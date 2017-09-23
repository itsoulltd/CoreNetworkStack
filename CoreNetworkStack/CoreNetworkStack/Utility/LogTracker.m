//
//  LogTracker.m
//  RequestSynchronizer
//
//  Created by Towhid Islam on 8/25/14.
//  Copyright (c) 2014 Towhid Islam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LogTracker.h"
#import <CoreDataStack/PropertyList.h>
#import "HttpFileRequest.h"
#import "RemoteSession.h"
#import "RemoteConnection.h"

@interface LogTracker (){
    NSUInteger __maxCapacity;
    dispatch_queue_t __serialKiller;
}
@property (nonatomic, strong) NSMutableArray *logBook;
@property (nonatomic, strong) NSDateFormatter *formatter;
@property (nonatomic, strong) NSString *fileName;
@end

@implementation LogTracker

- (instancetype) initWithPersistenceFileName:(NSString*)fileName{
    
    if (self = [super init]) {
        //
        self.fileName = fileName;
        __maxCapacity = 100;
        __serialKiller = dispatch_queue_create([fileName UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc{
    NSLog(@"dealloc %@",NSStringFromClass([self class]));
}

- (NSMutableArray *)logBook{
    
    if (!_logBook) {
        _logBook = [[NSMutableArray alloc] initWithCapacity:__maxCapacity];
    }
    return _logBook;
}

- (NSDateFormatter *)formatter{
    
    if (!_formatter) {
        _formatter = [[NSDateFormatter alloc] init];
        [_formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    }
    return _formatter;
}

- (PropertyList*) getManager{
    
    PropertyList *_manager = [[PropertyList alloc] initWithFileName:self.fileName directoryType:NSDocumentDirectory dictionary:NO];
    return _manager;
}

- (void) addToLogBook:(NSString*)log{
    
    dispatch_async(__serialKiller, ^{
        NSDate *now = [NSDate date];
        NSString *key = [self.formatter stringFromDate:now];
        [self.logBook addObject:[NSString stringWithFormat:@"[%@] :> %@",key,log]];
        if (self.logBook.count == __maxCapacity) {
            [self save];
        }
    });
}

- (void)save{
    
    dispatch_async(__serialKiller, ^{
        //First load manager.
        PropertyList *manager = [self getManager];
        //save to manager.
        NSArray *tempBook = [[NSArray alloc] initWithArray:self.logBook copyItems:YES];
        //remove all from logbook.
        [[self logBook] removeAllObjects];
        [manager addItemsToCollection:tempBook];
        [manager save];
        manager = nil;
    });
}

- (void)printSavedLog{
    
    dispatch_async(__serialKiller, ^{
        PropertyList *manager = [self getManager];
        id collection = [manager readOnlyCollection];
        manager = nil;
        NSLog(@"%@",collection);
    });
}

- (void)sendFeedbackTo:(HttpFileRequest *)binary{
    
    dispatch_async(__serialKiller, ^{
        PropertyList *manager = [self getManager];
        binary.localFileURL = [manager storageLocation];
        manager = nil;
        
        if ([[UIDevice currentDevice].systemVersion compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending){
            
            RemoteSession *remoteObject = [RemoteSession defaultSession];
            [remoteObject uploadContent:binary progressDelegate:nil onCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
                //
            }];
        }else{
            RemoteConnection *remoteObject = [RemoteConnection new];
            [remoteObject sendAsynchronusMessage:binary onCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
                //
            }];
        }
    });
}

@end
