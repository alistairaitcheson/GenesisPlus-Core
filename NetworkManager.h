//
//  NetworkManager.h
//  GenesisPlus
//
//  Created by Alistair Aitcheson on 05/08/2016.
//  Copyright 2016 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkManager : NSObject <NSStreamDelegate> {
    
}

@property BOOL allowTracking;
@property (nonatomic, strong) NSArray *trackVars;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableArray *cachedMessages;
@property (nonatomic, strong) NSString *startTime;

@property (nonatomic, strong) NSMutableArray *writeCache;
@property BOOL writeCacheReady;
@property (nonatomic, strong) NSThread *thread;

-(void)SendMessage:(NSString*)message WithHeader:(NSString*)header;
-(NSArray*)GetCachedMessages;
-(void)ClearCachedMessages;
-(NSString*)timeStampAsNumber;

-(void)Refresh;
-(void)Close;

@end
