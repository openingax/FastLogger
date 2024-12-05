//
//  ViewController.m
//  FastLogger
//
//  Created by 谢立颖 on 2024/11/29.
//

#import "ViewController.h"
#include <mach/mach_time.h>
#include "fast_logger.h"

@interface ViewController ()

@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) NSTimer *testTimer;

@end

@implementation ViewController


- (void)viewLogFile {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *logPath = [documentsPath stringByAppendingPathComponent:@"app_log.txt"];
    
    // 检查文件是否存在
    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                     message:@"日志文件不存在"
                                                              preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                style:UIAlertActionStyleDefault
                                              handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:logPath];
    
#if TARGET_OS_MACCATALYST
    [UIPasteboard generalPasteboard].string = logPath;
#else
    // iOS 设备
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                          initWithActivityItems:@[fileURL]
                                          applicationActivities:nil];
    
    // 可以排除一些不需要的分享选项
    activityVC.excludedActivityTypes = @[
        UIActivityTypePostToFacebook,
        UIActivityTypePostToTwitter,
        UIActivityTypePostToWeibo,
        UIActivityTypeMessage
    ];
    
    // 添加完成回调
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType,
                                            BOOL completed,
                                            NSArray *returnedItems,
                                            NSError *error) {
        if (completed) {
            // 分享成功
            NSLog(@"Log file shared successfully");
        } else if (error) {
            // 分享出错
            NSLog(@"Error sharing log file: %@", error);
        }
    };
    
    [self presentViewController:activityVC animated:YES completion:nil];
#endif
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}

- (void)appendLog:(NSString *)log {
    self.logTextView.text = [self.logTextView.text stringByAppendingString:log];
}
//
//
//
//- (void)performanceTest {
//    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
//    NSString *fastLogPath = [documentsPath stringByAppendingPathComponent:@"fast.log"];
//    NSString *nslogPath = [documentsPath stringByAppendingPathComponent:@"nslog.log"];
//    
//    // 设置 FastLogger 的日志文件
//    fast_set_log_file([fastLogPath UTF8String]);
//    
//    // 重定向 NSLog 到文件
//    freopen([nslogPath UTF8String], "a+", stderr);
//    
//    // 准备测试数据
//    NSArray *messages = @[
//        @"Short log message",
//        @"This is a medium length log message for testing",
//        @"This is a very long log message that contains more content to test the performance with larger data sizes and see how it affects the logging speed"
//    ];
//    
//    // 测试次数
//    NSInteger iterations = 10000;
//    
//    // 测试 fast_log_message
//    NSDate *fastStart = [NSDate date];
//    for (NSInteger i = 0; i < iterations; i++) {
//        NSString *message = messages[i % messages.count];
//        fast_log_message("INFO", "Test", [message UTF8String], mach_absolute_time());
//    }
//    NSTimeInterval fastDuration = -[fastStart timeIntervalSinceNow];
//    
//    // 测试 NSLog
//    NSDate *nslogStart = [NSDate date];
//    for (NSInteger i = 0; i < iterations; i++) {
//        NSString *message = messages[i % messages.count];
//        NSLog(@"%@", message);
//    }
//    NSTimeInterval nslogDuration = -[nslogStart timeIntervalSinceNow];
//    
//    // 计算每秒日志数
//    double fastLogsPerSecond = iterations / fastDuration;
//    double nslogLogsPerSecond = iterations / nslogDuration;
//    
//    // 计算文件大小
//    NSDictionary *fastAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:fastLogPath error:nil];
//    NSDictionary *nslogAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:nslogPath error:nil];
//    
//    // 显示结果
//    NSString *result = [NSString stringWithFormat:
//                       @"Performance Test Results:\n\n"
//                       @"Test iterations: %ld\n\n"
//                       @"FastLogger:\n"
//                       @"- Time: %.5f seconds\n"
//                       @"- Speed: %.5f logs/second\n"
//                       @"- File size: %.2f KB\n\n"
//                       @"NSLog:\n"
//                       @"- Time: %.2f seconds\n"
//                       @"- Speed: %.2f logs/second\n"
//                       @"- File size: %.2f KB\n\n"
//                       @"Performance difference:\n"
//                       @"FastLogger is %.2fx faster than NSLog",
//                       (long)iterations,
//                       fastDuration,
//                       fastLogsPerSecond,
//                       [fastAttr fileSize] / 1024.0,
//                       nslogDuration,
//                       nslogLogsPerSecond,
//                       [nslogAttr fileSize] / 1024.0,
//                       nslogDuration / fastDuration];
//    
//    self.logTextView.text = result;
//}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化日志系统
    fast_logger_init();
    
    // 设置日志文件路径
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *logPath = [documentsPath stringByAppendingPathComponent:@"app_log.txt"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        NSError *e;
        [[NSFileManager defaultManager] removeItemAtPath:logPath error:&e];
        NSLog(@"app_log.txt file remove done, error: %@", e);
    }
    
    fast_logger_set_file([logPath UTF8String]);
    
    NSLog(@"Log file path: %@", logPath);
    
    // 创建显示日志的 TextView
    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 300)];
    self.logTextView.font = [UIFont systemFontOfSize:14];
    self.logTextView.backgroundColor = [UIColor systemGray6Color];
    [self.view addSubview:self.logTextView];
    
    // 创建测试按钮
    UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
    testButton.frame = CGRectMake(20, 400, self.view.bounds.size.width - 40, 44);
    [testButton setTitle:@"开始测试" forState:UIControlStateNormal];
    [testButton addTarget:self action:@selector(startTest) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:testButton];
    
    UIButton *viewLogButton = [UIButton buttonWithType:UIButtonTypeSystem];
    viewLogButton.frame = CGRectMake(20, 460, self.view.bounds.size.width - 40, 44);
    [viewLogButton setTitle:@"查看日志文件" forState:UIControlStateNormal];
    [viewLogButton addTarget:self action:@selector(viewLogFile) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:viewLogButton];
    
    UIButton *performanceTestButton = [UIButton buttonWithType:UIButtonTypeSystem];
    performanceTestButton.frame = CGRectMake(20, 520, self.view.bounds.size.width - 40, 44);
    [performanceTestButton setTitle:@"与 NSLog 性能测试" forState:UIControlStateNormal];
    [performanceTestButton addTarget:self action:@selector(performanceTest) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:performanceTestButton];
}

- (void)testLargeContent {
    // 1. 首先读取大文本文件
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"LargeContentTest" ofType:@"txt"];
    if (!filePath) {
        NSLog(@"Failed to find LargeContentTest.txt");
        return;
    }
    
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:filePath
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    if (error) {
        NSLog(@"Failed to read file: %@", error);
        return;
    }
    
    fast_logger_write(LOG_LEVEL_INFO, "LongTest", [content UTF8String]);
}

- (void)startTest {
    
    CFAbsoluteTime beginTime = CFAbsoluteTimeGetCurrent();
    
    // 停止之前的测试
    [self.testTimer invalidate];
    self.logTextView.text = @"";
    
    // 基本日志测试
    [self appendLog:@"\n=== 基本日志测试 ===\n"];
    fast_logger_write(LOG_LEVEL_DEBUG, "Default", "This is a debug Log");
    fast_logger_write(LOG_LEVEL_INFO, "Default", "这是一条信息日志");
    fast_logger_write(LOG_LEVEL_WARN, "Default", "This is a warn log");
    fast_logger_write(LOG_LEVEL_ERROR, "Default", "这是一条错误日志");
    
    // 带模块的日志测试
    [self appendLog:@"\n=== 模块日志测试 ===\n"];
    fast_logger_write(LOG_LEVEL_DEBUG, "Network", "网络请求开始");
    fast_logger_write(LOG_LEVEL_INFO, "UserData", "用户数据更新");
    fast_logger_write(LOG_LEVEL_WARN, "System", "电池电量低");
    fast_logger_write(LOG_LEVEL_ERROR, "Database", "数据库访问失败");
    
    // 开始性能测试
    [self appendLog:@"\n=== 开始性能测试 ===\n"];
    
    for (long count = 0; count < 1000000; count ++) {
        char message[100];
        // 模拟不同场景的日志
        switch (count % 4) {
            case 0:
                snprintf(message, sizeof(message), "性能测试 - Debug #%ld", count);
                fast_logger_write(LOG_LEVEL_DEBUG, "Performance", message);
                break;
            case 1:
                snprintf(message, sizeof(message), "性能测试 - Info #%ld", count);
                fast_logger_write(LOG_LEVEL_INFO, "Performance", message);
                break;
            case 2:
                snprintf(message, sizeof(message), "性能测试 - Warning #%ld", count);
                fast_logger_write(LOG_LEVEL_WARN, "Performance", message);
                break;
            case 3:
                snprintf(message, sizeof(message), "性能测试 - Error #%ld", count);
                fast_logger_write(LOG_LEVEL_ERROR, "Performance", message);
                break;
        }
    }
    
    [self appendLog:@"\n=== 性能测试完成 ===\n"];
    
    // 开始超长文本日志测试
    [self appendLog:@"\n=== 开始超长文本日志测试 ===\n"];
    [self testLargeContent];
    [self appendLog:@"\n=== 超长文本日志测试完成 ===\n"];
    
    // 强制刷新缓冲区
    fast_logger_flush();
    
    CFAbsoluteTime totalTime = CFAbsoluteTimeGetCurrent() - beginTime;
    NSLog(@"=== 日志写入总时间 ===: %lfs", totalTime);
}

- (void)performanceTest {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *fastLogPath = [documentsPath stringByAppendingPathComponent:@"fast.log"];
    NSString *nslogPath = [documentsPath stringByAppendingPathComponent:@"nslog.log"];
    
    // 设置 FastLogger 的日志文件
    fast_logger_set_file([fastLogPath UTF8String]);
    
    // 重定向 NSLog 到文件
    freopen([nslogPath UTF8String], "a+", stderr);
    
    // 准备测试数据
    NSArray *messages = @[
        @"Short log message",
        @"This is a medium length log message for testing",
        @"This is a very long log message that contains more content to test the performance with larger data sizes and see how it affects the logging speed"
    ];
    
    // 测试次数
    NSInteger iterations = 10000;
    
    CFAbsoluteTime beginTime = CFAbsoluteTimeGetCurrent();
    
    // 测试 fast_logger_write
    NSDate *fastStart = [NSDate date];
    for (NSInteger i = 0; i < iterations; i++) {
        NSString *message = messages[i % messages.count];
        fast_logger_write(LOG_LEVEL_INFO, "Test", [message UTF8String]);
    }
    
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime fast_log_time = endTime - beginTime;
    
    // 测试 NSLog
    NSDate *nslogStart = [NSDate date];
    for (NSInteger i = 0; i < iterations; i++) {
        NSString *message = messages[i % messages.count];
        NSLog(@"%@", message);
    }
    
    CFAbsoluteTime nslog_time = CFAbsoluteTimeGetCurrent() - endTime;
    
    // 强制刷新缓冲区
    fast_logger_flush();
    
    // 计算每秒日志数
    double fastLogsPerSecond = iterations / fast_log_time;
    double nslogLogsPerSecond = iterations / nslog_time;
    
    // 计算文件大小
    NSDictionary *fastAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:fastLogPath error:nil];
    NSDictionary *nslogAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:nslogPath error:nil];
    
    // 显示结果
    NSString *result = [NSString stringWithFormat:
                        @"Performance Test Results:\n\n"
                        @"Test iterations: %ld\n\n"
                        @"FastLogger:\n"
                        @"- Time: %.8f seconds\n"
                        @"- Speed: %.8f logs/second\n"
                        @"- File size: %.2f KB\n\n"
                        @"NSLog:\n"
                        @"- Time: %.8f seconds\n"
                        @"- Speed: %.8f logs/second\n"
                        @"- File size: %.2f KB\n\n"
                        @"Performance difference:\n"
                        @"FastLogger is %.8fx faster than NSLog",
                        (long)iterations,
                        fast_log_time,
                        fastLogsPerSecond,
                        [fastAttr fileSize] / 1024.0,
                        nslog_time,
                        nslogLogsPerSecond,
                        [nslogAttr fileSize] / 1024.0,
                        nslog_time / fast_log_time];
    
    self.logTextView.text = result;
}

// viewLogFile 和 appendLog 方法保持不变...

- (void)dealloc {
    // 清理日志系统
    fast_logger_cleanup();
}

@end
