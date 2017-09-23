//
//  NetCapsul.m
//  RequestSynchronizer
//
//  Created by NGStack on 4/30/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "HttpWebRequest.h"
#import "HttpRequestHeader.h"
#import "CNDebugLog.h"

@interface HttpWebRequest ()
@property (nonatomic, strong) NSString *baseUrl;
@property (nonatomic, strong) NSString *payloadClassName;
@property (nonatomic, assign) HTTP_METHOD http_method;
@property (nonatomic, assign) Application_ContentType contentType;
@property (nonatomic) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong) NSString *password;
@property (nonatomic) NSURLCredentialPersistence credentialPersistence;
@end

@implementation HttpWebRequest

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

- (void)updateValue:(id)value forKey:(NSString*)key{
    
    if ([(NSString*)key isEqualToString:@"http_method"]) {
        self.http_method = [(NSNumber*)value intValue];
    }
    else if ([(NSString*)key isEqualToString:@"contentType"]) {
        self.contentType = [(NSNumber*)value intValue];
    }
    else if ([(NSString*)key isEqualToString:@"cachePolicy"]) {
        self.cachePolicy = [(NSNumber*)value integerValue];
    }
    else if ([(NSString*)key isEqualToString:@"payLoad"]) {
        
        //trying to restore payload
        @try {
            if (self.payloadClassName) {
                if (![NSClassFromString(self.payloadClassName) isSubclassOfClass:[NGObject class]]) {
                    [CNDebugLog message:@"%@ can't re-construct from archived data.",NSStringFromClass([self.payLoad class])];
                    return;
                }
                
                NGObject *obj = [[NSClassFromString(self.payloadClassName) alloc] init];
                if ([value isKindOfClass:[NSDictionary class]]) {
                    [obj updateWithInfo:value];
                }
                self.payLoad = obj;
            }else{
                self.payLoad = value;
            }
        }
        @catch (NSException *exception) {
            self.payLoad = nil;
            [CNDebugLog message:@"%@",exception.debugDescription];
        }
    }
    else if ([(NSString*)key isEqualToString:@"payloadClassName"]){
        
        self.payloadClassName = value;
        //trying to restore payload
        if (self.payloadClassName && self.payLoad) {
            if (![NSClassFromString(self.payloadClassName) isSubclassOfClass:[NGObject class]]) {
                [CNDebugLog message:@"%@ can't re-construct from archived data.",NSStringFromClass([self.payLoad class])];
                return;
            }
            
            NGObject *obj = [[NSClassFromString(self.payloadClassName) alloc] init];
            if ([self.payLoad isKindOfClass:[NSDictionary class]]) {
                [obj updateWithInfo:(NSDictionary*)self.payLoad];
            }
            self.payLoad = obj;
        }
    }
    else{
        [super updateValue:value forKey:key];
    }
}

- (void)setPayLoad:(id<NGObjectProtocol>)payLoad{
    
    _payLoad = payLoad;
    if (_payLoad && [_payLoad isKindOfClass:[NGObject class]]) {
        self.payloadClassName = NSStringFromClass([_payLoad class]);
    }
}

- (HttpRequestHeader *)requestHeaderFields{
    if (_requestHeaderFields == nil) {
        _requestHeaderFields = [[HttpRequestHeader alloc] init];
    }
    return _requestHeaderFields;
}

- (instancetype)initWithBaseUrl:(NSString *)baseUrl{
    
    if (self = [self initWithBaseUrl:baseUrl method:GET contentType:Application_Form_URLEncoded cachePolicy:NSURLRequestReloadIgnoringLocalCacheData]) {
        //
    }
    return self;
}

- (instancetype)initWithBaseUrl:(NSString *)baseUrl method:(HTTP_METHOD)httpMethod{
    
    if (self = [self initWithBaseUrl:baseUrl method:httpMethod contentType:Application_Form_URLEncoded cachePolicy:NSURLRequestReloadIgnoringLocalCacheData]) {
        //
    }
    return self;
}

- (instancetype) initWithBaseUrl:(NSString*)baseUrl method:(HTTP_METHOD)httpMethod contentType:(Application_ContentType)contentType{
    
    if (self = [self initWithBaseUrl:baseUrl method:httpMethod contentType:contentType cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData]) {
        //
    }
    return self;
}

- (instancetype) initWithBaseUrl:(NSString*)baseUrl method:(HTTP_METHOD)httpMethod contentType:(Application_ContentType)contentType cachePolicy:(NSURLRequestCachePolicy)policy{
    
    if (self = [super init]) {
        self.baseUrl = [self validateBaseUrl:baseUrl];
        self.http_method = httpMethod;
        self.contentType = contentType;
        self.cachePolicy = policy;
    }
    return self;
}

- (NSURLRequest *)createRequest{
    
    return [self createRequestWithPathComponent:self.pathComponent andPayload:self.payLoad];
}

- (NSURLRequest*) createRequestWithPathComponent:(NSArray*)pathComponent andPayload:(id<NGObjectProtocol>)payload{
    
    NSMutableURLRequest *request = nil;
    self.payLoad = payload;
    
    if (self.http_method == GET) {
        
        if (!payload) {
            request = [[NSMutableURLRequest alloc] initWithURL:[self createUrlFromPath:pathComponent]];
        }else{
            NSString *path = [NSString stringWithFormat:@"%@%@",[self appendPaths:pathComponent],[self convertToKeyValuePair:[payload serializeIntoInfo]]];
            request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:path]];
        }
        
        [request setCachePolicy:self.cachePolicy];
        [request setHTTPMethod:[self getHTTPMethod:GET]];
    }
    else{
        
        NSURL *url = [self createUrlFromPath:pathComponent];
        request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setCachePolicy:self.cachePolicy];
        [request setHTTPMethod:[self getHTTPMethod:self.http_method]];
        [request setValue:[self getApplicationContentType:self.contentType] forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[self convertToBinary:[payload serializeIntoInfo]]];
    }
    [self httpRequestConfiguration:request];
    //Now mutate the authentication Header info to request, if required.
    [self.requestHeaderFields mutateAuthenticationHeaderInfo:request];
    
    return request;
}

- (NSString *) convertValue:(id)value forKey:(NSString*)key{
    
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    else if ([value isKindOfClass:[NSDate class]]){
        return [self serializeDate:value forKey:key];
    }
    else if ([value isKindOfClass:[NSString class]]){
        return value;
    }
    else{
        return @"";
    }
}

- (void)httpRequestConfiguration:(NSMutableURLRequest *)request{
    [CNDebugLog message:@"By default Nothing to say"];
}

#pragma -mark private methods

- (NSString*) validateBaseUrl:(NSString*)url{
    
    NSMutableString *valide = [[NSMutableString alloc] initWithString:[url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    
    while ([valide hasSuffix:@"/"] ^ [valide hasSuffix:@"&"] ^ [valide hasSuffix:@"?"] ^ [valide hasSuffix:@"#"] ^ [valide hasSuffix:@"$"]
           ^ [valide hasSuffix:@"@"] ^ [valide hasSuffix:@"!"] ^ [valide hasSuffix:@"^"] ^ [valide hasSuffix:@"*"]) {
        [valide deleteCharactersInRange:NSMakeRange((valide.length - 1), 1)];
    }
    
    return valide;
}

- (NSURL*) createUrlFromPath:(NSArray*)path{
    
    return [[NSURL alloc] initWithString:[self appendPaths:path]];
}

- (NSString*) appendPaths:(NSArray*)pathComponent{
    
    if (!pathComponent || 0 == pathComponent.count) {
        return self.baseUrl;
    }
    
    NSMutableString *urlStr = [[NSMutableString alloc] initWithString:[self baseUrl]];
    for (NSString* px in pathComponent) {
        [urlStr appendFormat:@"/%@",px];
    }
    return urlStr;
}

- (NSString *)getApplicationContentType:(Application_ContentType)contentType{
    switch (contentType) {
        case Application_Form_URLEncoded:
            return @"application/x-www-form-urlencoded";
            break;
        case Application_JSON:
            return @"application/json";//@"application/json; charset=utf-8"
            break;
        case Application_XML:
            return @"application/xml";
            break;
        case Application_PLIST:
            return @"application/x-plist";
            break;
        case Application_Multipart_FormData:
            return @"multipart/form-data";
            break;
        default:
            return @"text/plain";
            break;
    }
}

- (NSString *)getHTTPMethod:(HTTP_METHOD)method{
    
    switch (method) {
        case PUT:
            return @"PUT";
            break;
        case DELETE:
            return @"DELETE";
            break;
        case POST:
            return @"POST";
            break;
        default:
            return @"GET";
            break;
    }
}

- (NSData *)convertToBinary:(NSDictionary *)_data{
	
	NSMutableString *body = [[NSMutableString alloc] init];
	
	if (_data) {
		if (self.contentType == Application_Form_URLEncoded) {
            for (NSString *key in _data) {
                
                id value = [_data objectForKey:key];
                NSString *valueStr = [self convertValue:value forKey:key];
                if ([body length] > 0) [body appendString:@"&"];
                [body appendString:[key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                [body appendString:@"="];
                [body appendString:[valueStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
            return  [[NSData alloc] initWithData:[body dataUsingEncoding:NSUTF8StringEncoding]];
        }
        else if (self.contentType == Application_JSON){
            NSError *error;
            NSData *data = [NSJSONSerialization dataWithJSONObject:_data options:NSJSONWritingPrettyPrinted error:&error];
            return [[NSData alloc] initWithData:data];
        }
        else{
            NSMutableString *str = [NSMutableString stringWithFormat:@"%@",_data];
            return [[NSData alloc] initWithData:[str dataUsingEncoding:NSUTF32StringEncoding]];
        }
	}
    return  nil;
}

- (NSString *)convertToKeyValuePair:(NSDictionary *)_data{
	
	NSMutableString *body = [[NSMutableString alloc] init];
	
	if (_data) {
		for (NSString *key in _data) {
            id value = [_data objectForKey:key];
            if (value == nil || [value isKindOfClass:[NSNull class]]) {
                continue;
            }
            if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSMutableArray class]]) {
                for (id itemValue in ((NSArray*)value)) {
                    NSString *valueStr = [self convertValue:itemValue forKey:key];
                    [self append:body value:valueStr key:key];
                }
            }else{
                NSString *valueStr = [self convertValue:value forKey:key];
                [self append:body value:valueStr key:key];
            }
        }
	}
    NSString *result = [NSString stringWithFormat:@"?%@",body];
    [CNDebugLog message:result];
    return  result;
}

- (NSMutableString*) append:(NSMutableString*)body value:(NSString*)valueStr key:(NSString*)key{
    if ([body length] > 0) [body appendString:@"&"];
    [body appendString:[key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [body appendString:@"="];
    [body appendString:[valueStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return body;
}

- (void)updateCredentialWithUser:(NSString *)userId andPassword:(NSString *)password{
    
    [self updateCredentialWithUser:userId andPassword:password persistance:NSURLCredentialPersistenceSynchronizable];
}

- (void)updateCredentialWithUser:(NSString *)userId andPassword:(NSString *)password persistance:(NSURLCredentialPersistence)persistence{
    
    _authenticationEnabled = YES;
    self.userName = userId;
    self.password = password;
    self.credentialPersistence = persistence;
}

- (NSURLCredential *)credentialForChallenge:(NSURLAuthenticationChallenge*)challenge{
    
    NSString *method = challenge.protectionSpace.authenticationMethod;
    
    if ([method isEqualToString:NSURLAuthenticationMethodHTTPBasic]) {
        
        if (!self.userName || !self.password) {
            [CNDebugLog message:@"Please call -updateCredentialWithUser:andPassword:"];
            return nil;
        }
        else{
            return [NSURLCredential credentialWithUser:self.userName password:self.password persistence:self.credentialPersistence];
        }
    }
    else if ([method isEqualToString:NSURLAuthenticationMethodHTTPDigest]) {
        
        if (!self.userName || !self.password) {
            [CNDebugLog message:@"Please call -updateCredentialWithUser:andPassword:"];
            return nil;
        }
        else{
            return [NSURLCredential credentialWithUser:self.userName password:self.password persistence:self.credentialPersistence];
        }
    }
    else if ([method isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        return [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    }
    else{
        
        [CNDebugLog message:@"Please implement explicite authentication challange method."];
        return nil;
    }
}

@end
