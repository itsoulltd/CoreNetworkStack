//
//  NetCapsulBinary.m
//  RequestSynchronizer
//
//  Created by NGStack on 4/30/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "HttpFileRequest.h"
#import "HttpRequestHeader.h"
#import "CNDebugLog.h"

#define kBoundary @"0xKhTmLbOuNdArY"

@interface HttpFileRequest ()
@property (nonatomic, readonly) HTTP_METHOD http_method;
@property (nonatomic, readonly) Application_ContentType contentType;
@end

@implementation HttpFileRequest
@dynamic http_method;
@dynamic contentType;

- (void)updateValue:(id)value forKey:(NSString *)key{
    
    if ([key isEqualToString:@"localFileURL"]) {
        //
        self.localFileURL = [[NSURL alloc] initFileURLWithPath:value];
    }
    else{
        [super updateValue:value forKey:key];
    }
}

- (id)serializeValue:(id)value forKey:(NSString *)key{
    
    if ([key isEqualToString:@"localFileURL"]) {
        //
        if ([value isKindOfClass:[NSURL class]]) {
            return [((NSURL*)value) path];
        }
        return nil;
    }
    else{
        return [super serializeValue:value forKey:key];
    }
}

- (instancetype) initWithBaseUrl:(NSString*)baseUrl method:(HTTP_METHOD)httpMethod{
    if (self = [super initWithBaseUrl:baseUrl method:httpMethod contentType:Application_Multipart_FormData cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData]) {
        //
    }
    return self;
}

- (instancetype) initWithBaseUrl:(NSString*)baseUrl method:(HTTP_METHOD)httpMethod contentType:(Application_ContentType)contentType{
    
    if (self = [super initWithBaseUrl:baseUrl method:httpMethod contentType:Application_Multipart_FormData cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData]) {
        //
    }
    return self;
}

- (instancetype) initWithBaseUrl:(NSString*)baseUrl method:(HTTP_METHOD)httpMethod contentType:(Application_ContentType)contentType cachePolicy:(NSURLRequestCachePolicy)policy{
    
    if (self = [super initWithBaseUrl:baseUrl method:httpMethod contentType:Application_Multipart_FormData cachePolicy:policy]) {
        //
    }
    return self;
}

- (NSMutableURLRequest*) createMutableRequestWithPathComponent:(NSArray*)pathComponent{
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[self createUrlFromPath:pathComponent]];
    [request setHTTPMethod:[self getHTTPMethod:self.http_method]];
    
    //Now mutate the authentication Header info to request, if required.
    [self.requestHeaderFields mutateAuthenticationHeaderInfo:request];
    //set Content-Type
    NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    NSString *contentType = [NSString stringWithFormat:@"%@; charset=%@; boundary=%@", [self getApplicationContentType:self.contentType], charset, kBoundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    return request;
}

- (NSMutableData*) createMutableHTTPBodyData:(NSData*)data payload:(id<NGObjectProtocol>)payload dispositionName:(NSString*)name fileName:(NSString*)filename{
    
    //Creating Request HTTP body
    NSMutableData *tempPostData = [[NSMutableData alloc] init];
    [tempPostData appendData:[[NSString stringWithFormat:@"--%@\r\n", kBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Sample Key Value for data
    NSString *endBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n", kBoundary];
    NSDictionary *form = [payload serializeIntoInfo];
    if (form) {
        [form enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            
            NSString *valueStr = [self convertValue:obj forKey:key];
            
            [tempPostData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", (NSString*)key] dataUsingEncoding:NSUTF8StringEncoding]];
            [tempPostData appendData:[valueStr dataUsingEncoding:NSUTF8StringEncoding]];
            [tempPostData appendData:[endBoundary dataUsingEncoding:NSUTF8StringEncoding]];
        }];//
    }
    
    // Sample file to send as data
    [tempPostData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"; size=\"%lu\"\r\n", name, filename, (unsigned long)data.length] dataUsingEncoding:NSUTF8StringEncoding]];
    [tempPostData appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [tempPostData appendData:[NSData dataWithData:data]];
    [tempPostData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", kBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return tempPostData;
}

#pragma -mark Public Methods

- (NSNumber *)getLocalFileSize{
    
    if (!self.localFileURL) {
        return [NSNumber numberWithLong:0];
    }
    
    NSNumber *fileSize = nil;
    [self.localFileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
    [CNDebugLog message:[NSString stringWithFormat:@"FileSize : %.2f bytes",[fileSize doubleValue]]];
    
    return fileSize;
}

- (NSData*) getLocalFileData{
    
    if (!self.localFileURL) {
        return nil;
    }
    
    NSData *fileData = [[NSData alloc] initWithContentsOfURL:self.localFileURL options:NSDataReadingUncached error:NULL];
    return fileData;
}

- (NSInputStream *)getHTTPBodyStream{
    
    if (!self.localFileURL) {
        return nil;
    }
    //Check is fileUrl is local file url.
    BOOL isRemote = [[self.localFileURL scheme] isEqualToString:@"http"] || [[self.localFileURL scheme] isEqualToString:@"https"];
    if (isRemote) {
        [CNDebugLog message:@"File can't be send over network, because it is a remote URL."];
        return nil;
    }
    
    //@TODO Need More Optimization (File Operation)
    NSString *fileName = [[[self.localFileURL absoluteString] pathComponents] lastObject];
    NSData *fileData = [self getLocalFileData];
    NSMutableData *mData = [self createMutableHTTPBodyData:fileData payload:self.payLoad dispositionName:self.dispositionName fileName:fileName];
    NSInputStream *stream = [[NSInputStream alloc] initWithData:mData];
    //
    return stream;
}

- (NSData *)getHTTPBodyData{
    
    NSString *fileName = [[[self.localFileURL absoluteString] pathComponents] lastObject];
    NSData *fileData = [self getLocalFileData];
    return [self createMutableHTTPBodyData:fileData payload:self.payLoad dispositionName:self.dispositionName fileName:fileName];
}

- (NSURLRequest *)createRequest{
    
    return [self createRequestWithPathComponent:self.pathComponent payload:self.payLoad localFileUrl:self.localFileURL dispositionName:self.dispositionName];
}

- (NSURLRequest *)createThinRequest{
    
    return [self createMutableRequestWithPathComponent:self.pathComponent];
}

- (NSURLRequest *)createRequestWithPathComponent:(NSArray *)pathComponent payload:(id<NGObjectProtocol>)payload localFileUrl:(NSURL *)fileURL dispositionName:(NSString *)name{
    
    if (fileURL != self.localFileURL) {
        self.localFileURL = fileURL;
    }
    
    NSMutableURLRequest *request = [self createMutableRequestWithPathComponent:pathComponent];
    //Creating Request HTTP body stream
    NSInputStream *bodyStream = [self getHTTPBodyStream];
    //Setting HTTP Body stream.
    [request setHTTPBodyStream:bodyStream];
    return request;
}

- (NSURLRequest*) createRequestWithPathComponent:(NSArray*)pathComponent payload:(id<NGObjectProtocol>)payload fileData:(NSData*)data dispositionName:(NSString*)name fileName:(NSString*)filename{
    
    NSMutableURLRequest *request = [self createMutableRequestWithPathComponent:pathComponent];
    //Creating Request HTTP body
    NSMutableData *tempPostData = [self createMutableHTTPBodyData:data payload:payload dispositionName:name fileName:filename];
    //Setting HTTP Body data.
    [request setHTTPBody:tempPostData];
    return request;
}

@end
