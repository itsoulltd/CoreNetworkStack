//
//  NSString+Hash.h
//  NGStackToolKitProject
//
//  Created by Towhid Islam on 10/19/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (NGStackHash)

- (NSString*) NGStack_MD5;

- (NSString*) NGStack_SHA1;

- (NSString*) NGStack_SHA256;
@end
