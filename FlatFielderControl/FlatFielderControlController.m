//
//  FlatFielderControlController.m
//  FlatFielderControl
//
//  Created by roro on 19/3/16.
//  Copyright © 2016 RTI-Zone. All rights reserved.
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
            self.fm_mode = NONE;
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



- (void) awakeFromNib
{
    // set some default
    /*
    self.maxPosition = 7000;
    self.tcf3_enable = false;
    self.focusStep = 1;
    self.firstFPOSRO = true;
    self.firstFREADX = true;
    self.firstConnect = true;
    self.shouldDisconnect = false;
    [self.focuserStepper setMinValue: 1];
    [self.focuserStepper setMaxValue: 1000];
    self.focuserTempCompData = malloc(sizeof(TCF_tempCompData_type));
    if (!self.focuserTempCompData) {
        NSLog(@"Memory allocation error .. exiting");
        [NSApp terminate:self];
    }
     */
    self.commandQueue = [[Queue alloc] init];
    self.responseQueue = [[Queue alloc] init];
    [self.Brightness setContinuous:YES];
    [self.Brightness setIntegerValue:0];
    self.currentBrightness = 0;
    [self setControlOff];
    
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
    /*
    self.tcf_mode = FNONE;
    self.currentPosition = 0;
    self.center_on_connect = false;
    self.currentBuffer = nil;
    self.timeoutTimer = nil;
    // set the focus control with the default values
    [self.focuserIncrement setStringValue: [NSString stringWithFormat:@"%d", self.focusStep]];
    [self.GotoValue setStringValue: [NSString stringWithFormat:@"%d", self.currentPosition]];
     */
    [self.statusField setTextColor: [NSColor blackColor]];
    [self.statusField setStringValue:@"Not connected"];
    [self.statusField  setSelectable:YES];
    [self.statusProgress setHidden:YES];
    [self.statusProgress stopAnimation: self];
        
    // disable some control until we connect
    [self enableDisableControls: false];
    
}

-(void) enableDisableControls: (BOOL)Enabled
{

    /*
    [self.GotoValue setEnabled:Enabled];
    [self.CenterButton setEnabled:Enabled];
    [self.focuserIncrement setEnabled:Enabled];
    [self.focuserStepper setEnabled:Enabled];
    [self.inButton setEnabled:Enabled];
    [self.outButton setEnabled:Enabled];
    [self.gotoButton setEnabled:Enabled];
    [self.centerButton setEnabled:Enabled];
    */
}


-(void) updateConnectButtonLabel
{
    /*
    if (self.tcf_mode != FNONE)
        self.ConnectButton.title = @"Disconnect";
    else
        self.ConnectButton.title = @"Connect";
     */
}


- (IBAction) connectToFlatman:(id)sender
{
    if (!self.serialPort) {
        [self.statusField setTextColor: [NSColor redColor]];
        [self.statusField setStringValue:@"Select a serial port before clicking \"Connect\""];
        return;
    }
    
    NSString *status =@"";
    int i;

    // disconnect from the focuser
    if (self.fm_mode != NONE) {
        if (self.serialPort.isOpen) {
            [self stopTimeoutTimer];
            // close the port
            [self.serialPort close];
            self.fm_mode = NONE;
            [self updateConnectButtonLabel];
        }
    }
    else {
        // is there already a connect command in the queue
        for (i=0; i< [self.commandQueue queueLenght]; i++) {
            if ( [self.commandQueue objectAtIndex:i] == [NSNumber numberWithInt: GET_STATE])
                return;
        }
        
        // connect to the focuser
        // set the port speed, stopbit, ...
        self.serialPort.baudRate = [NSNumber numberWithInteger:9600];
        self.serialPort.numberOfStopBits = (NSUInteger)1;
        self.serialPort.parity = ORSSerialPortParityNone;
        
        [self.serialPort open];
        self.currentBuffer=@"";
        NSData *dataToSend = [fm_get_state dataUsingEncoding: [NSString defaultCStringEncoding] ];
        [self.serialPort sendData:dataToSend];
        // wait for the answer
        [self.commandQueue addObject: [NSNumber numberWithInt: GET_STATE]];
        
        status = @"Connecting to device";
        self.firstConnect = true;
    }
    
    [self startCommandiTmer:status  timeout:5.0];

}

- (IBAction)updateBrightness:(id)sender
{
    uint32_t temp;
    
    temp = [self.Brightness intValue];
    printf("Update brightness to %u\n", temp);
    self.currentBrightness = temp;
}


#pragma mark - Timer control

-(void) startTimeoutTimer: (float) timeout
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

-(void) stopTimeoutTimer
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
    [self.statusProgress setHidden:YES];
    [self.statusField setTextColor: [NSColor blackColor]];
    [self.statusField setStringValue:message];
    
}


- (void) startCommandiTmer: (NSString*)message timeout:(float)timeoutValue
{
    [self startTimeoutTimer: timeoutValue];
    [self.statusField setTextColor: [NSColor blackColor]];
    [self.statusField setStringValue:message];
    [self.statusProgress setHidden:NO];
    [self.statusProgress startAnimation: self];
    
}

-(void) timeOut: (NSTimer *)timer
{
    NSString *errorMessage = @"";
    UInt16 command;
    [self.statusProgress stopAnimation: self];
    [self.statusProgress setHidden:YES];
}


#pragma mark - Flatman response Methods
-(void) processFlatmanCommandResponse:(NSString *)response
{
    NSString *resp_cmd;
    NSString *resp_cmd3 = nil;
#ifdef DEBUG
    NSLog(@"current response buffer : \n%@", response);
    NSLog(@"current response len %lu", [response length]);
#endif
    // we only use the 1st or 2 st caracter to check what response we got.
    // this is only used for reponse with values.
    if ([response length]>2)
        resp_cmd3 = [response substringWithRange:NSMakeRange(0,3)];
    
    if ([response length]>1)
        resp_cmd = [response substringWithRange:NSMakeRange(0,2)];
    else
        resp_cmd = response;
    /*
    if ( [response isEqualToString:focuser_manual_mode_answer]) {
        [self stopTimeoutTimer];
        [self processCommandResponseFMMODE:response];
    }
    else if ( [response isEqualToString:focus_in_out_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self focuserFPOSRO];
    }
    
    else if ( [resp_cmd isEqualToString:[focuser_get_pos_answer substringWithRange:NSMakeRange(0, 2)]]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processCommandResponseFPOSRO:response];
    }
    
    else if ( [resp_cmd isEqualToString:[focuser_get_temp_answer substringWithRange:NSMakeRange(0, 2)]]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self processCommandResponseFTMPRO:response];
    }
    
    else if ([response isEqualToString:focus_center_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        [self focuserFPOSRO];
    }
    
    else if ([response isEqualToString:focuser_sleep_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Sleeping"];
    }
    else if ([response isEqualToString:focuser_wakeup_answer]) {
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
    }
    
    // a bunch of command only respond with DONE
    else if ([response isEqualToString:focuser_DONE_answer]) {
        // we need to check which command we just sent
        UInt16 command;
        if([self.commandQueue queueLenght])
            command = [[self.commandQueue objectAtIndex:0 ] intValue];
        else
            command = FNONE;
        // stop the timeout as we know we got an answer
        [self stopTimeoutTimer];
        [self timerOk: @"Connected"];
        
        switch(command){
            case FLAnnn :
                // send FREADA
                [self focuserFREADA];
                break;
            case FLBnnn :
                // send FREADB
                [self focuserFREADB];
                break;
            case FQUITn :
                // nothing to do
                break;
            case FDAnnn :
                // probably nothing to do
                break;
            case FDBnnn :
                // probably nothing to do
                break;
            case FHOME :
                // nothing to do
                break;
            case FZAxxn :
                // send FtxxxA
                break;
            case FZBxxn :
                // send FtxxxB
                break;
        }
    }
    else if ( [response isEqualToString:focuser_free_mode_answer]) {
        [self processCommandResponseFFMODE:response];
        [self stopTimeoutTimer];
        [self setControlOff];
    }
    else if (resp_cmd3) {
        // check for A= vs A=0 respose (and same with B)
        if ( [resp_cmd3 isEqualToString:focuser_FREADA_answer ]) {
            [self stopTimeoutTimer];
            [self timerOk: @"Connected"];
            [self processCommandResponseFREADA:response];
        }
        else if ( [resp_cmd3 isEqualToString:focuser_FREADB_answer ]) {
            [self stopTimeoutTimer];
            [self timerOk: @"Connected"];
            [self processCommandResponseFREADB:response];
        }
        
        else if ( [resp_cmd isEqualToString:focuser_FTxxxA_answer ]) {
            [self stopTimeoutTimer];
            [self timerOk: @"Connected"];
            [self processCommandResponseFTxxxA:response];
        }
        else if ( [resp_cmd isEqualToString:focuser_FTxxxA_answer ]) {
            [self stopTimeoutTimer];
            [self timerOk: @"Connected"];
            [self processCommandResponseFTxxxB:response];
        }
    }
    */
}

- (void) processFlatmanResponsePing:(NSString *)response
{
    
}

- (void) processFlatmanResponseCclose:(NSString *)response
{
    
}

- (void) processFlatmanResponseLightOn:(NSString *)response
{
    
}

- (void) processFlatmanResponseLightOff:(NSString *)response
{
    
}

- (void) processFlatmanResponseSetBrightness:(NSString *)response
{
    
}

- (void) processFlatmanResponseGetBrightness:(NSString *)response
{
    
}

- (void) processFlatmanResponseGetState:(NSString *)response
{
    
}

- (void) processFlatmanResponseGetVersion:(NSString *)response
{
    
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
    NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    if ([string length] == 0)
        return;
    
    if(!self.responseQueue && !self.commandQueue)
        return;
    
    self.currentBuffer = [self.currentBuffer stringByAppendingString:string];
    NSArray *dataChunk = [self.currentBuffer componentsSeparatedByString:@"\n\r"];
    
    self.currentBuffer = [dataChunk lastObject];
    
    for ( i=0; i<[dataChunk count]; i++) {
        NSString *s = [dataChunk objectAtIndex:i];
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
