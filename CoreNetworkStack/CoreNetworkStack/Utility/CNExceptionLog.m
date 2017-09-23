//
//  CNExceptionLog.m
//  RequestSynchronizer
//
//  Created by Towhid Islam on 8/25/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "CNExceptionLog.h"
#import "LogTracker.h"

@implementation CNExceptionLog

static BOOL DEBUG_MODE_ON = YES;
static BOOL TRACKING_MODE_ON = NO;

+ (LogTracker*) getExceptionTracker{
    
    static LogTracker *_tracker2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tracker2 = [[LogTracker alloc] initWithPersistenceFileName:@"__log_manager__exception"];
    });
    return _tracker2;
}

+ (void)message:(NSString *)format, ...{
    
    @try {
        va_list args;
        va_start(args, format);
        NSString *fLog = [[NSString alloc] initWithFormat:format arguments:args];
        if (TRACKING_MODE_ON) [[CNExceptionLog getExceptionTracker] addToLogBook:fLog];
        if (DEBUG_MODE_ON) NSLog(@"%@",fLog);
    }
    @catch (NSException *exception) {
        NSLog(@"CNExceptionLog %@",[exception reason]);
    }
}

+ (void)message:(NSString *)format args:(va_list)args{
    
    @try {
        NSString *fLog = [[NSString alloc] initWithFormat:format arguments:args];
        if (TRACKING_MODE_ON) [[CNExceptionLog getExceptionTracker] addToLogBook:fLog];
        if (DEBUG_MODE_ON) NSLog(@"%@",fLog);
    }
    @catch (NSException *exception) {
        NSLog(@"Debug %@",[exception reason]);
    }
}

+ (void)save{
    
    [[CNExceptionLog getExceptionTracker] save];
}

+ (void)printSavedLog{
    
    if (DEBUG_MODE_ON) {
        [[CNExceptionLog getExceptionTracker] printSavedLog];
    }
}

+ (void)sendFeedbackTo:(HttpFileRequest *)binary{
    
    [[CNExceptionLog getExceptionTracker] sendFeedbackTo:binary];
}

@end
