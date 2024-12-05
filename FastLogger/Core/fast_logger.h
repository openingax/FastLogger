//
//  fast_logger.h
//  FastLogger
//
//  Created by 谢立颖 on 2024/12/3.
//

#ifndef FAST_LOGGER_H
#define FAST_LOGGER_H

#ifdef __cplusplus
extern "C" {
#endif

// 日志级别
typedef enum {
    LOG_LEVEL_DEBUG = 0,
    LOG_LEVEL_INFO,
    LOG_LEVEL_WARN,
    LOG_LEVEL_ERROR
} LogLevel;

// 初始化函数，可考虑加 __attribute__((constructor))，以让系统启动时自动调用此函数
int fast_logger_init(void);

// 设置日志文件
int fast_logger_set_file(const char* path);

// 写入日志
int fast_logger_write(LogLevel level, const char* module, const char* message);

// 清理函数
void fast_logger_cleanup(void);

// 设置日志级别（可选）
void fast_logger_set_level(LogLevel level);

// 立即刷新缓冲区（可选）
void fast_logger_flush(void);

#ifdef __cplusplus
}
#endif

#endif // FAST_LOGGER_H
