//
//  AppDelegate.m
//  ZYFOOMReportDemo
//
//  Created by zhengyin on 2020/1/8.
//  Copyright © 2020 zhengyin. All rights reserved.
//

#import "AppDelegate.h"
#import <Bugly/Bugly.h>
#import "ZYOutOfMemoryMonitor.h"

@interface AppDelegate () <BuglyDelegate>

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    BuglyConfig *config = [[BuglyConfig alloc]init];
    config.reportLogLevel = BuglyLogLevelWarn;
    config.crashAbortTimeout = 1.f;
    config.unexpectedTerminatingDetectionEnable = YES;
    config.delegate = self;
    [Bugly startWithAppId:@"1234" config:config];
    
    [[ZYOutOfMemoryMonitor sharedInstance] beginMonitoringMemoryEventsWithHandler:^(BOOL wasInForeground) {
        if (wasInForeground) {
            //report
        }
    }];
    
    return YES;
}

- (NSString *)attachmentForException:(NSException *)exception {
    [[ZYOutOfMemoryMonitor sharedInstance] appDidCrash];
    return @"";
}

#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
