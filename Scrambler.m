//
//  Scrambler.m
//  GenesisPlus
//
//  Created by Alistair Aitcheson on 29/07/2016.
//  Copyright 2016 __MyCompanyName__. All rights reserved.
//

#import "Scrambler.h"
#import "GenPlusGameCore.h"
#include "shared.h"
#include "scrc32.h"
#include "NetworkManager.h"

@implementation Scrambler

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.editHistory = [NSMutableArray array];
    
        
        NSString *currentpath = [GenPlusGameCore PathString];
        
        self.readPath = [currentpath stringByAppendingString:@"memorycommands.txt"];
        self.logPath = [currentpath stringByAppendingString:@"GenesisLog.txt"];
        
        FILE *testDoc = fopen([[currentpath stringByAppendingString:@"SCRAMBLER_START.txt"] UTF8String], "w");
        fclose(testDoc);

        [[NSFileManager defaultManager] createFileAtPath:[currentpath stringByAppendingString:@"here_it_is.txt"]
                                                contents:nil
                                              attributes:nil];
    }
    return self;
}

-(void)UpdateDefinitions
{
    self.parameters = [NSMutableArray array];

    NSString *source = [NSString stringWithContentsOfFile:self.readPath
                                                 encoding:NSASCIIStringEncoding
                                                    error:nil];
    
    for (NSString *component in [source componentsSeparatedByString:@"\n"]) {
        NSDictionary *dict = [self DictFromString:component];
        if (dict) [self.parameters addObject:dict];
    }
}

-(NSDictionary*)DictFromString:(NSString*)source
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if ([source hasPrefix:@"//"]) {
        return nil;
    }
    
    NSArray *components = [source componentsSeparatedByString:@","];
    for (NSString *field in components) {
        NSArray *split = [field componentsSeparatedByString:@":"];
        if ([split count] > 1) {
            [dict setObject:split[1] forKey:split[0]];
        }
    }
    
    if (!dict[@"trigger"]) dict[@"trigger"] = @"always";
    if (!dict[@"edit"]) dict[@"edit"] = @"scramble";
    if (!dict[@"repeat"]) dict[@"repeat"] = @"1";
    
    dict[@"SOURCE"] = source;
    
    return dict;
}

-(void)ActivateOnCondition:(NSString*)condition
{
    for (NSDictionary *param in self.parameters) {
        BOOL canPerform = [param[@"trigger"] isEqualToString:condition];
        if ([condition hasPrefix:@"timer_"] && [param[@"trigger"] hasPrefix:@"timer_"])
        {
//            WriteToLog("has prefix timer");
            NSString *timeStr = [condition substringFromIndex:6];
//            WriteToLog("got time string");
            uint inputTime = (uint)[timeStr intValue];
//            WriteToLog("got inputTime");

            NSString *myTimeStr = [param[@"trigger"] substringFromIndex:6];
//            WriteToLog("got myTimeStr");
            uint period = (uint)[myTimeStr intValue];
//            WriteToLog("got period");
            
            if (inputTime % period == 0)
            {
//                WriteToLog("can perform");
                canPerform = YES;
            }
        }
        
        if (canPerform) {
            if (param[@"network"])
            {
                SendNetworkEvent((char*)[param[@"network"] UTF8String]);
                continue;
            }
            
            for (int i = 0; i < [self uIntFromNSString:param[@"repeat"]]; i++) {
                uint whichType = 1;
                if ([param[@"type"] isEqualToString:@"work"]) whichType = 0;
                if ([param[@"type"] isEqualToString:@"vram"]) whichType = 1;
                if ([param[@"type"] isEqualToString:@"z80"]) whichType = 2;
                if ([param[@"type"] isEqualToString:@"cart"]) whichType = 3;
                if ([param[@"type"] isEqualToString:@"all"]) whichType = 100;

                if ([param[@"edit"] isEqualToString:@"scramble" ]) {
                    ScrambleByteWithRange([self uIntFromNSString:param[@"start"]],
                                          [self uIntFromNSString:param[@"end"]],
                                          [self uIntFromNSString:param[@"min"]],
                                          [self uIntFromNSString:param[@"max"]],
                                          whichType,
                                          true);
                }

                if ([param[@"edit"] isEqualToString:@"add" ]) {
                    IncrementByteWithRange([self uIntFromNSString:param[@"start"]],
                                          [self uIntFromNSString:param[@"end"]],
                                          [self uIntFromNSString:param[@"min"]],
                                          [self uIntFromNSString:param[@"max"]],
                                          whichType,
                                           true);
                }
                if([param[@"edit"] isEqualToString:@"reverse"])
                {
                    [self ReverseLastEditInHistory:whichType];
                }
            }
        }
    }
}

-(void)RegisterInHistory_Addr:(uint)addr Was:(uint)was Became:(uint)became OnMem:(int)onMem
{
    NSDictionary *entry = @{@"address" : @(addr),
                            @"was" : @(was),
                            @"became" : @(became),
                            @"onMem" : @(onMem)};
    [self.editHistory addObject:entry];
}

-(void)ReverseLastEditInHistory:(int)onMem
{
    for (int i = (int)[self.editHistory count] - 1; i >= 0; i--) {
        NSDictionary *entry = self.editHistory[i];
        if ((uint)[entry[@"onMem"] intValue] == onMem || onMem == 100)
        {
            SetByteOnMem((uint)[entry[@"address"] intValue], (uint)[entry[@"was"] intValue], (uint)[entry[@"onMem"] intValue]);
            [self.editHistory removeObjectAtIndex:i];
            break;
        }
    }
}

-(uint)uIntFromNSString:(NSString*)string
{
    if ([string length] == 0) {
        return 0;
    }
    uint outVal;
    NSString *source = [[string componentsSeparatedByString:@"x"] lastObject];
    
    NSScanner* scanner = [NSScanner scannerWithString:source];
    [scanner scanHexInt:&outVal];
    
    return outVal;
}

@end
