//
//  Queue.h
//  FocusControl
//
//  Created by roro on Thursday 17/10/13.
//  Copyright (c) 2013 RTI-Zone. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Queue:NSObject
{
    NSMutableArray* objects;
}

- (void)addObject:(id)object;
- (id)takeObject;
- (UInt16)queueLenght;
- (id)objectAtIndex:(int)index;
- (void) emptyQueue;
@end
