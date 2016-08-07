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

@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableArray *cachedMessages;

-(void)SendMessage:(NSString*)message WithHeader:(NSString*)header;
-(NSArray*)GetCachedMessages;
-(void)ClearCachedMessages;

@end
