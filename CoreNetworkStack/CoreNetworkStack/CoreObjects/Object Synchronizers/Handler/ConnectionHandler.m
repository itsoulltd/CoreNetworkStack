//
//  ConnectionHandler.m
//  NGStackToolKitProject
//
//  Created by Towhid Islam on 9/13/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "ConnectionHandler.h"
#import "ContentHandler.h"
#import "HttpFileRequest.h"
#import "CNDebugLog.h"

@interface ConnectionHandler ()
@property (nonatomic, strong) NSURLResponse *response;
@end

@implementation ConnectionHandler

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

- (ContentHandler *)uploadHandler{
    
    if (!_uploadHandler) {
        _uploadHandler = [ContentHandler new];
        if ([self.capsul isMemberOfClass:[HttpFileRequest class]]){
            [_uploadHandler resetWithExpectedLength:[[(HttpFileRequest*)self.capsul getLocalFileSize] longLongValue]];
        }
    }
    return _uploadHandler;
}

- (ContentHandler *)downloadHandler{
    
    if (!_downloadHandler) {
        _downloadHandler = [ContentHandler new];
    }
    return _downloadHandler;
}

- (void) whenProgressFailedWithError:(NSError*)error{
    
    if (self.progressDelegate && [self.progressDelegate respondsToSelector:@selector(progressHandler:didFailedWithError:)]) {
        
        NSDictionary *userinfo = @{@"title":@"Network Operation Cenceled"
                                   ,@"message":@"Network operation has been canceled."};
        NSError *errorX = (error) ? error : [[NSError alloc] initWithDomain:@"com.remote.object.network.cancel" code:NetworkOperationCancel userInfo:userinfo];
        if ([self.capsul isMemberOfClass:[HttpFileRequest class]]) {
            [self.progressDelegate progressHandler:self.uploadHandler didFailedWithError:errorX];
            [self.uploadHandler resetWithExpectedLength:[[(HttpFileRequest*)self.capsul getLocalFileSize] longLongValue]];
        }else{
            [self.progressDelegate progressHandler:self.downloadHandler didFailedWithError:errorX];
            [self.downloadHandler resetWithExpectedLength:0];
        }
    }
}

#pragma mark NSURLConnectionDelegate

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
    
    if (redirectResponse == nil) {
        return request;
    } else {
        
        HttpWebRequest *nCapsul = [[self.capsul.class alloc] initWithBaseUrl:[[request URL] absoluteString] method:self.capsul.http_method contentType:self.capsul.contentType];
        if ([nCapsul isKindOfClass:[HttpFileRequest class]]) {
            ((HttpFileRequest*)nCapsul).localFileURL = ((HttpFileRequest*)self.capsul).localFileURL;
            ((HttpFileRequest*)nCapsul).dispositionName = ((HttpFileRequest*)self.capsul).dispositionName;
        }
        nCapsul.payLoad = self.capsul.payLoad;
        nCapsul.requestHeaderFields = self.capsul.requestHeaderFields;
        //nCapsul.pathComponent = self.capsul.pathComponent; //Should not pass, because it may alter redirect url.
        self.capsul = nCapsul;
        return [nCapsul createRequest];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    [CNDebugLog message:[NSString stringWithFormat:@"%@",response.description]];
    //
    self.response = response;
    [self.responseData setLength:0];
    //Data Download progress
    if (![self.capsul isMemberOfClass:[HttpFileRequest class]]){
        if (self.progressDelegate && [self.progressDelegate respondsToSelector:@selector(progressHandler:downloadPercentage:)])
            [self.downloadHandler resetWithResponse:(NSHTTPURLResponse*)response];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    if(self.responseData == nil){
        NSMutableData *tempRes = [[NSMutableData alloc] init];
        self.responseData = tempRes;
    }
    [self.responseData appendData:data];
    //Data Download progress
    if (![self.capsul isMemberOfClass:[HttpFileRequest class]]){
        if (self.progressDelegate && [self.progressDelegate respondsToSelector:@selector(progressHandler:downloadPercentage:)]) {
            
            float perc = [self.downloadHandler calculatePercentage:data.length];
            [self.progressDelegate progressHandler:self.downloadHandler downloadPercentage:perc];
            if (perc >= 100.0) {
                [self.downloadHandler resetWithExpectedLength:0];
            }
        }
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil; // never cache a response
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    if (self.responseData) {
        
        if (self.completionHandler != nil){
            
            NSData *data = [NSData dataWithData:self.responseData];
            NSURLResponse *response = [self.response copy];
            dispatch_async(self.queue, ^{
                
                self.completionHandler(data, response, nil);
            });
            [self setResponseData:nil];
            self.response = nil;
        }
    }
    else{
        
        if (self.completionHandler != nil){
            
            NSURLResponse *response = [self.response copy];
            dispatch_async(self.queue, ^{
                
                NSDictionary *userinfo = @{@"title":@"Network Error"
                                           ,@"message":@"You are not connected to internet. Check again!"};
                
                NSError *errorX = [[NSError alloc] initWithDomain:@"com.remote.object.network.error" code:NetworkOperationError userInfo:userinfo];
                
                self.completionHandler(nil, response, errorX);
            });
        }
    }
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    if (self.completionHandler != nil){
        
        NSURLResponse *response = [self.response copy];
        dispatch_async(self.queue, ^{
            
            self.completionHandler(nil, response, error);
        });
    }
    
    [self whenProgressFailedWithError:error];
}

/*!
 * Following two delegate impl, has been removed because of deprication in SDK
 */
/*
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}
*/
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge{
    
    NSURLCredential *credential = [self.capsul credentialForChallenge:challenge];
    
    if (!credential) {
        
        [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
    }else{
        
        if (challenge.previousFailureCount == 0) {
            
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        }else{
            
            [[challenge sender] cancelAuthenticationChallenge:challenge];
        }
    }
    
}

#pragma -mark Uploading Progress

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request{
    
    if ([self.capsul isMemberOfClass:[HttpFileRequest class]]) {
        return [(HttpFileRequest*)self.capsul getHTTPBodyStream];
    }
    return nil;
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite{
    
    //Data Upload progress
    if ([self.capsul isMemberOfClass:[HttpFileRequest class]]) {
        if (self.progressDelegate && [self.progressDelegate respondsToSelector:@selector(progressHandler:uploadPercentage:)]) {
            
            self.uploadHandler.totalByteRW = totalBytesWritten;
            self.uploadHandler.totalBytesExpectedToRW = totalBytesExpectedToWrite;
            
            float percentage = [self.uploadHandler calculatePercentage:bytesWritten];
            [self.progressDelegate progressHandler:self.uploadHandler uploadPercentage:percentage];
            
            if (totalBytesWritten >= totalBytesExpectedToWrite) {
                [self.uploadHandler resetWithExpectedLength:[[(HttpFileRequest*)self.capsul getLocalFileSize] longLongValue]];
            }
        }
    }
    
    [CNDebugLog message:[NSString stringWithFormat:@"bytesWritten=%ld, totalBytesWritten=%ld, totalBytesExpectedToWrite=%ld",(long)bytesWritten,(long)totalBytesWritten,(long)totalBytesExpectedToWrite]];
}

@end
