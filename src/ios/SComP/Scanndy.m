//
//  Scanndy.m
//  SComP_Demo
//
//  Created by Andreas Wallstabe on 14.06.12.
//  Copyright (c) 2012 Panmobil. All rights reserved.
//

#import "Scanndy.h"
#import "scomp.h"

//in ms
#define SCOMP_EXCH_TIMOUT 1000
#define SCOMP_REC_TIMOUT 1000
#define SCOMP_ARRAY_SIZE 16000

@implementation Scanndy
@synthesize delegate;


- (id)init
{
    if (self = [super init])
    {
        // Initialization code here
        [self initSComP];
        [self initSessionController];
        [self checkConnectedAccessory];
        [self registerCallbacks];
    }
    return self;
}

- (void) initSComP
{
    ScompOpt_t opt;
    opt.i = 1;
    ScompSetOption( SCOMP_OPT_USE_CRC, opt );
    opt.cb = sndcb;
    ScompSetOption( SCOMP_OPT_SNDCB, opt );
    opt.cb = rcvcb;
    ScompSetOption( SCOMP_OPT_RCVCB, opt );
}

- (void) checkConnectedAccessory
{
    _isConnected = FALSE;
    
    _accessoryList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];
    
    if ([_accessoryList count] != 0)
    {
        [self _accessoryDidConnect:NULL];
    }
}

- (void) registerCallbacks
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidConnect:) name   :EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessorySendData:) name:EADSessionDataReceivedNotification object:nil];
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
}

- (void) initSessionController
{
    _eaSessionController = [EADSessionController sharedController];
    //_accessory = [[_eaSessionController accessory] retain];
    _accessory = [_eaSessionController accessory];
}

static int sndcb( void *array, int size, int to )
{
    //    if (_isConnected)
    //        return 0;
    
    NSData* data = [NSData dataWithBytes:(const void *)array length:sizeof(char)*size];
    
    //for debug
    //NSString *strData = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    //NSLog(@"snd: %@",strData);
    
    [[EADSessionController sharedController] writeData:data withTimeout:to];
    
    return size;
}

static int rcvcb( void *array, int size, int to )
{
    //    if (!_isConnected)
    //        return 0;
    
    NSMutableData *data = [[NSMutableData alloc] init];
    int bytesRead = 0;
    
    EADSessionController *sessionController = [EADSessionController sharedController];
    
    NSData *dataAvailable = [sessionController readData:size withTimeout:to];
    
    //for debug
    NSString *strData = [[NSString alloc]initWithData:dataAvailable encoding:NSUTF8StringEncoding];
    NSLog(@"rec: %@",strData);
    
    if (dataAvailable)
    {
        [data appendData:dataAvailable];
        bytesRead = [data length];
        memcpy(array, [data bytes], bytesRead);
    }
    
    //just for debug
    //NSString* aStr = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    return bytesRead;
}

- (NSData*) sendData:(NSData *)data
{
    return [self sendData:data withTimout:(SCOMP_EXCH_TIMOUT)];
}

- (NSData*) sendData:(NSData *)data withTimout:(NSInteger)timeout
{
    NSUInteger size = [data length] / sizeof(char);
    char* array = (char*) [data bytes];
    
    int sizeResp = SCOMP_ARRAY_SIZE;
    char arrayResp[sizeResp];
    
    int result = ScompExch( array, size, arrayResp, &sizeResp, timeout + SCOMP_EXCH_TIMOUT);
    if (0 != result)
    {
        sizeResp = 0;
        NSLog(@"SCOMP_ERR: %d", result);
    }
    
    return [NSData dataWithBytes:(const void *)arrayResp length:sizeof(char)*sizeResp];
}

- (NSInteger) sendData_ignoreResponse:(NSData *)data
{
    int sseq = -1;
    NSUInteger size = [data length] / sizeof(char);
    char* array = (char*) [data bytes];
    
    return ScompSend( array, size, &sseq, SCOMP_REQUEST );
}


-(void) selector_scanndyRequestAsyncCallback
{
    [self.delegate scanndyRequestAsyncCallback];
}

- (void) receiveData
{
    NSData* data = nil;
    int size = SCOMP_ARRAY_SIZE;
    char array[size];
    int slen;
    int seq;
    int type;
    int res = 0;
    
    res = ScompRecv(array, &size, &seq, &type, SCOMP_REC_TIMOUT);
    
    switch ( res )
    {
        case SCOMP_ERR_OK:
            if ( SCOMP_REQUEST == type )
            {
                //start sync callback
                data = [self.delegate scanndyRequestSyncCallback:[NSData dataWithBytes:(const void *)array length:sizeof(char)*size]];
                
                slen = [data length];
                memcpy(array, [data bytes], slen);
                
                ScompSendResponse( array, slen, seq );
                
                //put async callback in thread's queue and return immediately
                [self performSelectorOnMainThread:@selector(selector_scanndyRequestAsyncCallback) withObject:nil waitUntilDone:NO];
                
                //[self.delegate scanndyRequestAsyncCallback];
            }
            else
            {
                ; // drop unsolicited non-requests
            }
            break;
        case SCOMP_ERR_TIMEOUT:
            // silent timeout
            break;
        case SCOMP_ERR_CRC:
            ScompSendResponse( "error:crc", 9, seq );
            //fall through intended
        default:
            //unknown ScompRecv return value
            NSLog(@"nRcvErr: %s", ScompStrErr( res ));
            break;
    }
}

- (void)_accessorySendData:(NSNotification *)notification
{
    [self receiveData];
}

- (void)_accessoryDidConnect:(NSNotification *)notification
{
    if (_isConnected)
        return;
    
    EAAccessory *connectedAccessory = NULL;
    
    if (notification != NULL)
    {
        //The hard way to kill the ghost accessories.... (because we are sure using only a single accessory)
        //http://stackoverflow.com/questions/4394291/easession-eaaccessorydelegate-and-error-opening-session-failed
        [_accessoryList removeAllObjects];
        
        connectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
        [_accessoryList addObject:connectedAccessory];
    }
    
    //NSLog(@"new connected device: %@ %i", [connectedAccessory name], [connectedAccessory connectionID]);
    
    for (id checkedAccessory in _accessoryList)
    {
        //NSLog(@"checkedAccessory: %@ count:%i", [checkedAccessory name], [_accessoryList count]);
        
        //check for scanndy
        if ([[checkedAccessory name] isEqualToString:@"Scanndy"])
            //if ([[connectedAccessory name] isEqualToString:@"Scanndy"])
        {
            //NSLog(@"Scanndy found!");
            //_selectedAccessory = [checkedAccessory retain];
            _selectedAccessory = checkedAccessory;
            
            
            //check for valid protocol
            _selectedProtokol = @"";
            NSArray *protocolStrings = [_selectedAccessory protocolStrings];
            for(NSString *protocolString in protocolStrings)
            {
                if ([protocolString isEqualToString:@"com.panmobil.protocol1"])
                {
                    //NSLog(@"Scanndy connnected, valid protocol found!");
                    _selectedProtokol = [_selectedProtokol stringByAppendingString:protocolString];
                    
                    _eaSessionController = [EADSessionController sharedController];
                    [_eaSessionController setupControllerForAccessory:_selectedAccessory                                                 withProtocolString:_selectedProtokol];
                    [_eaSessionController openSession];
                    
                    _isConnected = TRUE;
                    [self.delegate scanndyConnectedCallback];
                }
            }
            if ([_selectedProtokol isEqualToString:@""] )
            {
                //this is normal during the connection process, because the scanndy is reconnected, after the exchange of supported protocols by general lingo
                //NSLog(@"Scanndy does not support a valid protocol!");
            }
        }
    }
}

- (void)_accessoryDidDisconnect:(NSNotification *)notification
{
    
    EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    
    //NSLog(@"disconnected device: %@ %i", [disconnectedAccessory name], [disconnectedAccessory connectionID]);
    
    if (_selectedAccessory && [disconnectedAccessory connectionID] == [_selectedAccessory connectionID])
    {
        //NSLog(@"Scanndy disconnected!");
        _isConnected = FALSE;
        [self.delegate scanndyDisconnectedCallback];
    }
    
    NSInteger disconnectedAccessoryIndex = 0;
    
    //get index of diconnected accessory
    for(EAAccessory *accessory in _accessoryList)
    {
        if ([disconnectedAccessory connectionID] == [accessory connectionID])
        {
            break;
        }
        disconnectedAccessoryIndex++;
    }
    
    //debug stuff:
    
    /*
     NSLog(@"count: %i", [_accessoryList count]);
     NSLog (@"id: %i",[disconnectedAccessory connectionID]);
     if ([[disconnectedAccessory protocolStrings] count])
     NSLog (@"prot: %@", (NSString*) [[disconnectedAccessory protocolStrings] objectAtIndex:0]);
     */
    
    if (disconnectedAccessoryIndex < [_accessoryList count])
    {
        [_accessoryList removeObjectAtIndex:disconnectedAccessoryIndex];
        [_eaSessionController closeSession];
    }
    else
    {
        NSLog(@"could not find disconnected accessory in accessory list");
    }
}

- (void) dealloc
{
    // remove the observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EADSessionDataReceivedNotification object:nil];
    [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
    
    [_eaSessionController closeSession];
    
    [_accessory release];
    _accessory = nil;
    [_accessoryList release];
    _accessoryList = nil;
    [_selectedAccessory release];
    _selectedAccessory = nil;
    [_selectedProtokol release];
    _selectedProtokol = nil;
    
    [super dealloc];
}


@end
