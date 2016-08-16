//
//  Scrambler.h
//  GenesisPlus
//
//  Created by Alistair Aitcheson on 29/07/2016.
//  Copyright 2016 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Scrambler : NSObject {
    
}

@property NSMutableArray *parameters;
@property NSMutableArray *editHistory;
@property NSString *readPath, *logPath;
@property BOOL updatingDefs;
@property (nonatomic, strong) NSMutableDictionary *usageCounts;

-(void)UpdateDefinitions;
-(void)ActivateOnCondition:(NSString*)condition;
-(uint)uIntFromNSString:(NSString*)string;
-(void)RegisterInHistory_Addr:(uint)addr Was:(uint)was Became:(uint)became OnMem:(int)onMem;
-(void)RequestDefsFromBackground;

@end
