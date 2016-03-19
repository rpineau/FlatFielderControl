//
//  AppDelegate.h
//  FlatFielderControl
//
//  Created by roro on 19/03/16.
//  Copyright © 2016 RTI-Zone. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
}
@property (assign) IBOutlet NSWindow *window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void)applicationWillTerminate:(NSNotification *)notification;
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app;


@end

