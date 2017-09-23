//
//  RemoteObjectProgressHandler.m
//  RequestSynchronizer
//
//  Created by Towhid Islam on 7/28/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import "ContentHandler.h"
#import "CNDebugLog.h"

@implementation ContentHandler

- (void)dealloc{
    [CNDebugLog message:@"dealloc %@",NSStringFromClass([self class])];
}

- (float)calculatePercentage:(unsigned long)length{
    
    self.byteReceived += length;
    
    if (self.expectedLength != NSURLResponseUnknownLength) {
        
        float percentComplete = (self.byteReceived/(float)self.expectedLength)*100.0;
        [CNDebugLog message:[NSString stringWithFormat:@"Percentage : %.2f",percentComplete]];
        return percentComplete;
    }else{
        [CNDebugLog message:[NSString stringWithFormat:@"Byte Received : %lu",self.byteReceived]];
        return 0.0;
    }
}

- (void)resetWithExpectedLength:(unsigned long long)expectedLength{
    
    self.expectedLength = expectedLength;
    self.byteReceived = 0;
    self.mimeType = nil;
    self.suggestedFileName = nil;
    self.textEncodingName = nil;
}

- (void)resetWithResponse:(NSHTTPURLResponse *)response{
    
    self.expectedLength = response.expectedContentLength;
    self.byteReceived = 0;
    self.mimeType = response.MIMEType;
    self.suggestedFileName = response.suggestedFilename;
    self.textEncodingName = response.textEncodingName;
}

@end
