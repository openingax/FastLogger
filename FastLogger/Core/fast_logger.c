//
//  fast_logger.c
//  FastLogger
//
//  Created by 谢立颖 on 2024/12/3.
//

#include "fast_logger.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <stdatomic.h>
#include <pthread.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#define BUFFER_SIZE (4 * 1024 * 1024)   // 4MB ring buffer
#define BATCH_THRESHOLD (256 * 1024)    // 256KB batch write

typedef struct {
    char* buffer;
    atomic_int writePos;
    atomic_int readPos;
    int fd;
    pthread_mutex_t mutex;
    pthread_t flush_thread;
    atomic_bool should_exit;
    LogLevel min_level;
} LoggerContext;

static LoggerContext* logger = NULL;

// 时间戳缓存
static struct {
    atomic_uint_fast64_t last_timestamp;
    char last_timestamp_str[32];
    pthread_mutex_t mutex;
    uint32_t len;
} timestamp_cache = {0};

// 获取当前时间戳（毫秒）
static uint64_t get_current_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
}

// 格式化时间戳
__attribute__((always_inline)) static uint32_t format_timestamp(char* buffer, uint64_t timestamp_ms) {
    time_t seconds = timestamp_ms / 1000;
    int milliseconds = timestamp_ms % 1000;
    
    // 检查缓存
    uint64_t last = atomic_load(&timestamp_cache.last_timestamp);
    if (seconds == last / 1000) {
        pthread_mutex_lock(&timestamp_cache.mutex);
        memcpy(buffer, timestamp_cache.last_timestamp_str, timestamp_cache.len);
        pthread_mutex_unlock(&timestamp_cache.mutex);
        return timestamp_cache.len;
    }
    
    struct tm tm_time;
    localtime_r(&seconds, &tm_time);
    
    pthread_mutex_lock(&timestamp_cache.mutex);
    
    size_t len = strftime(buffer, 32, "%Y-%m-%d %H:%M:%S.", &tm_time);
    len += snprintf(buffer + len, 32 - len, "%03d", milliseconds);
    
    // 添加长度检查
    if (len > UINT32_MAX) {
        len = UINT32_MAX;
    }
    
    // 更新缓存
    timestamp_cache.len = (uint32_t)len;
    memcpy(timestamp_cache.last_timestamp_str, buffer, len);
    atomic_store(&timestamp_cache.last_timestamp, timestamp_ms);
    
    pthread_mutex_unlock(&timestamp_cache.mutex);
    
    return (uint32_t)len;
}

// 刷新缓冲区
__attribute__((hot)) static void flush_buffer(void) {
    int readPos = atomic_load(&logger->readPos);
    int writePos = atomic_load(&logger->writePos);
    
    if (readPos == writePos) return;
    
    if (writePos > readPos) {
        write(logger->fd, logger->buffer + readPos, writePos - readPos);
    } else {
        write(logger->fd, logger->buffer + readPos, BUFFER_SIZE - readPos);
        write(logger->fd, logger->buffer, writePos);
    }
    
    atomic_store(&logger->readPos, writePos);
}

// 刷新线程函数
static void* flush_thread_func(void* arg) {
    while (!atomic_load(&logger->should_exit)) {
        pthread_mutex_lock(&logger->mutex);
        flush_buffer();
        pthread_mutex_unlock(&logger->mutex);
        usleep(1000000); // 休眠1秒
    }
    return NULL;
}

//__attribute__((constructor))
int fast_logger_init(void) {
    if (logger != NULL) return 0;  // 已经初始化
    
    logger = (LoggerContext*)calloc(1, sizeof(LoggerContext));
    if (!logger) return -1;
    
    // 使用 calloc 而不是 malloc，确保内存被初始化为 0
    logger->buffer = (char*)calloc(1, BUFFER_SIZE);
    if (!logger->buffer) {
        free(logger);
        logger = NULL;
        return -1;
    }
    
    pthread_mutex_init(&logger->mutex, NULL);
    pthread_mutex_init(&timestamp_cache.mutex, NULL);
    atomic_init(&logger->writePos, 0);
    atomic_init(&logger->readPos, 0);
    atomic_init(&logger->should_exit, false);
    logger->min_level = LOG_LEVEL_DEBUG;
    logger->fd = -1;
    
    // 创建刷新线程
    if (pthread_create(&logger->flush_thread, NULL, flush_thread_func, NULL) != 0) {
        free(logger->buffer);
        free(logger);
        logger = NULL;
        return -1;
    }
    
    return 0;
}

int fast_logger_set_file(const char* path) {
    if (!logger) return -1;
    if (logger->fd > 0) {
        close(logger->fd);
    }
    
    // 打开或创建文件
    logger->fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (logger->fd <= 0) {
        return -1;
    }
    
    // 如果是新文件，写入 UTF-8 BOM
    if (lseek(logger->fd, 0, SEEK_END) == 0) {
        // UTF-8 BOM: EF BB BF
        unsigned char bom[] = {0xEF, 0xBB, 0xBF};
        write(logger->fd, bom, sizeof(bom));
    }
    
    return 0;
}

int fast_logger_write(LogLevel level, const char* module, const char* message) {
    if (!logger || logger->fd <= 0 || level < logger->min_level) return -1;
    
    
    
    // 格式化时间戳
    char timestamp[32];
    uint32_t timestamp_len = format_timestamp(timestamp, get_current_time_ms());
    
    // 获取级别字符串
    const char* level_str;
    switch (level) {
        case LOG_LEVEL_DEBUG: level_str = "DEBUG"; break;
        case LOG_LEVEL_INFO:  level_str = "INFO"; break;
        case LOG_LEVEL_WARN:  level_str = "WARN"; break;
        case LOG_LEVEL_ERROR: level_str = "ERROR"; break;
        default: level_str = "UNKNOWN"; break;
    }
    
    size_t level_len = strlen(level_str);
    size_t module_len = strlen(module);
    size_t message_len = strlen(message);
    // 5的长度是这几个字符：[][]\n
    // module 和 level 用中括号括起来，每行最后还要有一个 \n 换行符
    size_t total_len = timestamp_len + level_len + module_len + message_len + 5;
    
    if (total_len >= BUFFER_SIZE) return -1;
    
    pthread_mutex_lock(&logger->mutex);
    
    int currentPos = atomic_load(&logger->writePos);
    int nextPos = (currentPos + total_len) % BUFFER_SIZE;
    
    if (nextPos < currentPos || total_len > (BUFFER_SIZE - currentPos)) {
        flush_buffer();
        currentPos = 0;
        
        if (total_len > BUFFER_SIZE) {
            pthread_mutex_unlock(&logger->mutex);
            return -1;
        }
        
        nextPos = (int)total_len;
    }
    
    int offset = currentPos;
    memcpy(logger->buffer + offset, timestamp, timestamp_len);
    offset += timestamp_len;
    
    logger->buffer[offset++] = '[';
    
    memcpy(logger->buffer + offset, level_str, level_len);
    offset += level_len;
    
    logger->buffer[offset++] = ']';
    logger->buffer[offset++] = '[';
    
    memcpy(logger->buffer + offset, module, module_len);
    offset += module_len;
    
    logger->buffer[offset++] = ']';
    
    memcpy(logger->buffer + offset, message, message_len);
    offset += message_len;
    logger->buffer[offset++] = '\n';
    
    atomic_store(&logger->writePos, nextPos);
    
    if (nextPos - atomic_load(&logger->readPos) >= BATCH_THRESHOLD) {
        flush_buffer();
    }
    
    pthread_mutex_unlock(&logger->mutex);
    return 0;
}

// __attribute__((destructor))
void fast_logger_cleanup(void) {
    if (!logger) return;
    
    // 停止刷新线程
    atomic_store(&logger->should_exit, true);
    pthread_join(logger->flush_thread, NULL);
    
    // 最后一次刷新
    pthread_mutex_lock(&logger->mutex);
    flush_buffer();
    pthread_mutex_unlock(&logger->mutex);
    
    // 清理资源
    if (logger->fd > 0) {
        close(logger->fd);
    }
    pthread_mutex_destroy(&logger->mutex);
    pthread_mutex_destroy(&timestamp_cache.mutex);
    
    free(logger->buffer);
    free(logger);
    logger = NULL;
}

void fast_logger_set_level(LogLevel level) {
    if (logger) {
        logger->min_level = level;
    }
}

void fast_logger_flush(void) {
    if (logger) {
        pthread_mutex_lock(&logger->mutex);
        flush_buffer();
        pthread_mutex_unlock(&logger->mutex);
    }
}
