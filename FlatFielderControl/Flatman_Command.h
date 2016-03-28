//
//  Flatman_Command.h
//  FlatFielderControl
//
//  Created by roro on 19/3/16.
//  Copyright © 2016 RTI-Zone. All rights reserved.
//

#ifndef Flatman_Command_h
#define Flatman_Command_h

enum { NONE=0, CONNECTED, PING, OPEN, CLOSE, LIGHT_ON, LIGHT_OFF, SET_BRIGHTNESS,
    GET_BRIGHTNESS, GET_STATE, GET_VERSION
};
// 99 for Flip-Flat, 19 for Flat-Man, 10 for XL, 15 Flat-Man_L
enum { FLIPFLAP=99, FLATMAN=19, FLATMANXL=10, FLATMANL=15};
// doc is wrong, all command end with LF (\n, 0x0A), not CR (\r , 0x0D)

NSString *fm_ping = @">P000\n";
NSString *fm_ping_answer = @"*P";

NSString *fm_open = @">O000\n";
NSString *fm_open_answer = @"*O";

NSString *fm_close = @">C000\n";
NSString *fm_close_answer = @"*C";

NSString *fm_light_on = @">L000\n";
NSString *fm_light_on_answer = @"*L";

NSString *fm_light_off = @">D000\n";
NSString *fm_light_off_answer = @"*D";

NSString *fm_set_brightness = @">B";
NSString *fm_set_brightness_answer = @"*B";

NSString *fm_get_brightness = @">J000\n";
NSString *fm_get_brightness_answer = @"*J";

NSString *fm_get_state = @">S000\n";
NSString *fm_get_state_answer = @"*S";

NSString *fm_get_version = @">V000\n";
NSString *fm_get_version_answer = @"*V";



#endif /* Flatman_Command_h */
