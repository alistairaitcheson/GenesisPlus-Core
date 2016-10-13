//
//  NetworkManager.m
//  GenesisPlus
//
//  Created by Alistair Aitcheson on 05/08/2016.
//  Copyright 2016 __MyCompanyName__. All rights reserved.
//

#import "NetworkManager.h"
#import "GenPlusGameCore.h"

@implementation NetworkManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        WriteToLog("init NetworkManager");
        self.cachedMessages = [NSMutableArray array];
        self.writeCache = [NSMutableArray array];
        self.writeCacheReady = NO;
        
        [self initNetworkCommunication];
        
        self.startTime = [self timeStampAsNumber];
        
    }
    return self;
}

-(NSDictionary*)NetworkSettings
{
    NSString *currentpath = [GenPlusGameCore PathString];
    
    NSString *path = [currentpath stringByAppendingString:@"networksettings.txt"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    
    NSString *settingsSource = [NSString stringWithContentsOfFile:path
                                                         encoding:NSASCIIStringEncoding
                                                            error:nil];
    
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    
    for (NSString *strValue in [settingsSource componentsSeparatedByString:@"\n"]) {
        NSArray *components = [strValue componentsSeparatedByString:@":"];
        if ([components count] > 1)
        {
            parameters[components[0]] = components[1];
        }
    }
        
    return parameters;
}

-(void)threadLoop{
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];

    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    NSDictionary *params = [self NetworkSettings];
    if(!params)return;
    
    NSString *host = (params[@"ip"])? params[@"ip"] : @"192.168.0.2";////@"192.168.0.2";//@"localhost";//
    NSString *port = (params[@"port"])? params[@"port"] : @"13000";
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Connecting to host: %@, on port: %@", host, port]];
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, [port intValue], &readStream, &writeStream);
    
    if (readStream)
    {
        self.inputStream = (__bridge NSInputStream *)readStream;
        [self.inputStream setDelegate:self];
        [self.inputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        [self.inputStream open];
        WriteToLog("Read stream has succeeded");
    }
    else
    {
        WriteToLog("Read stream has failed");
    }
    
    if (readStream)
    {
        self.outputStream = (__bridge NSOutputStream *)writeStream;
        [self.outputStream setDelegate:self];
        [self.outputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        [self.outputStream open];
        WriteToLog("Write stream has succeeded");
    }
    else
    {
        WriteToLog("Write stream has failed");
    }
    
    WriteToLog("streams opened! -_-_-_-_");
    
    [runLoop runUntilDate:[NSDate distantFuture]];
//    WriteToLog([[NSString stringWithFormat:@"Beginning loop - run loop status: %@", [runLoop currentMode]] UTF8String]);
    
    WriteToLog("run loop ended");

//    while (true) {
//        if (self.writeCacheReady)
//        {
//            WriteToLog("Write cache ready!!!!!!!!!!!!!!!");
//            [self WriteFromCache];
//        }
//        else
//        {
//            WriteToLog("........");
////            WriteToLog([[NSString stringWithFormat:@"Run loop status: %@", [runLoop currentMode]] UTF8String]);
//        }
//    }
    
}

- (void)initNetworkCommunication {
    self.thread = [[NSThread alloc] initWithTarget:self
                                          selector:@selector(threadLoop)
                                            object:nil];
    [self.thread start];

}

-(void)SendMessage:(NSString*)message WithHeader:(NSString*)header
{
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Caching message to write: %@>%@", header, message]];
    NSString *response  = [NSString stringWithFormat:@"%@>%@>%@\n", header, message, [self timeStampAsNumber]];
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"   response: %@", response]];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"   data length: %i", (int)[data length]]];
    
    [[self writeCache] addObject:data];
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Cache size: %i", (int)[self.writeCache count]]];
    
    if (self.writeCacheReady)
    {
        [self WriteFromCache];
    }
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"(%@) stream event %i", (theStream == self.inputStream)? @"input" : (theStream == self.outputStream) ? @"output" : @"?", (uint)streamEvent]];
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Stream opened %@", theStream]];
            break;
            
        case NSStreamEventHasBytesAvailable: // CAN READ
            [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"NSStreamEventHasBytesAvailable %@", theStream]];
            if (theStream == self.inputStream)
            {
                uint8_t buffer[1024];
                int len;
                
                while ([self.inputStream hasBytesAvailable]) {
                    len = (int)[self.inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        
                        NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        
                        if (nil != output) {
                            NSString *logMsg = [NSString stringWithFormat:@"received from server: %@  -->  cache size: %i", output, (int)[self.cachedMessages count]];
                            [GenPlusGameCore WriteToLog:logMsg];
                            [self.cachedMessages addObject:output];
                        }
                    }
                }
            }
            break;
            
        case NSStreamEventHasSpaceAvailable: // CAN WRITE
            [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"NSStreamEventHasSPACEAvailable %@", theStream]];
            if (theStream == self.outputStream)
            {
                WriteToLog("FLAGGED: CAN WRITE");
                [self WriteFromCache];
            }
            break;
            
        case NSStreamEventErrorOccurred:
            [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"NSStreamEventErrorOccurred %@", theStream]];
            WriteToLog("Can not connect to the host!");
            [self Close];
            theStream = nil;
            break;
            
        case NSStreamEventEndEncountered:
            [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"NSStreamEventEndEncountered %@", theStream]];
            WriteToLog("Event ended");
            [self Close];
            theStream = nil;
            break;
            
        default:
            [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Event %i, %@", (int)streamEvent, theStream]];
            WriteToLog("Unknown event");
    }
}

-(NSArray*)GetCachedMessages
{
    return self.cachedMessages;
}

-(void)ClearCachedMessages
{
    [self.cachedMessages removeAllObjects];
}

-(NSString*)timeStampAsNumber
{
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMHHmmss"];
    NSString *timeString = [formatter stringFromDate:date];
    return timeString;
}

-(void)Close
{
    [GenPlusGameCore WriteToLog:@"Closing network streams"];
    
    [self.inputStream close];
    [self.outputStream close];
    
    [self.inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream setDelegate:nil];
    
    [self.outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream setDelegate:nil];
    
    self.inputStream = nil;
    self.outputStream = nil;
    
    [GenPlusGameCore WriteToLog:@"Closed network streams"];
    
}

-(void)Refresh
{
    [self Close];
    
    [self initNetworkCommunication];
    
}

-(void)WriteFromCache
{
    self.writeCacheReady = NO;
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Writing from cache (%i messages)", (int)[self.writeCache count]]];
    if ([self.writeCache count] > 0)
    {
        NSData *data = self.writeCache[0];
        [self.outputStream write:[data bytes] maxLength:[data length]];
        [self.writeCache removeObjectAtIndex:0];
    }
    else
    {
        self.writeCacheReady = YES;
    }
}

@end
