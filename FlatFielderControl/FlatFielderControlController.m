//
//  FlatFielderControlController.m
//  FlatFielderControl
//
//  Created by roro on 19/3/16.
//  Copyright  2016 RTI-Zone. All rights reserved.
//

#import "FlatFielderControlController.h"
#import "ORSSerialPortManager.h"
#include "Flatman_Command.h"

@implementation FlatFielderControlController

- (id) init
{
    self = [super init];
    if (self)
    {
        [self GetSystemVersion ];

        // code to run on app close.
        void (^terminationBlock)(void) = ^{
            if (self.commandQueue)
                self.commandQueue = nil;
            if (self.responseQueue)
                self.responseQueue = nil;
            if(self.fm_mode != NONE) {
                self.fm_mode = NONE;
                [self.serialPort sendData:[fm_light_off dataUsingEncoding: [NSString defaultCStringEncoding] ]];
                sleep(1);
                [self.serialPort close];
            }
            [self.serialPort close];

        };


        // register for notifications
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        [nc addObserverForName:NSApplicationWillTerminateNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *notification){
                        terminationBlock();
                    }];

        self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
        self.availableBaudRates = [NSArray arrayWithObjects: [NSNumber numberWithInteger:300], [NSNumber numberWithInteger:1200], [NSNumber numberWithInteger:2400], [NSNumber numberWithInteger:4800], [NSNumber numberWithInteger:9600], [NSNumber numberWithInteger:14400], [NSNumber numberWithInteger:19200], [NSNumber numberWithInteger:28800], [NSNumber numberWithInteger:38400], [NSNumber numberWithInteger:57600], [NSNumber numberWithInteger:115200], [NSNumber numberWithInteger:230400],
                                   nil];

        [nc addObserver:self selector:@selector(serialPortsWereConnected:) name:ORSSerialPortsWereConnectedNotification object:nil];
        [nc addObserver:self selector:@selector(serialPortsWereDisconnected:) name:ORSSerialPortsWereDisconnectedNotification object:nil];
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
#endif
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *)stringToHex:(NSString *)string
{
    const char *utf8 = [string UTF8String];
    NSMutableString *hex = [NSMutableString string];
    while ( *utf8 ) [hex appendFormat:@"%02X" , *utf8++ & 0x00FF];

    return [NSString stringWithFormat:@"%@", hex];
}

- (NSString *)dataToHex:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    const char *utf8 = [string UTF8String];
    NSMutableString *hex = [NSMutableString string];
    while ( *utf8 ) [hex appendFormat:@"%02X" , *utf8++ & 0x00FF];

    return [NSString stringWithFormat:@"%@", hex];
}

- (void) awakeFromNib
{
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:reason:)]) {
        self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions:0x00FFFFFF reason:@"receiving OSC messages"];
    }

    // set some defaults
    self.commandQueue = [[Queue alloc] init];
    self.responseQueue = [[Queue alloc] init];
    [self.Brightness setContinuous:YES];
    [self.Brightness setIntegerValue:0];
    self.firstConnect = true;
    self.shouldDisconnect = false;
    self.currentBrightness = 0;
    self.lightIsOn = false;
    self.flipFlatIsOpen = false;
    [self setControlOff];
    [self.SerialDropdown removeItemWithTitle:@"No Value"];
    [self.SerialDropdown selectItemAtIndex:0];
    if([self.serialPortManager.availablePorts count]) {
        self.serialPort = [self.serialPortManager.availablePorts objectAtIndex:0];
    }
}

- (void) windowWillClose:(NSNotification *)notification
{
    if ([notification object] == [self flatFielderControllWindow]) {
#ifdef DEBUG
        NSLog(@"Cleanup before closing the main window");
#endif
        if (self.commandQueue)
            self.commandQueue = nil;
        if (self.responseQueue)
            self.responseQueue = nil;
    }
}


- (void) GetSystemVersion
{

    self.versionMajor = self.versionMinor = self.versionBugFix = 0;

    NSString* versionString = [[NSDictionary dictionaryWithContentsOfFile:
                                @"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"];
    NSArray* versions = [versionString componentsSeparatedByString:@"."];
    if ( versions.count >= 1 ) {
        self.versionMajor = [[versions objectAtIndex:0] integerValue];
        if ( versions.count >= 2 ) {
            self.versionMinor = [[versions objectAtIndex:1] integerValue];
            if ( versions.count >= 3 ) {
                self.versionBugFix = [[versions objectAtIndex:2] integerValue];
            }
        }
    }
}


-(BOOL) isANumber: (NSString *)string
{
    NSPredicate *numberPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES '^[0-9]+$'"];
    return [numberPredicate evaluateWithObject:string];
}


- (void) setControlOff
{
    self.statusField.textColor = [NSColor blackColor];
    self.statusField.stringValue = @"Not connected";
    self.statusField.selectable = YES;
    self.statusProgress.hidden = YES;
    [self.statusProgress stopAnimation: self];
    // disable some control until we connect
    [self enableDisableControls: false];

}

-(void) enableDisableControls: (BOOL)Enabled
{
    self.HaltButton.enabled = Enabled;
    self.CloseButton.enabled = Enabled;
    self.TurnOnButton.enabled = Enabled;
    self.Brightness.enabled = Enabled;
    self.Device.stringValue = @"N/A";
    self.FirmwareVersion.stringValue = @"N/A";
    self.currentMotorState.stringValue = @"N/A";
    self.currentCoverState.stringValue = @"N/A";
}

- (void) updateDeviceType:(UInt16)devType
{
    switch (devType) {
        case FLIPFLAP:
            self.Device.stringValue = @"Flip-Flat";
            break;
        case FLATMANXL:
            self.Device.stringValue = @"Flat-Man XL";
            break;
        case FLATMAN:
            self.Device.stringValue = @"Flat-Man";
            break;
        case FLATMANL:
            self.Device.stringValue = @"Flat-Man L";
            break;
    }

}

- (void) updateDeviceControls:(NSString *)response
{
    // *Siiqrs

    // check device type to enable/disable open/close controls
    NSRange devRange = NSMakeRange (2,2);
    self.deviceType = [[response substringWithRange:devRange] intValue];
    [self updateDeviceType: self.deviceType];

    NSRange lightRange = NSMakeRange (5,1);
    self.lightState = [[response substringWithRange:lightRange] intValue];

    NSRange motorRange = NSMakeRange (4,1);
    self.motorState = [[response substringWithRange:motorRange] intValue];

    NSRange coverRange = NSMakeRange (6,1);
    self.coverState = [[response substringWithRange:coverRange] intValue];

    if (self.deviceType == FLIPFLAP) {
        // enable open/close controls
        self.HaltButton.enabled = true;
        self.CloseButton.enabled = true;
        if (self.motorState) {
            self.currentMotorState.stringValue = @"Running";
        }
        else {
            self.currentMotorState.stringValue = @"Stopped";
        }

        switch (self.coverState ) {
            case 0:
                self.currentCoverState.stringValue = @"not open/closed";
                self.flipFlatIsOpen = false;
                self.CloseButton.title = @"Close";
                break;

            case 1:
                self.currentCoverState.stringValue = @"closed";
                self.flipFlatIsOpen = false;
                self.CloseButton.title = @"Open";
                break;

            case 2:
                self.currentCoverState.stringValue = @"open";
                self.flipFlatIsOpen = true;
                self.CloseButton.title = @"Close";
                break;

            case 3:
                self.currentCoverState.stringValue = @"timed out";
                self.flipFlatIsOpen = false;

                break;
        }
    }
    else {
        self.HaltButton.enabled = NO;
        self.CloseButton.enabled = NO;
    }

    // enable light controll, set state
    if (self.lightState) {
        self.TurnOnButton.enabled = true;

        self.TurnOnButton.title = @"Turn off";
        self.lightIsOn = true;
        // get brightness.
        NSData *dataToSend = [fm_get_brightness dataUsingEncoding: NSUTF8StringEncoding ];
        [self.serialPort sendData:dataToSend];
        // wait for the answer
        [self.commandQueue addObject: [NSNumber numberWithInt: GET_BRIGHTNESS]];
    }
    else {
        self.TurnOnButton.enabled = true;
        self.TurnOnButton.title = @"Turn on";
        self.lightIsOn = false;
    }


}


-(void) updateConnectButtonLabel
{
    if (self.fm_mode != NONE)
        self.ConnectButton.title = @"Disconnect";
    else
        self.ConnectButton.title = @"Connect";
}


- (IBAction) connectToFlatman:(id)sender
{
    NSString *status =@"";
    int i;

    if (!self.serialPort) {
        self.statusField.textColor = [NSColor redColor];
        self.statusField.stringValue =@"Select a serial port before clicking \"Connect\"";
        return;
    }

    // disconnect from the focuser
    if (self.fm_mode != NONE) {
        if (self.serialPort.isOpen) {
            [self stopTimeoutTimer];
            self.shouldDisconnect = true;
            self.currentBuffer=@"";
            NSData *dataToSend = [fm_light_off dataUsingEncoding: NSUTF8StringEncoding ];
#ifdef DEBUG
            NSLog(@"dataToSend      : %@\n", dataToSend);
            NSLog(@"dataToSend [hex]: %@\n", [self dataToHex:dataToSend]);
#endif
            [self.serialPort sendData:dataToSend];
            // wait for the answer
            [self.commandQueue addObject: [NSNumber numberWithInt: LIGHT_OFF]];
            status = @"Disconnecting from device";
            [self startCommandiTmer:status  timeout:2.0];
        }
    }
    else {
        // is there already a connect command in the queue
        for (i=0; i< [self.commandQueue queueLenght]; i++) {
            if ( [self.commandQueue objectAtIndex:i] == [NSNumber numberWithInt: PING])
                return;
        }

        // connect to the flatman
        // set the port speed, stopbit, ...
        self.serialPort.baudRate = [NSNumber numberWithInteger:9600];
        self.serialPort.numberOfStopBits = (NSUInteger)1;
        self.serialPort.parity = ORSSerialPortParityNone;
        [self.serialPort open];
        self.serialPort.DTR = YES;
        // Drop RTS
        self.serialPort.RTS = NO;
        status = @"Connecting to device";
        // 2 seconds delay after droping RTS before you can talk to the device.
        [self startConnectionTimer:status waitTime:2.0f];
    }


}

- (IBAction)updateBrightness:(id)sender
{
    uint32_t brightness;
    NSData *dataToSend;


    brightness = self.Brightness.intValue;
    if (brightness == 0) {
        return;
    }

    // Do not send new command until we get the response from the previous one.
    if ([self.commandQueue queueLenght]) {
        return;
    }

    self.currentBrightness = brightness;

    NSMutableString *cmd = [[NSMutableString alloc] initWithString:fm_set_brightness];
    [cmd appendFormat:@"%03d\n", brightness];
    dataToSend = [cmd dataUsingEncoding: NSUTF8StringEncoding];
#ifdef DEBUG
    NSLog(@"cmd : \n%@", cmd);
    NSLog(@"dataToSend : \n%@", [self dataToHex:dataToSend]);
#endif

    [self.serialPort sendData:dataToSend];

    // wait for the answer
    [self.commandQueue addObject: [NSNumber numberWithInt: SET_BRIGHTNESS]];
    [self startCommandiTmer: nil  timeout:2.0];

}

- (IBAction) turnLigthOn:(id)sender
{
    NSData *dataToSend;
    UInt16 toDo;
    NSString *message;

    // Do not send new command until we get the response from the previous one.
    while ([self.commandQueue queueLenght]) {
        // wait
        [NSThread sleepForTimeInterval:0.1f];
    }

    if (self.lightIsOn) {
        dataToSend = [fm_light_off dataUsingEncoding: NSUTF8StringEncoding ];
        toDo = LIGHT_OFF;
        message = @"Truning off";
    }
    else {
        dataToSend = [fm_light_on dataUsingEncoding: NSUTF8StringEncoding ];
        toDo = LIGHT_ON;
        message = @"Truning on";
    }

    [self.serialPort sendData:dataToSend];
    // wait for the answer
    [self.commandQueue addObject: [NSNumber numberWithInt: toDo]];
    [self startCommandiTmer: message  timeout:2.0];

}

- (IBAction) openFlipFlat:(id)sender
{
    NSData *dataToSend;
    UInt16 toDo;
    NSString *message;
    // Do not send new command until we get the response from the previous one.
    while ([self.commandQueue queueLenght]) {
        // wait
        [NSThread sleepForTimeInterval:0.1f];
    }

    if (self.flipFlatIsOpen) {
        dataToSend= [fm_close dataUsingEncoding: NSUTF8StringEncoding ];
        toDo = CLOSE;
        message = @"Closing";
    }
    else {
        dataToSend= [fm_open dataUsingEncoding: NSUTF8StringEncoding ];
        toDo = OPEN;
        message = @"Opening";
    }

    [self.serialPort sendData:dataToSend];
    // wait for the answer
    [self.commandQueue addObject: [NSNumber numberWithInt: toDo]];
    [self startCommandiTmer: message  timeout:60.0];

}

- (IBAction) haltFlipFlat:(id)sender
{
    // Do not send new command until we get the response from the previous one.
    while ([self.commandQueue queueLenght]) {
        // wait
    }

    NSData *dataToSend = [fm_motor_halt dataUsingEncoding: NSUTF8StringEncoding ];
    [self.serialPort sendData:dataToSend];
    // wait for the answer
    [self.commandQueue addObject: [NSNumber numberWithInt: HALT]];

}


#pragma mark - Timer control

- (void) startTimeoutTimer: (float) timeout
{

    [self stopTimeoutTimer];

    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                         target:self
                                                       selector:@selector(timeOut:)
                                                       userInfo:nil
                                                        repeats:NO];

#if (MAC_OS_X_VERSION_MAX_ALLOWED > 1080)
    if (self.versionMajor == 10 && self.versionMinor >8)
        [self.timeoutTimer setTolerance:0.2];
#endif
}

- (void) startConnectionTimer: (NSString*)message waitTime:(float) waitTimeValue
{
    self.statusField.textColor = [NSColor blackColor];
    if (message) {
        self.statusField.stringValue = message;
        self.statusProgress.hidden = NO;
        [self.statusProgress startAnimation: self];
    }
    else {
        self.statusField.stringValue = @"";
    }

    self.connectionTimer = [NSTimer scheduledTimerWithTimeInterval:waitTimeValue
                                                         target:self
                                                       selector:@selector(sendConnectPing:)
                                                       userInfo:nil
                                                        repeats:NO];

#if (MAC_OS_X_VERSION_MAX_ALLOWED > 1080)
    if (self.versionMajor == 10 && self.versionMinor >8)
        [self.connectionTimer setTolerance:0.2];
#endif

}

- (void) stopTimeoutTimer
{
    // stop the timer
    if (self.timeoutTimer) {
        [self.timeoutTimer invalidate];
        self.timeoutTimer = nil;

        if([self.commandQueue queueLenght])
            [self.commandQueue takeObject];
    }
}

- (void) timerOk: (NSString*)message
{
    [self.statusProgress stopAnimation: self];
    self.statusProgress.hidden = YES;
    self.statusField.textColor = [NSColor blackColor];
    self.statusField.stringValue = message;

}


- (void) startCommandiTmer: (NSString*)message timeout:(float)timeoutValue
{
    [self startTimeoutTimer: timeoutValue];
    self.statusField.textColor = [NSColor blackColor];
    if (message) {
        self.statusField.stringValue = message;
        self.statusProgress.hidden = NO;
        [self.statusProgress startAnimation: self];
    }
    else {
        self.statusField.stringValue = @"";
    }
}

- (void) sendConnectPing: (NSTimer *)timer
{
    // stop the timer
    if (self.connectionTimer) {
        [self.connectionTimer invalidate];
        self.connectionTimer = nil;
    }

    NSString *status =@"";
    self.currentBuffer=@"";
    NSData *dataToSend = [fm_ping dataUsingEncoding: NSUTF8StringEncoding ];

#ifdef DEBUG
    NSLog(@"dataToSend      : %@\n", dataToSend);
    NSLog(@"dataToSend [hex]: %@\n", [self dataToHex:dataToSend]);
#endif
    [self.serialPort sendData:dataToSend];
    [NSThread sleepForTimeInterval:0.1f];
    // wait for the answer
    [self.commandQueue addObject: [NSNumber numberWithInt: PING]];

    status = @"Connecting to device";
    self.firstConnect = true;
    [self startCommandiTmer:status  timeout:2.0];

}

- (void) timeOut: (NSTimer *)timer
{
    NSString *errorMessage = @"";
    UInt16 command;

    [self.statusProgress stopAnimation: self];
    self.statusProgress.hidden = YES;
    if([self.commandQueue queueLenght])
        command = [[self.commandQueue takeObject ] intValue];
    else
        command = NONE;

    switch (command) {
        case PING :
            if (self.firstConnect) {
                [self.serialPort close];
                errorMessage = @"Error connecting to the device";
            }
            else {
                errorMessage = @"Error pingingthe device";
            }
            break;

        case GET_STATE :
            errorMessage = @"Error getting state from the device";
            break;

        case OPEN :
            errorMessage = @"Error opening Flip-Flat";
            break;

        case CLOSE :
            errorMessage = @"Error closing Flip-Flat";
            break;

        case LIGHT_ON :
            errorMessage = @"Error swicthing light on";
            break;

        case LIGHT_OFF :
            errorMessage = @"Error swicthing light off";
            if (self.shouldDisconnect) {
                // close the port
                [self.serialPort close];
                self.fm_mode = NONE;
                [self updateConnectButtonLabel];
                [self.commandQueue emptyQueue ];
                [self setControlOff];
            }
            break;

        case SET_BRIGHTNESS :
            errorMessage = @"Error setting brightness";
            break;

        case GET_BRIGHTNESS :
            errorMessage = @"Error getting brightness";
            break;

        case GET_VERSION :
            errorMessage = @"Error getting firmware version";
            break;

        default :
            errorMessage = @"Error ";
            break;


    }
    self.statusField.stringValue = errorMessage;
    self.statusField.textColor = [NSColor redColor];
    // do we want to cancel all the other commands ?
    [self.commandQueue emptyQueue ];

#ifdef DEBUG
    NSLog(@"current data buffer content : \n%@", self.currentBuffer);
#endif
    self.currentBuffer = @"";
}


#pragma mark - Flatman response Methods
-(void) processFlatmanCommandResponse:(NSString *)response
{
    NSString *resp_cmd;
#ifdef DEBUG
    NSLog(@"current response buffer       : %@\n", response);
    NSLog(@"current response buffer (hex) : %@\n", [self stringToHex:response]);
    NSLog(@"current response len          : %lu\n", [response length]);
#endif
    // all response are 7 bytes long
    if ([response length] >= 7)
        resp_cmd = [response substringWithRange:NSMakeRange(0,2)];
    else
        return;

    if ( [resp_cmd isEqualToString:fm_ping_answer]) {
        [self stopTimeoutTimer];
        if (self.firstConnect) {
            [self timerOk: @"Connected"];
            self.fm_mode = CONNECTED;
            [self updateConnectButtonLabel];
            [self enableDisableControls:true];
            [self updateDeviceControls:response];
        }
        [self processFlatmanResponsePing:response];
    }
    else if ( [resp_cmd isEqualToString:fm_open_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseOpen:response];
    }
    else if ( [resp_cmd isEqualToString:fm_close_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseClose:response];
    }
    else if ( [resp_cmd isEqualToString:fm_light_on_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseLightOn:response];
    }
    else if ( [resp_cmd isEqualToString:fm_light_off_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseLightOff:response];
    }
    else if ( [resp_cmd isEqualToString:fm_set_brightness_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseSetBrightness:response];
    }
    else if ( [resp_cmd isEqualToString:fm_get_brightness_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseGetBrightness:response];
    }
    else if ( [resp_cmd isEqualToString:fm_get_state_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseGetState:response];
    }
    else if ( [resp_cmd isEqualToString:fm_get_version_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseGetVersion:response];
    }
    else if ( [resp_cmd isEqualToString:fm_motor_halt_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processFlatmanResponseMotorHalt:response];
    }

}


- (void) processFlatmanResponsePing:(NSString *)response
{

    // *Pii000
    NSRange devRange = NSMakeRange (2,2);
    self.deviceType = [[response substringWithRange:devRange] intValue];
    [self updateDeviceType: self.deviceType];
    NSData *dataToSend = [fm_get_state dataUsingEncoding: NSUTF8StringEncoding ];
    [self.serialPort sendData:dataToSend];
    // wait for the answer
    [self.commandQueue addObject: [NSNumber numberWithInt: GET_STATE]];
    [self startCommandiTmer: @"Getting state"  timeout:2.0];

}

- (void) processFlatmanResponseOpen:(NSString *)response
{
    // *Oii000
    // does it replies when it's done opening or before ?
    self.CloseButton.title = @"Close";

}

- (void) processFlatmanResponseClose:(NSString *)response
{
    // *Cii000
    // does it replies when it's done closing or before ?
    self.CloseButton.title = @"Open";

}

- (void) processFlatmanResponseLightOn:(NSString *)response
{
    // *Lii000
    self.TurnOnButton.title = @"Turn off";
    self.lightIsOn = true;
    self.Brightness.enabled = YES;

    NSData *dataToSend = [fm_get_brightness dataUsingEncoding: NSUTF8StringEncoding ];
    [self.serialPort sendData:dataToSend];
    // wait for the answer
    [self.commandQueue addObject: [NSNumber numberWithInt: GET_BRIGHTNESS]];
    [self startCommandiTmer: @"Getting state"  timeout:2.0];

}

- (void) processFlatmanResponseLightOff:(NSString *)response
{
    if(self.shouldDisconnect){
        // close the port
        [self.serialPort close];
        self.fm_mode = NONE;
        [self updateConnectButtonLabel];
        [self timerOk: @"Disconnected"];
        [self.commandQueue emptyQueue ];
        [self setControlOff];
    }
    else {
        // *Dii000
        self.TurnOnButton.title = @"Turn on";
        self.lightIsOn = false;
        self.Brightness.enabled = NO;
    }
}

- (void) processFlatmanResponseSetBrightness:(NSString *)response
{
    // *Biixxx
    // not sure I need to do anything here.
}

- (void) processFlatmanResponseGetBrightness:(NSString *)response
{
    // *Jiixxx
    NSRange brightnessRange = NSMakeRange (4,3);
    self.currentBrightness = [[response substringWithRange:brightnessRange] intValue];
    self.Brightness.doubleValue = (double)self.currentBrightness;
}

- (void) processFlatmanResponseGetState:(NSString *)response
{
    // *Siiqrs
    [self updateDeviceControls:response];
    if (self.firstConnect) {
        NSData *dataToSend = [fm_get_version dataUsingEncoding: NSUTF8StringEncoding ];
        [self.serialPort sendData:dataToSend];
        // wait for the answer
        [self.commandQueue addObject: [NSNumber numberWithInt: GET_VERSION]];
        [self startCommandiTmer: @"Getting firmware version"  timeout:2.0];
    }

}

- (void) processFlatmanResponseGetVersion:(NSString *)response
{
    // *Viivvv
    NSString *version;
    NSRange versionRange = NSMakeRange (3,3);
    version = [response substringWithRange:versionRange];
    self.FirmwareVersion.stringValue = version;
    if (self.firstConnect) {
        NSData *dataToSend = [fm_get_brightness dataUsingEncoding: NSUTF8StringEncoding ];
        [self.serialPort sendData:dataToSend];
        // wait for the answer
        [self.commandQueue addObject: [NSNumber numberWithInt: GET_BRIGHTNESS]];
        [self startCommandiTmer: @"Getting state"  timeout:2.0];
        self.firstConnect = false;
    }
}

- (void) processFlatmanResponseMotorHalt:(NSString *)response
{
    // *Hiixxx
    // not sure I need to do anything here.
}

#pragma mark - ORSSerialPortDelegate Methods

- (void) serialPortWasOpened:(ORSSerialPort *)serialPort
{
}

- (void) serialPortWasClosed:(ORSSerialPort *)serialPort
{
}

- (void) serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    int i;
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([string length] == 0)
        return;
#ifdef DEBUG
    NSLog(@"received string : %@\n", [self stringToHex:string]);
#endif

    if(!self.responseQueue && !self.commandQueue)
        return;

    self.currentBuffer = [self.currentBuffer stringByAppendingString:string];
#ifdef DEBUG
    NSLog(@"currentBuffer : %@\n", self.currentBuffer);
    NSLog(@"currentBuffer (hex) : %@\n", [self stringToHex:self.currentBuffer]);
#endif

    NSArray *dataChunk = [self.currentBuffer componentsSeparatedByString:@"\n"];

    self.currentBuffer = [dataChunk lastObject];
#ifdef DEBUG
    NSLog(@"currentBuffer (hex) : %@\n", [self stringToHex:self.currentBuffer]);
#endif

    for ( i=0; i<[dataChunk count]; i++) {
        NSString *s = [dataChunk objectAtIndex:i];
#ifdef DEBUG
        NSLog(@"s (hex) : %@\n", [self stringToHex:s]);
#endif
        if([s length] > 0)
            [self.responseQueue addObject: [dataChunk objectAtIndex:i]];
    }
    while([self.responseQueue queueLenght])
        [self processFlatmanCommandResponse:[self.responseQueue takeObject]];
}

- (void) serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
{
    // After a serial port is removed from the system, it is invalid and we must discard any references to it
    self.serialPort = nil;
    self.ConnectButton.title = @"Connect";
}

- (void) serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"Serial port %@ encountered an error: %@", serialPort, error);
#endif
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
#ifdef DEBUG
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, object, keyPath);
    NSLog(@"Change dictionary: %@", change);
#endif
}

#pragma mark - NSUserNotificationCenterDelegate

#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)

- (void) userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [center removeDeliveredNotification:notification];
    });
}

- (BOOL) userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

#endif

#pragma mark - Notifications

- (void) serialPortsWereConnected:(NSNotification *)notification
{
    NSArray *connectedPorts = [[notification userInfo] objectForKey:ORSConnectedSerialPortsKey];
#ifdef DEBUG
    NSLog(@"Ports were connected: %@", connectedPorts);
#endif
    [self postUserNotificationForConnectedPorts:connectedPorts];
}

- (void) serialPortsWereDisconnected:(NSNotification *)notification
{
    NSArray *disconnectedPorts = [[notification userInfo] objectForKey:ORSDisconnectedSerialPortsKey];
#ifdef DEBUG
    NSLog(@"Ports were disconnected: %@", disconnectedPorts);
#endif
    [self postUserNotificationForDisconnectedPorts:disconnectedPorts];

}

- (void) postUserNotificationForConnectedPorts:(NSArray *)connectedPorts
{
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
    if (!NSClassFromString(@"NSUserNotificationCenter")) return;

    NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (ORSSerialPort *port in connectedPorts)
    {
        NSUserNotification *userNote = [[NSUserNotification alloc] init];
        userNote.title = NSLocalizedString(@"Serial Port Connected", @"Serial Port Connected");
        NSString *informativeTextFormat = NSLocalizedString(@"Serial Port %@ was connected to your Mac.", @"Serial port connected user notification informative text");
        userNote.informativeText = [NSString stringWithFormat:informativeTextFormat, port.name];
        userNote.soundName = nil;
        [unc deliverNotification:userNote];
    }
#endif
}

- (void) postUserNotificationForDisconnectedPorts:(NSArray *)disconnectedPorts
{
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
    if (!NSClassFromString(@"NSUserNotificationCenter")) return;

    NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (ORSSerialPort *port in disconnectedPorts)
    {
        NSUserNotification *userNote = [[NSUserNotification alloc] init];
        userNote.title = NSLocalizedString(@"Serial Port Disconnected", @"Serial Port Disconnected");
        NSString *informativeTextFormat = NSLocalizedString(@"Serial Port %@ was disconnected from your Mac.", @"Serial port disconnected user notification informative text");
        userNote.informativeText = [NSString stringWithFormat:informativeTextFormat, port.name];
        userNote.soundName = nil;
        [unc deliverNotification:userNote];
    }
#endif
}

@synthesize serialPortManager = _serialPortManager;
- (void) setSerialPortManager:(ORSSerialPortManager *)manager
{
    if (manager != _serialPortManager)
    {
        [_serialPortManager removeObserver:self forKeyPath:@"availablePorts"];
        _serialPortManager = manager;
        NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
        [_serialPortManager addObserver:self forKeyPath:@"availablePorts" options:options context:NULL];
    }
}

@synthesize serialPort = _serialPort;
- (void) setSerialPort:(ORSSerialPort *)port
{
    if (port != _serialPort)
    {
        [_serialPort close];
        _serialPort.delegate = nil;

        _serialPort = port;

        _serialPort.delegate = self;
    }
}

@synthesize availableBaudRates = _availableBaudRates;


@end
