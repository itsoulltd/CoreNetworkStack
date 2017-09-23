//
//  SessionedRemoteObject.m
//  RequestSynchronizer
//
//  Created by Towhid Islam on 7/7/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "RemoteSession.h"
#import "RemoteTask.h"
#import "NSString+NGStackHash.h"
#import "ContentHandler.h"
#import "HttpFileRequest.h"
@import CoreDataStack;
#import "CNDebugLog.h"
#import "SessionHandler.h"
#import "ContentDelegate.h"

@interface RemoteSession (){
    
}
@property (readwrite) NSURLSession *backgroundSession;
@property (readwrite) NSURLSession *defaultSession;
@property (readwrite) NSURLSession *utilitySession;
@property (nonatomic, strong, readwrite) SessionHandler *delegateHandler;
@end

@implementation RemoteSession

- (NSURLSession *)basicSession{
    return _defaultSession;
}

NSString *const kBacgroundSessionIdentifier = @"backgroundSessionIdentifier";

+ (instancetype)defaultSession{
    
    static RemoteSession *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *kBackgroundSessionId = [NSString stringWithFormat:@"%@.%@",[[NSBundle mainBundle] bundleIdentifier],kBacgroundSessionIdentifier];
        _sharedInstance = [[RemoteSession alloc] initWithBackgroundSessionIdentifier:kBackgroundSessionId];
    });
    return _sharedInstance;
}

- (instancetype)initWithBackgroundSessionIdentifier:(NSString*)identifier andSessionDelegate:(SessionHandler*)handler{
    
    if (self = [super init]) {
        
        //setup SessionDelegate handler
        _taskMapper = [[NSMutableDictionary alloc] initWithCapacity:0];
        _responseDataMapper = [[NSMutableDictionary alloc] initWithCapacity:0];
        _completionHandlerDictionary = [[NSMutableDictionary alloc] initWithCapacity:0];
        if (!handler) {
            handler = [SessionHandler new];
        }
        self.delegateHandler = handler;
        self.delegateHandler.taskMapper = self.taskMapper;
        self.delegateHandler.responseDataMapper = self.responseDataMapper;
        self.delegateHandler.completionHandlerDictionary = self.completionHandlerDictionary;
        
        //Background Session
        self.backgroundSession = [self createBackgroundSessionWithIdentifier:identifier andSessionDelegate:self.delegateHandler];
        
        //Default Session
        NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration
                                                          defaultSessionConfiguration];
        defaultConfigObject.allowsCellularAccess = YES;
        defaultConfigObject.HTTPMaximumConnectionsPerHost = 5;
        //configure cache policy for default config object.
        [self setupCachePolicy:defaultConfigObject directory:@"/DefaultCacheDirectory"];
        NSOperationQueue *optQueue = [[NSOperationQueue alloc] init];
        if ([optQueue respondsToSelector:@selector(setQualityOfService:)]) {
            optQueue.qualityOfService = NSQualityOfServiceUserInitiated;
        }
        self.defaultSession = [NSURLSession sessionWithConfiguration:defaultConfigObject
                                                            delegate:self.delegateHandler
                                                       delegateQueue:optQueue];
        
        //Utility Session
        NSURLSessionConfiguration *utilityConfigObject = [NSURLSessionConfiguration
                                                          defaultSessionConfiguration];
        utilityConfigObject.allowsCellularAccess = NO;
        utilityConfigObject.networkServiceType = NSURLNetworkServiceTypeBackground;
        utilityConfigObject.HTTPMaximumConnectionsPerHost = 5;
        //configure cache policy for utility config object.
        [self setupCachePolicy:utilityConfigObject directory:@"/UtilityCacheDirectory"];
        NSOperationQueue *optQueue2 = [[NSOperationQueue alloc] init];
        if ([optQueue2 respondsToSelector:@selector(setQualityOfService:)]) {
            optQueue2.qualityOfService = NSQualityOfServiceUtility;
        }
        self.utilitySession = [NSURLSession sessionWithConfiguration:utilityConfigObject
                                                            delegate:self.delegateHandler
                                                       delegateQueue:optQueue2];
    }
    
    return self;
}

- (instancetype)initWithBackgroundSessionIdentifier:(NSString*)identifier{
    
    if (self = [self initWithBackgroundSessionIdentifier:identifier andSessionDelegate:nil]) {
        //
    }
    return self;
}

- (instancetype)init{
    
    NSString *kBackgroundSessionId = [NSString stringWithFormat:@"%@.%@.%@",[[NSBundle mainBundle] bundleIdentifier],kBacgroundSessionIdentifier,[NSDate date]];
    
    if (self = [self initWithBackgroundSessionIdentifier:kBackgroundSessionId]) {
        //
    }
    return self;
}

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

- (NSURLSession*) getBackgroundSession{
    return self.backgroundSession;
}

- (NSURLSession *)createBackgroundSessionWithIdentifier:(NSString *)identifier andSessionDelegate:(SessionHandler*)handler{
    
    NSURLSessionConfiguration *backgroundConfigObject = nil;
    if ([NSURLSessionConfiguration respondsToSelector:@selector(backgroundSessionConfigurationWithIdentifier:)]) {
        backgroundConfigObject = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
    }else{
        backgroundConfigObject = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
    }
    backgroundConfigObject.HTTPMaximumConnectionsPerHost = 5;
    backgroundConfigObject.allowsCellularAccess = YES;
    //configure cache policy for background config object.
    [self setupCachePolicy:backgroundConfigObject directory:@"/BackgroundCacheDirectory"];
    return [NSURLSession sessionWithConfiguration:backgroundConfigObject
                                                           delegate:handler
                                                      delegateQueue:[[NSOperationQueue alloc] init]];
}

- (void) setupCachePolicy:(NSURLSessionConfiguration*)configuration directory:(NSString*)directoryPath{
    
    /* Configure caching behavior for the default session.
     Note that iOS requires the cache path to be a path relative
     to the ~/Library/Caches directory, but OS X expects an
     absolute path.
     */
#if TARGET_OS_IPHONE
    NSString *cachePath = directoryPath;
    NSArray *myPathList = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                              NSUserDomainMask, YES);
    NSString *myPath    = [myPathList  objectAtIndex:0];
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *fullCachePath = [[myPath
                                stringByAppendingPathComponent:bundleIdentifier]
                               stringByAppendingPathComponent:cachePath];
    [CNDebugLog message:@"Cache path: %@\n", fullCachePath];
#else
    NSString *lastPathComponent = [NSString stringWithFormat:@"%@.cache",directoryPath];
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:lastPathComponent];
    [CNDebugLog message:@"OSX Cache path: %@\n", cachePath];
#endif
    
    NSURLCache *myCache = [[NSURLCache alloc] initWithMemoryCapacity: 16384
                                                        diskCapacity: 268435456 diskPath: cachePath];
    configuration.URLCache = myCache;
    configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
}

- (RemoteDataTask*)sendMessage:(HttpWebRequest *)capsul onCompletion:(CompletionHandler)completion{
    
    //by default dispatching completion and failure handler on main queue.
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    return [self sendMessage:capsul onDispatchQueue:queue onCompletion:completion];
}

- (RemoteDataTask*)sendMessage:(HttpWebRequest *)capsul onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion{
    
    return [self sendMessage:capsul onDispatchQueue:queue onCompletion:completion forSession:self.defaultSession];
}

- (RemoteDataTask*) sendUtilityMessage:(HttpWebRequest*)capsul onCompletion:(CompletionHandler)completion{
    
    //by default dispatching completion and failure handler on main queue.
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    return [self sendUtilityMessage:capsul onDispatchQueue:queue onCompletion:completion];
}

- (RemoteDataTask*) sendUtilityMessage:(HttpWebRequest*)capsul onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion{
    
    return [self sendMessage:capsul onDispatchQueue:queue onCompletion:completion forSession:self.utilitySession];
}

- (RemoteDataTask*)sendMessage:(HttpWebRequest *)capsul onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion forSession:(NSURLSession*)session{
    
    //Check sentinel values
    if (!capsul || !completion) {
        [CNDebugLog message:@"Capsul and CompletionHandler can't be nil"];
        return nil;
    }
    
    RemoteDataTask *rmtTask = nil;
    if ([capsul isMemberOfClass:[HttpFileRequest class]]) {
        rmtTask = [RemoteUploadTask new];
        ((RemoteUploadTask*)rmtTask).progressDelegate = nil;
    }else{
        rmtTask = [RemoteDataTask new];
    }
    //by default dispatching completion and failure handler on main queue.
    rmtTask.queue = !queue ? dispatch_get_main_queue() : queue;
    rmtTask.capsul = capsul;
    rmtTask.completionHandler = completion;
    
    //logic goes here.
    NSURLRequest *request = [capsul createRequest];
    NSURLSessionTask *realTask = [session dataTaskWithRequest:request];
    rmtTask.task = realTask;
    [self.taskMapper setObject:rmtTask forKey:realTask];
    [realTask resume];
    
    return rmtTask;
}

- (RemoteUploadTask *)uploadContent:(HttpFileRequest *)capsul progressDelegate:(id<ContentDelegate>)delegate onCompletion:(CompletionHandler)completion{
    
    //by default dispatching completion and failure handler on main queue.
    dispatch_queue_t queue = dispatch_get_main_queue();
    return [self uploadContent:capsul progressDelegate:delegate onDispatchQueue:queue onCompletion:completion];
}

- (RemoteUploadTask *)uploadContent:(HttpFileRequest *)capsul progressDelegate:(id<ContentDelegate>)delegate onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion{
    
    //Check sentinel values
    if (!capsul || !completion) {
        [CNDebugLog message:@"Capsul and CompletionHandler can't be nil"];
        return nil;
    }
    
    RemoteUploadTask *rutTask = [[RemoteUploadTask alloc] initWithNetCapsulBinary:capsul];
    rutTask.queue = !queue ? dispatch_get_main_queue() : queue;
    rutTask.completionHandler = completion;
    rutTask.progressDelegate = delegate;
    
    //logic goes here.
    NSURLSessionTask *realTask = nil;
    NSURLRequest *request = [capsul createThinRequest];
    
    //create temp file path
    NSURL *bundleSourceUrl = capsul.localFileURL;
    NSString *extention = [[bundleSourceUrl absoluteString] pathExtension];
    NSString *fileTempName = [NSString stringWithFormat:@"%@.%@", [[bundleSourceUrl absoluteString] NGStack_SHA256], extention];
    NSString *signatureFile = [NSString stringWithFormat:@"%@%@",  NSTemporaryDirectory(), fileTempName];
    
    //extract raw data from original file
    NSData *raw = [capsul getHTTPBodyData];
    
    //After successfully written to tmp/<signatureFile>.xyz path,
    if ([raw writeToFile:signatureFile atomically:YES]) {
        
        //capsul.localFileURL = [NSURL fileURLWithPath:signatureFile];
        rutTask.tempLocalFileURL = [NSURL fileURLWithPath:signatureFile];
        raw = nil;
        
        //realTask = [[self getBackgroundSession] uploadTaskWithRequest:request fromFile:capsul.localFileURL];
        realTask = [[self getBackgroundSession] uploadTaskWithRequest:request fromFile:rutTask.tempLocalFileURL];
        
        rutTask.task = realTask;
        [self.delegateHandler increaseCounter];
        [self.taskMapper setObject:rutTask forKey:realTask];
        [realTask resume];
        
        return rutTask;
    }
    else{
        return nil;
    }
}

- (RemoteDownloadTask *)resumeDownloadFrom:(RemoteDownloadTask *)task{
    
    if (!task.resumeable) {
        return [self downloadContent:task.capsul progressDelegate:task.progressDelegate onCompletion:task.completionHandler];
    }
    NSURLSessionDownloadTask *dwnTask = [[self getBackgroundSession] downloadTaskWithResumeData:task.resumeable];
    [self.taskMapper removeObjectForKey:task.task];//confirming if not removed.
    task.task = dwnTask;
    [self.delegateHandler increaseCounter];//..
    [self.taskMapper setObject:task forKey:dwnTask];
    [dwnTask resume];
    task.resumeable = nil;
    return task;
}

- (RemoteDownloadTask *)downloadContent:(HttpWebRequest *)capsul progressDelegate:(id<ContentDelegate>)delegate onCompletion:(DownloadCompletionHandler)completion{
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    return [self downloadContent:capsul progressHandler:delegate onDispatchQueue:queue onCompletion:completion];
}

- (RemoteDownloadTask *)downloadContent:(HttpWebRequest *)capsul progressHandler:(id<ContentDelegate>)delegate onDispatchQueue:(dispatch_queue_t)queue onCompletion:(DownloadCompletionHandler)completion{
    
    //Check sentinel values
    if (!capsul || !completion) {
        [CNDebugLog message:@"Capsul and CompletionHandler can't be nil"];
        return nil;
    }
    
    RemoteDownloadTask *rutTask = [RemoteDownloadTask new];
    rutTask.queue = !queue ? dispatch_get_main_queue() : queue;
    rutTask.capsul = capsul;
    rutTask.completionHandler = completion;
    rutTask.progressDelegate = delegate;
    
    //logic goes here.
    NSURLRequest *request = [capsul createRequest];
    NSURLSessionDownloadTask *dwTask = [[self getBackgroundSession] downloadTaskWithRequest:request];
    rutTask.task = dwTask;
    [self.delegateHandler increaseCounter];
    [self.taskMapper setObject:rutTask forKey:dwTask];
    [dwTask resume];
    
    return rutTask;
}

- (void) addCompletionHandler: (CompletionHandlerType) handler forSession: (NSString *)identifier
{
    /*
     *In iOS, when a background transfer completes or requires credentials, if your app is no longer running, your app is automatically relaunched in the background, and the app’s UIApplicationDelegate is sent an application:handleEventsForBackgroundURLSession:completionHandler: message. This call contains the identifier of the session that caused your app to be launched. Your app should then store that completion handler before creating a background configuration object with the same identifier, and creating a session with that configuration. The newly created session is automatically reassociated with ongoing background activity.
     
     *When your app later receives a URLSessionDidFinishEventsForBackgroundURLSession: message, this indicates that all messages previously enqueued for this session have been delivered, and that it is now safe to invoke the previously stored completion handler or to begin any internal updates that may result in invoking the completion handler.
     */
    [ self.completionHandlerDictionary setObject:handler forKey: identifier];
    //create new backgroundSession if not exist with same key before.
    if (self.backgroundSession == nil) {
        self.backgroundSession = [self createBackgroundSessionWithIdentifier:identifier andSessionDelegate:self.delegateHandler];
    }
}

- (void) addCompletionHandler: (CompletionHandlerType) handler forSession: (NSString *)identifier andSessionDelegate:(SessionHandler*)sessionDelegate{
    
    self.delegateHandler = sessionDelegate;
    [self addCompletionHandler:handler forSession:identifier];
}

@end
