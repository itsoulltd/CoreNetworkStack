//
//  EnergyStateSession.m
//  RequestSynchronizer
//
//  Created by Towhid on 8/28/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "EnergyStateSession.h"
#import "SessionHandler.h"
#import "CNDebugLog.h"

@interface EnergyStateSession ()

@end

@implementation EnergyStateSession

NSString *const kDiscretionarySessionIdentifier = @"discretionarySessionIdentifier";

+ (instancetype)defaultSession{
    
    static EnergyStateSession *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *kDescretionarySessionId = [NSString stringWithFormat:@"%@.%@",[[NSBundle mainBundle] bundleIdentifier],kDiscretionarySessionIdentifier];
        _sharedInstance = [[EnergyStateSession alloc] initWithBackgroundSessionIdentifier:kDescretionarySessionId];
    });
    return _sharedInstance;
}

- (NSURLSession*) createBackgroundSessionWithIdentifier:(NSString*)identifier andSessionDelegate:(SessionHandler*)handler{
    
    NSURLSessionConfiguration *discretionaryConfigObject = nil;
    if ([NSURLSessionConfiguration respondsToSelector:@selector(backgroundSessionConfigurationWithIdentifier:)]) {
        discretionaryConfigObject = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
    }else{
        discretionaryConfigObject = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
    }
    discretionaryConfigObject.HTTPMaximumConnectionsPerHost = 5;
    discretionaryConfigObject.discretionary = YES;
    discretionaryConfigObject.allowsCellularAccess = NO;
    discretionaryConfigObject.timeoutIntervalForResource = 18 * 60 * 60;
    //configure cache policy for background config object.
    [self setupCachePolicy:discretionaryConfigObject directory:@"/BackgroundCacheDirectory"];
    return [NSURLSession sessionWithConfiguration:discretionaryConfigObject
                                                              delegate:handler
                                                         delegateQueue:[[NSOperationQueue alloc] init]];
}

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

@end
