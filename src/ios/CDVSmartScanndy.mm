/*
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 *
 * Copyright 2011 Matt Kane. All rights reserved.
 * Copyright (c) 2011, IBM Corporation
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import <Cordova/CDVPlugin.h>
#import "Scanndy.h"
#import "UniqueUID.c"

//------------------------------------------------------------------------------
// plugin class
//------------------------------------------------------------------------------
@interface CDVSmartScanndy : CDVPlugin <ScanndyDelegate> {}

Scanndy *myScanndy;
NSString *accessoryRequest;
NSString *connectCallback;
NSString *disconnectCallback;
NSString *successCallback;
NSString *errorCallback;
bool scanndyConnected = false;

- (void)rfidscan:(CDVInvokedUrlCommand*)command;
@end

//------------------------------------------------------------------------------
// plugin class
//------------------------------------------------------------------------------
@implementation CDVSmartScanndy


- (void)pluginInitialize
{
    myScanndy = [Scanndy alloc];
    myScanndy.delegate = self;
    [myScanndy init];
}

//--------------------------------------------------------------------------
//these three calbacks are mandatory for proper communication:
- (void) scanndyConnectedCallback
{
    scanndyConnected = true;
}

- (void) scanndyDisconnectedCallback
{
    scanndyConnected = false;
    
}

//request from scanndy has to be handled here... (this is sync, this is handeled while accessory is still witing for an answer to its request)
- (NSData*) scanndyRequestSyncCallback:(NSData*)request
{
    accessoryRequest = [[NSString alloc] initWithData:request encoding:NSASCIIStringEncoding];
    
//    [self addToTextView:accessoryRequest];
    
    //send the answer according to the request
    NSData* response = [@"ok" dataUsingEncoding:NSUTF8StringEncoding];
    return response;
}


//request from scanndy has to be handled here... (this is async, this is handeled while accessory already received an answer to its request)
- (void) scanndyRequestAsyncCallback
{
    //scan barcode, if trigger key was sent from accessory
//    if ([accessoryRequest isEqualToString:@"keydata:T"])
//    {
//        [self scanBarcode];
//    }
    return;
}


//simple send function
- (NSData*) sendData:(NSData*)dataToSend withTimout:(NSInteger)timeout
{
    //this is the only necessary method you should call on the class scanndy
    return [myScanndy sendData:dataToSend withTimout:timeout];
}

- (NSString*) sendString:(NSString*)stringToSend withTimeout:(NSInteger)timeout
{
    //convert string to data object
    NSData* dataToSend=[stringToSend dataUsingEncoding:NSUTF8StringEncoding];
    //send data
    NSData* response = [self sendData:dataToSend withTimout:timeout];
    //convert data back to string
    return [[NSString alloc] initWithData:response encoding:NSASCIIStringEncoding];
}

- (NSString*) sendString:(NSString*)stringToSend
{
    return [self sendString:stringToSend withTimeout:1000];
}

//--------------------------------------------------------------------------
- (void)rfidscan:(CDVInvokedUrlCommand*)command {
    CDVbcsProcessor* processor;
    NSString*       callback;
    
    callback = command.callbackId;
    
    // We allow the user to define an alternate xib file for loading the overlay. 
    NSString *sccommand = nil;
    if ( [command.arguments count] >= 1 )
    {
        sccommand = [command.arguments objectAtIndex:0];
    }
    
    NSString* response = [self sendString:sccommand];
    NSString* respconv40 = "";
    NSString* respconv13 = "";
    
    int i = [Unique64to40 pUid40s:respconv40 pUId64s:response];
    int j = [Unique64to13 pUid40s:respconv13 pUId64s:response];
    
    NSMutableDictionary* resultDict = [[[NSMutableDictionary alloc] init] autorelease];
    [resultDict setObject:response     forKey:@"result"];
    [resultDict setObject:respconv40   forKey:@"result40"];
    [resultDict setObject:respconv13   forKey:@"result13"];
    
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsDictionary: resultDict
                               ];
    
    NSString* js = [result toSuccessCallbackString:callback];
    [self writeJavascript:js];
}

@end