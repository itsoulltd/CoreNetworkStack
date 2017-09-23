//
//  SessionHandler.m
//  NGStackToolKitProject
//
//  Created by Towhid Islam on 9/13/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "SessionHandler.h"
#import "RemoteTask.h"
#import "ContentHandler.h"
@import CoreDataStack;
#import "HttpFileRequest.h"
#import "CNDebugLog.h"
#import "CommunicationHeader.h"

@implementation SessionHandler

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

- (void) increaseCounter{
    @synchronized(self){
        _backgroundTaskCounter++;
    }
}

- (void) decreaseCounter{
    @synchronized(self){
        _backgroundTaskCounter--;
    }
}

- (BOOL) isAllTaskDone{
    return _backgroundTaskCounter == 0;
}

- (void) executeCompletionHandlerFor:(NSURLSession*)session{
    //
    [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        //
        if ([dataTasks count] == 0 && [uploadTasks count] == 0 && [downloadTasks count] == 0) {
            //
            [self disposeCompletionHandlerFor:session.configuration.identifier];
        }
    }];
}

- (void) disposeCompletionHandlerFor:(NSString*)sessionIdentifier{
    //
    CompletionHandlerType handler = [self.completionHandlerDictionary objectForKey:sessionIdentifier];
    if (handler){
        [self.completionHandlerDictionary removeObjectForKey:sessionIdentifier];
        dispatch_async(dispatch_get_main_queue(), ^{
            [CNDebugLog message:@"Calling completion handler.\n"];
            handler();
        });
    }
}

- (void) removeTemporaryUploadFile:(RemoteUploadTask*)uploadTask{
    
    if (uploadTask.tempLocalFileURL) {
        //now remove the temp file from sendbox.
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:[uploadTask.tempLocalFileURL path]]) {
            NSError *error = nil;
            [fm removeItemAtURL:uploadTask.tempLocalFileURL error:&error];
            if (error) {
                [CNDebugLog message:[NSString stringWithFormat:@"%@",error.userInfo]];
            }
        }
    }
}

- (NSMutableData*) responseDataFor:(NSURLSessionDataTask*)task{
    
    NSMutableData *responseData = [self.responseDataMapper objectForKey:task];
    if (!responseData) {
        responseData = [NSMutableData new];
        [responseData setLength:0];
        [self.responseDataMapper setObject:responseData forKey:task];
    }
    return responseData;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    [self responseDataFor:dataTask];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
    NSMutableData *responseData = [self responseDataFor:dataTask];
    if (responseData) {
        [responseData appendData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    
    //
    [CNDebugLog message:[NSString stringWithFormat:@"%@ %@",task.description,task.response.description]];
    //
    RemoteTask *rTask = [self.taskMapper objectForKey:task];
    if (error == nil) {
        //new call success
        if (rTask) {
            if ([rTask isMemberOfClass:[RemoteDataTask class]] || [rTask isMemberOfClass:[RemoteUploadTask class]]) {
                RemoteDataTask *nTask = (RemoteDataTask*)rTask;
                //In-case of background upload, remove the temp file from sendbox
                if ([nTask isMemberOfClass:[RemoteUploadTask class]]) {
                    [self removeTemporaryUploadFile:(RemoteUploadTask*)nTask];
                }
                //
            }else{
                //Download task will be completed by download delegate handler
            }
        }
    }else{
        //In-Case of Background Download get failed. Make some resume and in-memory backup.
        if ([rTask isMemberOfClass:[RemoteDownloadTask class]]) {
            RemoteDownloadTask *dTask = (RemoteDownloadTask*)rTask;
            NSData *resumeData = [[error userInfo] objectForKey:NSURLSessionDownloadTaskResumeData];
            dTask.resumeable = [NSData dataWithData:resumeData];
        }
        //In-case of background upload, remove the temp file from sendbox
        if ([rTask isMemberOfClass:[RemoteUploadTask class]]) {
            [self removeTemporaryUploadFile:(RemoteUploadTask*)rTask];
        }
        //
    }
    
    //now call the completion handler
    if ([rTask isKindOfClass:[RemoteDownloadTask class]]) {
        //The call of DownloadTask completion handler here, because of download failer.
        //Success actually handled by Download didFinishDownloadingToURL:
        //otherwise it will call twice.
        if (error != nil && ((RemoteDownloadTask*)rTask).completionHandler) {
            
            NSURLResponse *response = [((RemoteDownloadTask*)rTask).task.response copy];
            
            dispatch_async(rTask.queue, ^{
                ((RemoteDownloadTask*)rTask).completionHandler(nil, response, error);
            });
        }
    }else{
        
        if (((RemoteDataTask*)rTask).completionHandler) {
            
            NSData *receivedData = [[NSData alloc] initWithData:[self.responseDataMapper objectForKey:task]];
            NSURLResponse *response = [((RemoteDataTask*)rTask).task.response copy];
            
            dispatch_async(rTask.queue, ^{
                ((RemoteDataTask*)rTask).completionHandler(receivedData, response, error);
            });
        }
    }
    
    if (rTask){
        [self decreaseCounter];
        [self.taskMapper removeObjectForKey:task];
        [self.responseDataMapper removeObjectForKey:task];
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    //
    [CNDebugLog message:@"background session complete"];
    [self executeCompletionHandlerFor:session];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler{
    //
    if (response == nil) {
        return completionHandler(request);
    } else {
        
        RemoteTask *rTask = [self.taskMapper objectForKey:task];
        if (rTask) {
            HttpWebRequest *nCapsul = [[rTask.capsul.class alloc] initWithBaseUrl:[[request URL] absoluteString] method:rTask.capsul.http_method contentType:rTask.capsul.contentType];
            if ([nCapsul isKindOfClass:[HttpFileRequest class]]) {
                ((HttpFileRequest*)nCapsul).localFileURL = ((HttpFileRequest*)rTask.capsul).localFileURL;
                ((HttpFileRequest*)nCapsul).dispositionName = ((HttpFileRequest*)rTask.capsul).dispositionName;
            }
            nCapsul.payLoad = rTask.capsul.payLoad;
            nCapsul.requestHeaderFields = rTask.capsul.requestHeaderFields;
            //nCapsul.pathComponent = self.capsul.pathComponent; //Should not pass, because it may alter redirect url.
            rTask.capsul = nCapsul;
            completionHandler([nCapsul createRequest]);
        }
    }
}

#pragma -mark Authentication del

/**
 * Have to read more about auth challange @TODO
 */

//- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler{
//    //
//    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling,nil);
//}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler{
    //
    
    RemoteTask *rTask = [self.taskMapper objectForKey:task];
    NSURLCredential *credential = [rTask.capsul credentialForChallenge:challenge];
    
    if (!credential) {
        
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling,nil);
    }else{
        
        if (challenge.previousFailureCount == 0) {
            
            completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
        }else{
            
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);
        }
    }
}

#pragma -mark download del

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    //
    RemoteDownloadTask *dTask = [self.taskMapper objectForKey:downloadTask];
    if (dTask && dTask.completionHandler) {
        NSURLResponse *response = [dTask.task.response copy];
        dTask.completionHandler(location, response, nil);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes{
    //
    RemoteDownloadTask *dTask = [self.taskMapper objectForKey:downloadTask];
    if (dTask && dTask.progressDelegate && [dTask.progressDelegate respondsToSelector:@selector(progressHandler:downloadPercentage:)]) {
        
        dTask.downloadHandler.byteReceived = (unsigned long) fileOffset;
        dTask.downloadHandler.expectedLength = downloadTask.response.expectedContentLength;
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    //
    RemoteDownloadTask *dTask = [self.taskMapper objectForKey:downloadTask];
    if (dTask && dTask.progressDelegate && [dTask.progressDelegate respondsToSelector:@selector(progressHandler:downloadPercentage:)]) {
        
        dTask.downloadHandler.totalByteRW = totalBytesWritten;
        dTask.downloadHandler.totalBytesExpectedToRW = totalBytesExpectedToWrite;
        
        if (dTask.downloadHandler.byteReceived == 0) {
            [dTask.downloadHandler resetWithResponse:(NSHTTPURLResponse*)downloadTask.response];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //
            float percentage = [dTask.downloadHandler calculatePercentage:(unsigned long)bytesWritten];
            [dTask.progressDelegate progressHandler:dTask.downloadHandler downloadPercentage:percentage];
            if (totalBytesWritten >= totalBytesExpectedToWrite) {
                [dTask.downloadHandler resetWithExpectedLength:0];
            }
        });
    }
    
    [CNDebugLog message:[NSString stringWithFormat:@"bytesWritten=%ld, totalBytesWritten=%ld, totalBytesExpectedToWrite=%ld",(long)bytesWritten,(long)totalBytesWritten,(long)totalBytesExpectedToWrite]];
}

#pragma -mark upload del

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *))completionHandler{
    //
    RemoteUploadTask *uTask = (RemoteUploadTask*)[self.taskMapper objectForKey:task];
    if ([uTask.capsul isKindOfClass:[HttpFileRequest class]]) {
        completionHandler([(HttpFileRequest*)uTask.capsul getHTTPBodyStream]);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    //
    RemoteUploadTask *uTask = (RemoteUploadTask*)[self.taskMapper objectForKey:task];
    //Data Upload progress
    if (uTask) {
        if ([uTask.capsul isKindOfClass:[HttpFileRequest class]]) {
            if (uTask.progressDelegate && [uTask.progressDelegate respondsToSelector:@selector(progressHandler:uploadPercentage:)]) {
                
                uTask.uploadHandler.totalByteRW = totalBytesSent;
                uTask.uploadHandler.totalBytesExpectedToRW = totalBytesExpectedToSend;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    //
                    float percentage = [uTask.uploadHandler calculatePercentage:(unsigned long)bytesSent];
                    [uTask.progressDelegate progressHandler:uTask.uploadHandler uploadPercentage:percentage];
                    if (totalBytesSent >= totalBytesExpectedToSend) {
                        [uTask.uploadHandler resetWithExpectedLength:[[(HttpFileRequest*)uTask.capsul getLocalFileSize] longLongValue]];
                    }
                });
            }
        }
    }
    
    [CNDebugLog message:[NSString stringWithFormat:@"bytesSent=%ld, totalBytesSent=%ld, totalBytesExpectedToSend=%ld",(long)bytesSent,(long)totalBytesSent,(long)totalBytesExpectedToSend]];
}

@end
