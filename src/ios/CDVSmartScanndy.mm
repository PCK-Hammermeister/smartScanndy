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
/*#import <UniqueUID.c>*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
//#include <bsp/bsp.h>


// convert string of hex digits to array of bytes
static int hex2bin( unsigned char *dst, const char *src, int ndigits )
{
    if ( ndigits % 2 )	// cannot convert odd number of nibbles (half-bytes)
        return -1;
    
    const char * const hstr = "0123456789ABCDEF";
    char *p = NULL;
    int i = 0;
    
    while ( i < ndigits )
    {
        p = strchr( hstr, toupper( (unsigned char)src[ i ] ) );
        
        if ( NULL == p )
            return -1;	// invalid hex digit
        
        dst[ i / 2 ] = ( p - hstr ) << 4;
        ++i;
        p = strchr( hstr, toupper( (unsigned char)src[ i ] ) );
        
        if ( NULL == p )
            return -1;	// invalid hex digit
        
        dst[ i / 2 ] |= ( p - hstr );
        ++i;
    }
    
    return ( i / 2 );
}


// convert array of bytes to string of hex digits
static int bin2hex( char *dst, const unsigned char *src, int nbytes )
{
    int i = 0;
    
    for ( i = 0; i < nbytes; ++i )
    {
        if ( 2 != sprintf( dst + i * 2, "%02X", (unsigned int)src[ i ] ) )
            return -1;	// conversion error
    }
    
    return i * 2;
}


// convert array of bytes to string of decimal digits
static int bin2dec( char *dst, const unsigned char *src, int nbytes )
{
    unsigned long long val = 0;
    int i = 0;
    
    for ( i = 0; i < nbytes; ++i )
        val = val * 256 + src[ i ];
    
    dst[ 13 ] = '\0';
    
    for ( i = 12; i >= 0; --i )
    {
        dst[ i ] = val % 10 + '0';
        val /= 10;
    }
    
    return strlen( dst );
}


/*
 ** Convert hexadecimal ASCII coded 64 bit UID (16 characters stored in uid64s)
 ** to hexadecimal ASCII coded 40 bit UID (10 characters stored in uid40s).
 */
int Unique64to40( char *pUid40s, const char *pUid64s )
{
    if ( strlen( pUid64s ) != 16 )
        return -1;
    
    unsigned char uid64[ 8 ]; // buffer to store binary uid64
    
    if ( 8 != hex2bin( uid64, pUid64s, 16 ) )
        return -1;			// hex digit to binary conversion error
    
    unsigned char uid40[ 5 ]; // buffer to store binary uid40
    
    // do the bit (un)shuffeling to extract the "pure" 40 bit UID:
    uid40[ 0 ] = ( ( uid64[ 1 ] << 1 ) & 0xf0 ) |
    ( ( uid64[ 1 ] << 2 ) & 0x0c ) |
    ( ( uid64[ 2 ] >> 6 ) & 0x03 );
    
    uid40[ 1 ] = ( ( uid64[ 2 ] << 3 ) & 0xf0 ) |
    ( ( uid64[ 3 ] >> 4 ) & 0x0f );
    
    uid40[ 2 ] = ( ( uid64[ 3 ] << 5 ) & 0xe0 ) |
    ( ( uid64[ 4 ] >> 3 ) & 0x10 ) |
    ( ( uid64[ 4 ] >> 2 ) & 0x0f );
    
    uid40[ 3 ] = ( ( uid64[ 4 ] << 7 ) & 0x80 ) |
    ( ( uid64[ 5 ] >> 1 ) & 0x70 ) |
    (   uid64[ 5 ]        & 0x0f );
    
    uid40[ 4 ] = ( ( uid64[ 6 ] << 1 ) & 0xf0 ) |
    ( ( uid64[ 6 ] << 2 ) & 0x0c ) |
    ( ( uid64[ 7 ] >> 6 ) & 0x03 );
    
    if ( 10 != bin2hex( pUid40s, uid40, 5 ) )
        return -1;			// binary to hex digit conversion error
    
    return 0;
}


/*
 ** Convert hexadecimal ASCII coded 64 bit UID (16 characters stored in uid64s)
 ** to decimal ASCII coded 40 bit UID (13 characters stored in uid40s).
 */
int Unique64to13( char *pUid40s, const char *pUid64s )
{
    if ( strlen( pUid64s ) != 16 )
        return -1;
    
    unsigned char uid64[ 8 ]; // buffer to store binary uid64
    
    if ( 8 != hex2bin( uid64, pUid64s, 16 ) )
        return -1;			// hex digit to binary conversion error
    
    unsigned char uid40[ 5 ]; // buffer to store binary uid40
    
    // do the bit (un)shuffeling to extract the "pure" 40 bit UID:
    uid40[ 0 ] = ( ( uid64[ 1 ] << 1 ) & 0xf0 ) |
    ( ( uid64[ 1 ] << 2 ) & 0x0c ) |
    ( ( uid64[ 2 ] >> 6 ) & 0x03 );
    
    uid40[ 1 ] = ( ( uid64[ 2 ] << 3 ) & 0xf0 ) |
    ( ( uid64[ 3 ] >> 4 ) & 0x0f );
    
    uid40[ 2 ] = ( ( uid64[ 3 ] << 5 ) & 0xe0 ) |
    ( ( uid64[ 4 ] >> 3 ) & 0x10 ) |
    ( ( uid64[ 4 ] >> 2 ) & 0x0f );
    
    uid40[ 3 ] = ( ( uid64[ 4 ] << 7 ) & 0x80 ) |
    ( ( uid64[ 5 ] >> 1 ) & 0x70 ) |
    (   uid64[ 5 ]        & 0x0f );
    
    uid40[ 4 ] = ( ( uid64[ 6 ] << 1 ) & 0xf0 ) |
    ( ( uid64[ 6 ] << 2 ) & 0x0c ) |
    ( ( uid64[ 7 ] >> 6 ) & 0x03 );
    
    if ( 13 != bin2dec( pUid40s, uid40, 5 ) )
        return -1;			// binary to decimal digit conversion error
    
    return 0;
}

@class CDVscndyProcessor;

//------------------------------------------------------------------------------
// plugin class
//------------------------------------------------------------------------------
@interface CDVSmartScanndy : CDVPlugin {}
- (void)rfidscan:(CDVInvokedUrlCommand*)command;
@end

//------------------------------------------------------------------------------
// class that does the grunt work
//------------------------------------------------------------------------------
@interface CDVscndyProcessor : NSObject <ScanndyDelegate> {}
@property (nonatomic, retain) CDVSmartScanndy*            plugin;

- (id)initWithPlugin:(CDVSmartScanndy*)plugin;
- (NSString*)scanrfid:(NSString*)sccommand;
- (NSString*)conv64to40:(NSString*)value;
- (NSString*)conv64to13:(NSString*)value;
@end

//------------------------------------------------------------------------------
// plugin class
//------------------------------------------------------------------------------
@implementation CDVSmartScanndy

CDVscndyProcessor* processor;


- (void)pluginInitialize
{
    processor = [[CDVscndyProcessor alloc]
                 initWithPlugin:self
                 ];
}


//--------------------------------------------------------------------------
- (void)rfidscan:(CDVInvokedUrlCommand*)command {
    NSString*       callback;
    
    callback = command.callbackId;
    
    // We allow the user to define an alternate xib file for loading the overlay.
    NSString *sccommand = nil;
    if ( [command.arguments count] >= 1 )
    {
        sccommand = [command.arguments objectAtIndex:0];
    }
    
    UIAlertView *infoAlert = [[UIAlertView alloc] initWithTitle:@"INFO"
                                                         message:@"before rfidscan"
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
    [infoAlert show];
    [infoAlert release];
    
    NSString* responseraw = [processor scanrfid:sccommand];
    
    //NSString* responseraw = [self sendString:sccommand];
    NSString* response = [responseraw substringFromIndex:9];
    
    
    NSString* respconv40 = [processor conv64to40:response];
    //NSString* respconv13 = [[NSString alloc] initWithUTF8String:cresponse13];
    NSString* respconv13 = [processor conv64to13:response];
    
    NSMutableDictionary* resultDict = [[[NSMutableDictionary alloc] init] autorelease];
    [resultDict setObject:responseraw     forKey:@"resultraw"];
    [resultDict setObject:response     forKey:@"result"];
    [resultDict setObject:respconv40   forKey:@"result40"];
    [resultDict setObject:respconv13   forKey:@"result13"];
    
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"RESULT"
                                                         message:respconv40
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
    [errorAlert show];
    [errorAlert release];
    
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsDictionary: resultDict
                               ];
    
    NSString* js = [result toSuccessCallbackString:callback];
    [self writeJavascript:js];
}

@end

//------------------------------------------------------------------------------
// class that does the grunt work
//------------------------------------------------------------------------------
@implementation CDVscndyProcessor

@synthesize plugin               = _plugin;

Scanndy *myScanndy;
NSString *accessoryRequest;
bool scanndyConnected = false;

//--------------------------------------------------------------------------
- (id)initWithPlugin:(CDVSmartScanndy*)plugin {
    self = [super init];
    if (!self) return self;
    
    self.plugin               = plugin;
    
    myScanndy = [Scanndy alloc];
    myScanndy.delegate = self;
    [myScanndy init];
    
    return self;
}

//--------------------------------------------------------------------------
- (void)dealloc {
    self.plugin = nil;
    
    [super dealloc];
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
- (NSString*) scanrfid:(NSString*)sccommand {
    return [self sendString:sccommand];
}

- (NSString*) conv64to40:(NSString*)value {
    const char* cresponse = [value UTF8String];
    char* cresponse40 = (char*)calloc(40+1,1);
    
    Unique64to40(cresponse40, cresponse);
    
    return [[NSString alloc] initWithUTF8String:cresponse40];
    
}

- (NSString*) conv64to13:(NSString*)value {
    const char* cresponse = [value UTF8String];
    char* cresponse13 = (char*)calloc(13+1,1);
    
    Unique64to13(cresponse13, cresponse);
    
    return [[NSString alloc] initWithUTF8String:cresponse13];
}

@end


