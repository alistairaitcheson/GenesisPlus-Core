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
        self.usageCounts = [NSMutableDictionary dictionary];
    
        NSString *currentpath = [GenPlusGameCore PathString];
        
        self.readPath = [currentpath stringByAppendingString:@"memorycommands.txt"];
        self.logPath = [currentpath stringByAppendingString:@"GenesisLog.txt"];
        

        [[NSFileManager defaultManager] createFileAtPath:[currentpath stringByAppendingString:@"here_it_is.txt"]
                                                contents:nil
                                              attributes:nil];
        
        self.parameters = [NSMutableArray array];
        
        [self performSelectorInBackground:@selector(RequestDefsFromBackground)
                               withObject:nil];
    }
    return self;
}

-(void)UpdateDefinitions
{
    if (!self.updatingDefs)
    {
        self.updatingDefs = YES;
        NSMutableArray *tempArray = [NSMutableArray array];

        NSString *source = [NSString stringWithContentsOfFile:self.readPath
                                                     encoding:NSASCIIStringEncoding
                                                        error:nil];
        
        for (NSString *component in [source componentsSeparatedByString:@"\n"]) {
            NSDictionary *dict = [self DictFromString:component];
            if (dict) [tempArray addObject:dict];
        }
        
//        WriteToLog("got parameters");
        self.parameters = tempArray;
        self.updatingDefs = NO;
    }

}

-(void)RequestDefsFromBackground
{
    [self performSelectorInBackground:@selector(UpdateDefinitions)
                           withObject:nil];
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
    if (!dict[@"probmin"]) dict[@"probmin"] = @"0";
    if (!dict[@"probmax"]) dict[@"probmax"] = @"100";
    if (!dict[@"randoff"]) dict[@"randoff"] = @"0";
    if (!dict[@"roffcount"]) dict[@"roffcount"] = @"0";

    dict[@"SOURCE"] = source;
    
    return dict;
}

-(void)ActivateOnCondition:(NSString*)sourceCondition
{
    NSString *condition = sourceCondition;
    NSArray *conditionVars = [condition componentsSeparatedByString:@","];
    NSString *extraVar = nil;
    uint extraVarAsNumber = 0;
    if ([conditionVars count] > 1)
    {
        condition = [conditionVars objectAtIndex:0];
        extraVar = [conditionVars objectAtIndex:1];
        NSScanner *scanner = [NSScanner scannerWithString:extraVar];
        uint result;
        [scanner scanHexInt:&result];
        extraVarAsNumber = result;
//        [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Interpreted: %@ --> %i", extraVar, extraVarAsNumber]];
    }
    
    for (NSDictionary *param in self.parameters) {
        BOOL canPerform = [param[@"trigger"] isEqualToString:condition];
        if ([condition hasPrefix:@"timer_"] && [param[@"trigger"] hasPrefix:@"timer_"])
        {
            NSString *timeStr = [condition substringFromIndex:6];
            uint inputTime = (uint)[timeStr intValue];

            NSString *myTimeStr = [param[@"trigger"] substringFromIndex:6];
            uint period = (uint)[myTimeStr intValue];
            
            
            if (inputTime % period == 0)
            {
//                WriteToLog("can perform");
                canPerform = YES;
                
                if (param[@"lastTime"])
                {
                    if (inputTime > [self uIntFromNSString:param[@"lastTime"]])
                    {
                        canPerform = NO;
                    }
                }
            }
        }
        
        if (canPerform) {
            uint probaValue = rand() % 100;
            
            //for splitting things probabilistically
            if(probaValue < (uint)[param[@"probmin"] intValue] ||
               probaValue >= (uint)[param[@"probmax"] intValue])
            {
                continue;
            }
            
            if (param[@"network"])
            {
                SendNetworkEvent((char*)[param[@"network"] UTF8String]);
                continue;
            }
            
            if ([param[@"action"] isEqualToString:@"rewind"])
            {
                LoadFromBackup();
                continue;
            }
            
            if (param[@"report"])
            {
                NSArray *underscoreComponents = [condition componentsSeparatedByString:@"_"];
                if ([underscoreComponents count] > 1)
                {
                    NSString *locString = [underscoreComponents objectAtIndex:1];
                    uint location = [self uIntFromNSString:locString];
                    ReportByteAtLocation(location, (char*)[param[@"report"] UTF8String]);
                }
                continue;
            }
            
            if (param[@"name"] && param[@"only"])
            {
                NSString *idString = param[@"name"];
                uint usesSoFar = [self uIntFromNSString:self.usageCounts[idString]];
                if (usesSoFar > [self uIntFromNSString:param[@"only"]] )
                {
                    continue;
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.usageCounts setValue:[NSNumber numberWithInt:(int)usesSoFar + 1]
                                            forKey:idString];
                    });
                }
            }
            
            for (int i = 0; i < [self uIntFromNSString:param[@"repeat"]]; i++) {
                uint whichType = 1;
                if ([param[@"type"] isEqualToString:@"work"]) whichType = 0;
                if ([param[@"type"] isEqualToString:@"vram"]) whichType = 1;
                if ([param[@"type"] isEqualToString:@"z80"]) whichType = 2;
                if ([param[@"type"] isEqualToString:@"cart"]) whichType = 3;
                if ([param[@"type"] isEqualToString:@"all"]) whichType = 100;
                
                uint indexStart = [self uIntFromNSString:param[@"start"]];
                uint indexEnd = [self uIntFromNSString:param[@"end"]];
                uint offset = [self uIntFromNSString:param[@"randoff"]] * (rand() % ([self uIntFromNSString:param[@"roffcount"]] + 1));
                indexStart += offset;
                indexEnd += offset;
                
                uint minVal = [self uIntFromNSString:param[@"min"]];
                uint maxVal = [self uIntFromNSString:param[@"max"]];
                
                if (extraVar)
                {
                    minVal = extraVarAsNumber;
                    maxVal = extraVarAsNumber;
                    [GenPlusGameCore WriteToLog:@"APPLIED SPECIAL MIN/MAX"];
                }
                
                bool hide = false;
                if (param[@"hide"]) hide = true;
                
                bool flagOnNetwork = (param[@"flag"] != nil);

                if ([param[@"edit"] isEqualToString:@"scramble" ]) {
                    ScrambleByteWithRange(indexStart,
                                          indexEnd,
                                          minVal,
                                          maxVal,
                                          whichType,
                                          true,
                                          hide,
                                          flagOnNetwork,
                                          (char*)[param[@"flag"] UTF8String]);
                }

                bool isSubtract = [param[@"edit"] isEqualToString:@"subtract" ];
                
                if ([param[@"edit"] isEqualToString:@"add" ] || [param[@"edit"] isEqualToString:@"subtract" ]) {
                    bool useBounds = (param[@"lowBound"] || param[@"highBound"]);
                    uint lowBound = 0x00;
                    if (param[@"lowBound"]) lowBound = [self uIntFromNSString:param[@"lowBound"]];
                    uint highBound = 0xFF;
                    if (param[@"highBound"]) highBound = [self uIntFromNSString:param[@"highBound"]];

                    IncrementByteWithRange(indexStart,
                                          indexEnd,
                                          minVal,
                                          maxVal,
                                          whichType,
                                           true,
                                           useBounds,
                                           lowBound,
                                           highBound,
                                           isSubtract,
                                           hide);
                }
                if([param[@"edit"] isEqualToString:@"reverse"])
                {
                    [self ReverseLastEditInHistory:whichType];
                }
                
                
                if ([param[@"edit"] isEqualToString:@"track"])
                {
                    NSString *location = [param[@"trigger"] substringFromIndex:[@"byte_" length]];
                    uint valueAtLocation = ValueAtLocation([self uIntFromNSString:location],
                                                           whichType);
                    NSString *outputStr = [NSString stringWithFormat:@"track %@ = %04X %@",
                                           location,
                                           valueAtLocation,
                                           param[@"suffix"]];
                    [GenPlusGameCore WriteToLog:outputStr];
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

+(uint)uIntFromNSString:(NSString*)string
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
