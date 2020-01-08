//
//  ZYOutOfMemoryMonitor.h
//  ZYFOOMReportDemo
//
//  Created by zhengyin on 2020/1/7.
//  Copyright © 2020 xiaomi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZYOutOfMemoryMonitor : NSObject

typedef void (^ZYOutOfMemoryEventHandler)(BOOL wasInForeground);

+ (instancetype)sharedInstance;

- (void)beginMonitoringMemoryEventsWithHandler:(nonnull ZYOutOfMemoryEventHandler)handler;

/// 请在Crash组件捕获到crash后调用该方法
- (void)appDidCrash;

/// 请在Exit时,调用该方法,由于RN中的fishhook暂时hook函数Exit()失败,所以先手动调用
- (void)appDidExit;

@end

NS_ASSUME_NONNULL_END
