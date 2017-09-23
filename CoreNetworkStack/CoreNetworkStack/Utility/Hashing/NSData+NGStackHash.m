//
//  NSData+Hash.m
//  NGStackToolKitProject
//
//  Created by Towhid Islam on 10/19/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "NSData+NGStackHash.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (NGStackHash)

- (NSData*) NGStack_MD5 {
    unsigned int outputLength = CC_MD5_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_MD5(self.bytes, (unsigned int) self.length, output);
    return [NSMutableData dataWithBytes:output length:outputLength];
}

- (NSData*) NGStack_SHA1 {
    unsigned int outputLength = CC_SHA1_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_SHA1(self.bytes, (unsigned int) self.length, output);
    return [NSMutableData dataWithBytes:output length:outputLength];
}

- (NSData*) NGStack_SHA256 {
    unsigned int outputLength = CC_SHA256_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_SHA256(self.bytes, (unsigned int) self.length, output);
    return [NSMutableData dataWithBytes:output length:outputLength];
}

@end
