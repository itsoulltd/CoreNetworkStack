//
//  NSData+Hash.h
//  NGStackToolKitProject
//
//  Created by Towhid Islam on 10/19/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (NGStackHash)

- (NSData*) NGStack_MD5;

- (NSData*) NGStack_SHA1;

- (NSData*) NGStack_SHA256;

@end
