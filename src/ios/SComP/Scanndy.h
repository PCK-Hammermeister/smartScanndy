//
//  Scanndy.h
//  SComP_Demo
//
//  Created by Andreas Wallstabe on 14.06.12.
//  Copyright (c) 2012 Panmobil. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>
#import "QuartzCore/QuartzCore.h"
#import "EADSessionController.h"

@protocol ScanndyDelegate <NSObject>
- (void) scanndyConnectedCallback;
- (void) scanndyDisconnectedCallback;
- (NSData*) scanndyRequestSyncCallback:(NSData*)request;
- (void) scanndyRequestAsyncCallback;
@end

@interface Scanndy : NSObject {
    
    EAAccessory *_accessory;
    NSMutableArray *_accessoryList;
    EAAccessory *_selectedAccessory;
    EADSessionController *_eaSessionController;
    NSString *_selectedProtokol;
    NSInteger _isConnected;
}

@property (assign) id <ScanndyDelegate> delegate;

- (void) registerCallbacks;
- (void) initSComP;
- (void) checkConnectedAccessory;
- (void) initSessionController;
- (void)_accessoryDidConnect:(NSNotification *)notification;
- (void)_accessoryDidDisconnect:(NSNotification *)notification;

//- (NSInteger) sendData_ignoreResponse:(NSData*)data;

//this is the only method you should call on the class scanndy
- (NSData*) sendData:(NSData *)data withTimout:(NSInteger)timeout;
@end



