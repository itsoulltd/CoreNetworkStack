//
//  NetworkActivity.m
//  Prokasona
//
//  Created by Towhid Islam on 1/10/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "NetworkActivity.h"
#import "Reachability.h"
#import "CNDebugLog.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@interface NetworkActivity (){
    BOOL _iswifireachable;
    BOOL _iswwanreachable;
    BOOL _isHostReachable;
    BOOL _isObserverConfigured;
}
@property (assign) NSInteger networkIndicatorCounter;
@property (nonatomic) Reachability *hostReachability;
@property (nonatomic) Reachability *internetReachability;
@property (nonatomic) Reachability *wifiReachability;
@property (nonatomic, strong) NSString *hostName;
@end

@implementation NetworkActivity
@synthesize networkIndicatorCounter = __networkIndicatorCounter;
@synthesize hostName = _hostName;

- (id)init{
    
    if (self = [super init]) {
        //
    }
    return self;
}

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

+ (id)sharedInstance{
    
    static NetworkActivity *__sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[NetworkActivity alloc] init];
    });
    return __sharedInstance;
}

#pragma Public Methods

- (void) startNetworkActivity{
    
    self.networkIndicatorCounter ++;
    if (self.networkIndicatorCounter == 1) {
#if TARGET_OS_IPHONE
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
#else
        [CNDebugLog message:@"OSX Execution."];
#endif
    }
}

- (void) stopNetworkActivity{
    
    self.networkIndicatorCounter --;
    if (self.networkIndicatorCounter == 0) {
#if TARGET_OS_IPHONE
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
#else
        [CNDebugLog message:@"OSX Execution."];
#endif
    }
}

- (BOOL)isWifiReachable{
    
    if (!_iswifireachable) {
        Reachability *netConnection = [Reachability reachabilityForInternetConnection];
        NetworkStatus status = [netConnection currentReachabilityStatus];
        _iswifireachable = (status == ReachableViaWiFi);
    }
    
    return _iswifireachable;
}

- (BOOL)isWWANReachable{
    
    if (!_iswwanreachable) {
        Reachability *netConnection = [Reachability reachabilityForLocalWiFi];
        NetworkStatus status = [netConnection currentReachabilityStatus];
        _iswwanreachable = (status == ReachableViaWWAN);
    }
    
    return _iswwanreachable;
}

- (BOOL)isHostReachable{
    
    if (!_isHostReachable && self.hostName) {
        Reachability *netConnection = [Reachability reachabilityWithHostName:self.hostName];
        NetworkStatus status = [netConnection currentReachabilityStatus];
        _isHostReachable = (status == ReachableViaWWAN) || (status == ReachableViaWiFi);
    }
    
    return _isHostReachable;
}

- (BOOL)isInternetReachable{
    
    BOOL isTrue = [self isHostReachable] || [self isWifiReachable];
    return isTrue;
}

NSString *const InternetReachableNotification = @"InternetReachableNotification";

- (void)activateReachabilityObserverWithHostAddress:(NSString *)remoteHostName{
    
    if (_isObserverConfigured) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    _isObserverConfigured = YES;
    
    if (remoteHostName && remoteHostName.length > 0) {
        self.hostName = remoteHostName;
        self.hostReachability = [Reachability reachabilityWithHostName:remoteHostName];
        [self.hostReachability startNotifier];
    }else{
        self.internetReachability = [Reachability reachabilityForInternetConnection];
        [self.internetReachability startNotifier];
    }
}

- (void)deactivateReachabilityObserver{
    
    if (!_isObserverConfigured) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    _isObserverConfigured = NO;
}

- (void) reachabilityChanged:(NSNotification *)notification
{
	Reachability* reachability = [notification object];
	NetworkStatus internetStatus = [reachability currentReachabilityStatus];
    switch (internetStatus)
    {
        case NotReachable:
            //post Notification with userInfo
            _isHostReachable = _iswifireachable = _iswwanreachable = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:InternetReachableNotification object:nil userInfo:@{kInternetReachableKey:[NSNumber numberWithBool:NO]}];
            break;
        case ReachableViaWiFi:
            _isHostReachable = _iswifireachable = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:InternetReachableNotification object:nil userInfo:@{kInternetReachableKey:[NSNumber numberWithBool:YES]}];
            break;
        case ReachableViaWWAN:
            _isHostReachable = _iswwanreachable = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:InternetReachableNotification object:nil userInfo:@{kInternetReachableKey:[NSNumber numberWithBool:YES]}];
            break;
    }
}

@end
