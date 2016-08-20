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

- (void)initNetworkCommunication {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    NSDictionary *params = nil;//[self NetworkSettings];
//    if(!params)return;
    
    NSString *host = (params[@"ip"])? params[@"ip"] : @"192.168.0.2";//@"localhost";//
    NSString *port = (params[@"port"])? params[@"port"] : @"13000";
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Connecting to host: %@, on port: %@", host, port]];

    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, [port intValue], &readStream, &writeStream);
    
    if (readStream)
    {
        self.inputStream = (__bridge NSInputStream *)readStream;
        [self.inputStream setDelegate:self];
        [self.inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
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
        [self.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream open];
        WriteToLog("Write stream has succeeded");
    }
    else
    {
        WriteToLog("Write stream has failed");
    }
    
    WriteToLog("streams opened!");
}

-(void)SendMessage:(NSString*)message WithHeader:(NSString*)header
{
    NSString *response  = [NSString stringWithFormat:@"%@>%@>%@", header, message, [self timeStampAsNumber]];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [self.outputStream write:[data bytes] maxLength:[data length]];
    
    if (!self.outputStream) {
        [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"No output stream set up - did not send: %@", response]];
    }
    else
    {
        [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Sent network msg: %@", response]];
        [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"Input stream state: %@", self.inputStream]];
    }
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    [GenPlusGameCore WriteToLog:[NSString stringWithFormat:@"(%@) stream event %i", (theStream == self.inputStream)? @"input" : (theStream == self.outputStream) ? @"output" : @"?", (uint)streamEvent]];
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            WriteToLog("Stream opened");
            break;
            
        case NSStreamEventHasBytesAvailable:
            WriteToLog("NSStreamEventHasBytesAvailable");
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
            
        case NSStreamEventHasSpaceAvailable:
            WriteToLog("Has bytes available");
            break;
            
        case NSStreamEventErrorOccurred:
            WriteToLog("Can not connect to the host!");
            [self Refresh];
            break;
            
        case NSStreamEventEndEncountered:
            WriteToLog("Event ended");
            [self Refresh];
            break;
            
        default:
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
    [self.inputStream close];
    [self.outputStream close];
    
    self.inputStream = nil;
    self.outputStream = nil;
    
}

-(void)Refresh
{
    [self Close];
    [self initNetworkCommunication];
    
}

@end
