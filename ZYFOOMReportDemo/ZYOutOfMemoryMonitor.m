//
//  ZYOutOfMemoryMonitor.m
//  ZYFOOMReportDemo
//
//  Created by zhengyin on 2020/1/7.
//  Copyright © 2020 xiaomi. All rights reserved.
//

#import "ZYOutOfMemoryMonitor.h"
#import "fishhook.h"
#import <mach/mach.h>
#include <sys/stat.h>

static NSString *ZYOOMPreviousBundleVersionKey = @"ZYOOMPreviousBundleVersionKey";
static NSString *ZYOOMAppWasTerminatedKey = @"ZYOOMAppWasTerminatedKey";
static NSString *ZYOOMAppWasInBackgroundKey = @"ZYOOMAppWasInBackgroundKey";
static NSString *ZYOOMAppDidCrashKey = @"ZYOOMAppDidCrashKey";
static NSString *ZYOOMAppWasExitKey = @"ZYOOMAppWasExitKey";
static NSString *ZYOOMPreviousOSVersionKey = @"ZYOOMPreviousOSVersionKey";
static char *intentionalQuitPathname;

@interface ZYOutOfMemoryMonitor ()

- (void)appDidExit;

@end

static void (*_orig_exit)(int);
static void (*orig_exit)(int);
static void (*orig_abort)(void);

void my_exit(int value) {
    [[ZYOutOfMemoryMonitor sharedInstance] appDidExit];
    orig_exit(value);
}

void _my_exit(int value) {
    [[ZYOutOfMemoryMonitor sharedInstance] appDidExit];
    _orig_exit(value);
}

void my_abort(void) {
    [[ZYOutOfMemoryMonitor sharedInstance] appDidExit];
    orig_abort();
}

@implementation ZYOutOfMemoryMonitor

+ (void)load {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      rebind_symbols((struct rebinding[1]){
          {"_exit", (void *)_my_exit, (void *)&_orig_exit}
      }, 1);
      rebind_symbols((struct rebinding[1]){
          {"exit", (void *)my_exit, (void **)&orig_exit}
      }, 1);
      rebind_symbols((struct rebinding[1]){
          {"abort", (void *)my_abort, (void **)&orig_abort}
      }, 1);
  });
}

- (void)beginMonitoringMemoryEventsWithHandler:(ZYOutOfMemoryEventHandler)handler {
    [[ZYOutOfMemoryMonitor sharedInstance] beginApplicationMonitoring];
    signal(SIGABRT, ZYIntentionalQuitHandler);
    signal(SIGQUIT, ZYIntentionalQuitHandler);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Set up the static path for intentional aborts
    if ([ZYOutOfMemoryMonitor intentionalQuitPathname]) {
        intentionalQuitPathname = strdup([ZYOutOfMemoryMonitor intentionalQuitPathname]);
    }

    BOOL didIntentionallyQuit = NO;
    struct stat statbuffer;
    if (stat(intentionalQuitPathname, &statbuffer) == 0){
        // A file exists at the path, we had an intentional quit
        didIntentionallyQuit = YES;
    }
    BOOL didCrash = [defaults boolForKey:ZYOOMAppDidCrashKey];;
    BOOL didTerminate = [defaults boolForKey:ZYOOMAppWasTerminatedKey];
    BOOL didExit = [defaults boolForKey:ZYOOMAppWasExitKey];
    BOOL didUpgradeApp = ![[ZYOutOfMemoryMonitor currentBundleVersion] isEqualToString:[ZYOutOfMemoryMonitor previousBundleVersion]];
    BOOL didUpgradeOS = ![[ZYOutOfMemoryMonitor currentOSVersion] isEqualToString:[ZYOutOfMemoryMonitor previousOSVersion]];
    if (!(didIntentionallyQuit || didCrash || didExit || didTerminate || didUpgradeApp || didUpgradeOS)) {
        if (handler) {
            BOOL wasInBackground = [[NSUserDefaults standardUserDefaults] boolForKey:ZYOOMAppWasInBackgroundKey];
            handler(!wasInBackground);
        }
    }

    [defaults setObject:[ZYOutOfMemoryMonitor currentBundleVersion] forKey:ZYOOMPreviousBundleVersionKey];
    [defaults setObject:[ZYOutOfMemoryMonitor currentOSVersion] forKey:ZYOOMPreviousOSVersionKey];
    [defaults setBool:NO forKey:ZYOOMAppWasTerminatedKey];
    [defaults setBool:NO forKey:ZYOOMAppWasInBackgroundKey];
    [defaults setBool:NO forKey:ZYOOMAppDidCrashKey];
    [defaults setBool:NO forKey:ZYOOMAppWasExitKey];
    [defaults synchronize];
    // Remove intentional quit file
    unlink(intentionalQuitPathname);
}

#pragma mark termination and backgrounding

+ (instancetype)sharedInstance {
    static id sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ZYOutOfMemoryMonitor alloc] init];
    });
    return sharedInstance;
}

- (void)beginApplicationMonitoring {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ZYOOMAppWasTerminatedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ZYOOMAppWasInBackgroundKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:ZYOOMAppWasInBackgroundKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)appDidExit {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ZYOOMAppWasExitKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)appDidCrash {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ZYOOMAppDidCrashKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark app version

+ (NSString *)currentBundleVersion {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *majorVersion = infoDictionary[@"CFBundleShortVersionString"];
    NSString *minorVersion = infoDictionary[@"CFBundleVersion"];
    return [NSString stringWithFormat:@"%@.%@", majorVersion, minorVersion];
}

+ (NSString *)previousBundleVersion {
    return [[NSUserDefaults standardUserDefaults] objectForKey:ZYOOMPreviousBundleVersionKey];
}

#pragma mark OS version

+ (NSString *)stringFromOperatingSystemVersion:(NSOperatingSystemVersion)version {
    return [NSString stringWithFormat:@"%@.%@.%@", @(version.majorVersion), @(version.minorVersion), @(version.patchVersion)];
}

+ (NSString *)currentOSVersion {
    return [self stringFromOperatingSystemVersion:[[NSProcessInfo processInfo] operatingSystemVersion]];
}

+ (NSString *)previousOSVersion {
    return [[NSUserDefaults standardUserDefaults] objectForKey:ZYOOMPreviousOSVersionKey];
}

#pragma mark crash reporting

static void ZYIntentionalQuitHandler(int signal) {
    creat(intentionalQuitPathname, S_IREAD | S_IWRITE);
}

#pragma mark crash Path

+ (const char *)intentionalQuitPathname {
    NSString *appSupportDirectory = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDirectory isDirectory:NULL]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDirectory withIntermediateDirectories:YES attributes:nil error:nil]) {
            return 0;
        }
    }
    NSString *fileName = [appSupportDirectory stringByAppendingPathComponent:@"intentionalquit"];
    return [fileName UTF8String];
}

@end
