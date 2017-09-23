//
//  AuthenticationInfo.m
//  RequestSynchronizer
//
//  Created by Towhid Islam on 5/17/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "HttpRequestHeader.h"
#import "CNDebugLog.h"

@interface HttpRequestHeader ()
@property (nonatomic, strong) NSMutableDictionary *headerFields;
@end

@implementation HttpRequestHeader

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

- (void)updateValue:(id)value forKey:(NSString *)key{
    
    if ([key isEqualToString:@"headerFields"]) {
        if ([value isKindOfClass:[NSDictionary class]]) {
            self.headerFields = [[NSMutableDictionary alloc] initWithDictionary:value];
        }
    }else{
        [super updateValue:value forKey:key];
    }
}

+ (instancetype)createAuthHeaderWithFields:(NSDictionary *)fields andKey:(NSString*)key{
    
    HttpRequestHeader *info = [[HttpRequestHeader alloc] init];
    
    if (key && fields) {
        [info.headerFields setObject:[NSMutableDictionary dictionaryWithDictionary:fields] forKey:key];
    }
    return info;
}

+ (instancetype)createAuthHeaderWithValues:(NSArray *)values andKey:(NSString *)key{
    
    HttpRequestHeader *info = [[HttpRequestHeader alloc] init];
    
    if (key && values) {
        [info.headerFields setObject:[NSMutableArray arrayWithArray:values] forKey:key];
    }
    return info;
}

- (instancetype)init{
    
    if (self = [super init]) {
        self.headerFields = [[NSMutableDictionary alloc] initWithCapacity:7];
    }
    return self;
}

- (void)addValues:(NSArray *)values forKey:(NSString *)key{
    //
    if (!values) {
        return;
    }
    id lValues = [self.headerFields objectForKey:key];
    if (lValues) {
        if ([lValues isKindOfClass:[NSMutableArray class]]) {
            [(NSMutableArray*)lValues addObjectsFromArray:values];
        }
    }
    else{
        [self.headerFields setObject:[NSMutableArray arrayWithArray:values] forKey:key];
    }
}

- (void) addFields:(NSDictionary*)fields forKey:(NSString*)key{
    //
    if (!fields) {
        return;
    }
    id lFields = [self.headerFields objectForKey:key];
    if (lFields) {
        if ([lFields isKindOfClass:[NSMutableDictionary class]]) {
            [(NSMutableDictionary*)lFields addEntriesFromDictionary:fields];
        }
    }
    else{
        [self.headerFields setObject:[NSMutableDictionary dictionaryWithDictionary:fields] forKey:key];
    }
}

- (void) mutateAuthenticationHeaderInfo:(NSMutableURLRequest*)request{
    
    @synchronized(self.headerFields){
        NSArray *allKeys = [self.headerFields allKeys];
        for (NSString *key in allKeys) {
            NSString *fieldValues = [self getFormattedFields:[self.headerFields objectForKey:key]];
            [CNDebugLog message:fieldValues];
            [self mutateRequest:request withFieldsValue:fieldValues forHTTPHeaderField:key];
        }
    }
}

- (NSString*) getFormattedFields:(id)collection{
    
    NSMutableString *authHeader = [[NSMutableString alloc] init];
    
    if ([collection isKindOfClass:[NSArray class]]) {
        //Handle Values
        NSArray *values = (NSArray*)collection;
        for (NSInteger index = 0; index < values.count; index++) {
            //[authHeader appendFormat:@"\"%@\"",values[index]]; //It was a bug, Quotes must not be there.
            [authHeader appendFormat:@"%@",values[index]];
            if (index != values.count - 1) {
                [authHeader appendString:@","];
            }
        }
    }
    else{
        //Handle Key-Value pairs
        NSDictionary *fields = (NSDictionary*)collection;
        NSArray *allKeys = [fields allKeys];
        NSString *lastKey = [allKeys lastObject];
        for (NSString *key in allKeys) {
            //[authHeader appendFormat:@"%@=\"%@\"",key,[fields objectForKey:key]]; //It was a bug, Quotes must not be there.
            [authHeader appendFormat:@"%@=%@",key,[fields objectForKey:key]];
            if (![key isEqualToString:lastKey]) {
                [authHeader appendString:@","];
            }
        }
    }
    return authHeader;
}

- (void) mutateRequest:(NSMutableURLRequest*)request withFieldsValue:(NSString*)value forHTTPHeaderField:(NSString*)key{
    
    if (self.isEncodingEnabled) {
        //Implementation of Base64 encryption on full header data.
        NSData *headerAuthData = [value dataUsingEncoding:NSUTF8StringEncoding];
        NSString *headerEncodedVal = [headerAuthData base64EncodedStringWithOptions:0];
        [CNDebugLog message:headerEncodedVal];
        [request setValue:headerEncodedVal forHTTPHeaderField:key];
    }
    else{
        [request setValue:value forHTTPHeaderField:key];
    }
}

@end
