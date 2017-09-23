//
//  RemoteObject.m
//  RequestSynchronizer
//
//  Created by Towhid Islam on 7/7/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "RemoteConnection.h"
#import "HttpFileRequest.h"
#import "NetworkActivity.h"
#import "CNDebugLog.h"
#import "ConnectionHandler.h"

@interface RemoteConnection ()
@property (nonatomic, strong) HttpWebRequest *capsul;
@property (nonatomic, strong) NSString *className;
@property (nonatomic, copy) CompletionHandler completionHandler;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSURLConnection *internalConnection;
@property (nonatomic, strong) ConnectionHandler *delegate;
@end

@implementation RemoteConnection

- (instancetype)initWithConnectionDelegate:(ConnectionHandler *)handler{
    
    if (self = [super init]) {
        
        if (!handler) {
            handler = [ConnectionHandler new];
        }
        self.delegate = handler;
    }
    return self;
}

- (instancetype)init{
    
    if (self = [self initWithConnectionDelegate:nil]) {
        //
    }
    return self;
}

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

- (void) sendSynchronusMessage:(HttpWebRequest*)capsul onCompletion:(CompletionHandler)completion{
    
    //by default running on serial queue.
    const char *lable = [[NSString stringWithFormat:@"%@.remote.object",[[NSBundle mainBundle] bundleIdentifier]] cStringUsingEncoding:NSUTF8StringEncoding];
    dispatch_queue_t queue = dispatch_queue_create(lable, DISPATCH_QUEUE_SERIAL);
    
    [self sendSynchronusMessage:capsul onDispatchQueue:queue onCompletion:completion];
}

- (void) sendSynchronusMessage:(HttpWebRequest*)capsul onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion{
    
    //Check sentinel values
    if (!capsul || !completion) {
        [CNDebugLog message:@"Capsul and CompletionHandler can't be nil"];
        return;
    }
    
    self.queue = queue;
    self.capsul = capsul;
    self.completionHandler = completion;
    
    //logic goes here.
    if (![[NetworkActivity sharedInstance] isInternetReachable]) {
        //construct internet not reachable failer message.
        if (self.completionHandler) {
            NSError *error = [[NSError alloc] initWithDomain:@"com.remote.object.internet.unreachable" code:NetworkOperationUnreachable userInfo:nil];
            self.completionHandler(nil,nil,error);
        }
    }
    else{
        [self executeSynchronousLegacy];
    }
}

- (void)sendAsynchronusMessage:(HttpWebRequest *)capsul onCompletion:(CompletionHandler)completion{
    
    //by default running on main queue.
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    [self sendAsynchronusMessage:capsul onDispatchQueue:queue onCompletion:completion];
}

- (void)sendAsynchronusMessage:(HttpWebRequest *)capsul onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion{
    
    //Check sentinel values
    if (!capsul || !completion) {
        [CNDebugLog message:@"Capsul and CompletionHandler can't be nil"];
        return;
    }
    
    self.delegate.queue = !queue ? dispatch_get_main_queue() : queue;
    self.delegate.capsul = capsul;
    self.delegate.completionHandler = completion;
    self.delegate.progressDelegate = self.progressDelegate;
    
    //logic goes here.
    if (![[NetworkActivity sharedInstance] isInternetReachable]) {
        //construct internet not reachable failer message.
        if (self.delegate.completionHandler) {
            NSError *error = [[NSError alloc] initWithDomain:@"com.remote.object.internet.unreachable" code:NetworkOperationUnreachable userInfo:nil];
            self.delegate.completionHandler(nil, nil,error);
        }
    }
    else{
        [self executeAsynchronousLegacy];
    }
}

- (void)cancelRemoteMessage{
    
    if (self.internalConnection) {
        [self.internalConnection cancel];
        self.internalConnection = nil;
        if (self.completionHandler != nil){
            dispatch_async(self.delegate.queue, ^{
                
                NSDictionary *userinfo = @{@"title":@"Network Operation Cenceled"
                                           ,@"message":@"Network operation has been canceled."};
                NSError *errorX = [[NSError alloc] initWithDomain:@"com.remote.object.network.cancel" code:NetworkOperationCancel userInfo:userinfo];
                self.completionHandler(nil, nil, errorX);
            });
        }
        
        [self.delegate whenProgressFailedWithError:nil];
    }
    else{
        [CNDebugLog message:@"Operation Can't be canceled."];
    }
}

#pragma -mark private

- (void) executeAsynchronousLegacy{
    
    NSURLRequest *request = [self.delegate.capsul createRequest];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self.delegate startImmediately:NO];
    if(connection){
        
        NSMutableData *bData = [[NSMutableData alloc] init];
        [self.delegate setResponseData:bData];
        self.internalConnection = connection;
        [connection start];
    }
    else{
        
        if (self.completionHandler != nil){
            dispatch_async(self.delegate.queue, ^{
                NSDictionary *userinfo = @{@"title":@"Network Error"
                                           ,@"message":@"You are not connected to internet. Check again!"};
                NSError *errorX = [[NSError alloc] initWithDomain:@"com.remote.object.network.error" code:NetworkOperationError userInfo:userinfo];
                self.completionHandler(nil, nil, errorX);
            });
        }
    }
}

- (void) executeSynchronousLegacy{
    
    NSURLRequest *request = [self.capsul createRequest];
    NSError *error = nil;
    NSURLResponse *response = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [self completionHandlerWithData:data response:response error:error];
}

- (void) completionHandlerWithData:(NSData*)data response:(NSURLResponse*)response error:(NSError*)error{
    
    //
    [CNDebugLog message:[NSString stringWithFormat:@"%@",response.description]];
    //
    if (self.completionHandler) {
        self.completionHandler(data, response, error);
    }
}

- (CompletionHandler) getCompletionHandler{
    return self.completionHandler;
}

@end
