//
//  AbstructRemoteTask.m
//  RequestSynchronizer
//
//  Created by Towhid Islam on 8/17/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "RemoteTask.h"
#import "HttpFileRequest.h"
#import "ContentHandler.h"
#import "CNDebugLog.h"

@implementation RemoteTask
- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}
- (void)cancelTask{
    if (self.task && (self.task.state == NSURLSessionTaskStateRunning || self.task.state == NSURLSessionTaskStateSuspended)) {
        [self.task cancel];
    }
}
@end

@implementation RemoteDataTask
@end

@implementation RemoteUploadTask

- (id)init{
    if (self = [super init]) {
        self.uploadHandler = [ContentHandler new];
    }
    return self;
}

- (instancetype) initWithNetCapsulBinary:(HttpFileRequest*)binary{
    
    if (self = [self init]) {
        self.capsul = binary;
        if ([self.capsul isKindOfClass:[HttpFileRequest class]]){
            [_uploadHandler resetWithExpectedLength:[[(HttpFileRequest*)self.capsul getLocalFileSize] longLongValue]];
        }
    }
    return self;
}

@end

@implementation RemoteDownloadTask

-(id)init{
    
    if (self = [super init]) {
        self.downloadHandler = [ContentHandler new];
    }
    return self;
}

- (void)cancelTask{
    if (self.task && (self.task.state == NSURLSessionTaskStateRunning || self.task.state == NSURLSessionTaskStateSuspended)) {
        [(NSURLSessionDownloadTask*)self.task cancelByProducingResumeData:^(NSData *resumeData) {
            //now hold the resumeable data, until dispose from memory.
            self.resumeable = [NSData dataWithData:resumeData];
        }];
    }
}

@end
