//
//  FlatFielderControlController.h
//  FlatFielderControl
//
//  Created by roro on 19/3/16.
//  Copyright  2016 RTI-Zone. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ORSSerialPort.h"
#import "Queue.h"
#import "Flatman_Command.h"

@class ORSSerialPortManager;

#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_7)
@protocol NSUserNotificationCenterDelegate <NSObject>
@end
#endif

@interface FlatFielderControlController :  NSWindowController  <ORSSerialPortDelegate, NSUserNotificationCenterDelegate, NSWindowDelegate>

#pragma mark - Control Outlets
@property (unsafe_unretained) IBOutlet NSPopUpButton *SerialDropdown;
@property (unsafe_unretained) IBOutlet NSButton *ConnectButton;
@property (unsafe_unretained) IBOutlet NSButton *HaltButton;
@property (unsafe_unretained) IBOutlet NSButton *CloseButton;
@property (unsafe_unretained) IBOutlet NSButton *TurnOnButton;
@property (unsafe_unretained) IBOutlet NSWindow *flatFielderControllWindow;
@property (unsafe_unretained) IBOutlet NSSliderCell *Brightness;

#pragma mark - internal variables
@property (nonatomic, readwrite) UInt16 fm_mode;
@property (nonatomic, readwrite) UInt16 deviceType;
@property (nonatomic, readwrite) UInt16 coverState;
@property (nonatomic, readwrite) UInt16 lightState;
@property (nonatomic, readwrite) UInt16 motorState;
@property (nonatomic, readwrite) Queue *commandQueue;
@property (nonatomic, readwrite) Queue *responseQueue;
@property (nonatomic, strong) ORSSerialPortManager *serialPortManager;
@property (nonatomic, strong) ORSSerialPort *serialPort;
@property (nonatomic, strong) NSArray *availableBaudRates;
@property (nonatomic, strong) NSTimer *timeoutTimer;
@property (nonatomic, strong) NSTimer *connectionTimer;
@property (nonatomic, readwrite) NSInteger versionMajor;
@property (nonatomic, readwrite) NSInteger versionMinor;
@property (nonatomic, readwrite) NSInteger versionBugFix;
@property (nonatomic, readwrite) UInt16 currentBrightness;
@property (unsafe_unretained) IBOutlet NSTextField *Device;
@property (unsafe_unretained) IBOutlet NSTextField *FirmwareVersion;
@property (unsafe_unretained) IBOutlet NSTextField *currentMotorState;
@property (unsafe_unretained) IBOutlet NSTextField *currentCoverState;
@property (unsafe_unretained) IBOutlet NSTextField *statusField;
@property (unsafe_unretained) IBOutlet NSProgressIndicator *statusProgress;
@property (nonatomic, readwrite) NSString *currentBuffer;
@property (nonatomic, readwrite) bool firstConnect;
@property (nonatomic, readwrite) bool shouldDisconnect;
@property (nonatomic, readwrite) bool lightIsOn;
@property (nonatomic, readwrite) bool flipFlatIsOpen;
@property (strong) id activity;

#pragma mark - Methods
- (NSString *)stringToHex:(NSString *)string;
- (NSString *)dataToHex:(NSData *)data;
- (void) awakeFromNib;
- (void) windowWillClose:(NSNotification *)notification;
- (void) setControlOff;
- (void) updateDeviceType:(UInt16)devType;

- (IBAction) connectToFlatman:(id)sender;
- (IBAction) updateBrightness:(id)sender;
- (IBAction) turnLigthOn:(id)sender;
- (IBAction) openFlipFlat:(id)sender;
- (IBAction) haltFlipFlat:(id)sender;

- (BOOL) isANumber: (NSString *)string;
- (void) updateConnectButtonLabel;
- (void) startTimeoutTimer: (float) timeout;
- (void) startConnectionTimer: (NSString*)message waitTime:(float) waitTimeValue;
- (void) stopTimeoutTimer;
- (void) sendConnectPing: (NSTimer *)timer;
- (void) timerOk: (NSString*)message;
- (void) startCommandiTmer:(NSString*)message timeout:(float)timeoutValue;
- (void) enableDisableControls: (BOOL)Enabled;
- (void) updateDeviceControls:(NSString *)response;

- (void) timeOut: (NSTimer *)timer;

- (void) processFlatmanCommandResponse:(NSString *)response;
- (void) processFlatmanResponsePing:(NSString *)response;
- (void) processFlatmanResponseOpen:(NSString *)response;
- (void) processFlatmanResponseClose:(NSString *)response;
- (void) processFlatmanResponseLightOn:(NSString *)response;
- (void) processFlatmanResponseLightOff:(NSString *)response;
- (void) processFlatmanResponseSetBrightness:(NSString *)response;
- (void) processFlatmanResponseGetBrightness:(NSString *)response;
- (void) processFlatmanResponseGetState:(NSString *)response;
- (void) processFlatmanResponseGetVersion:(NSString *)response;
- (void) processFlatmanResponseMotorHalt:(NSString *)response;

@end
