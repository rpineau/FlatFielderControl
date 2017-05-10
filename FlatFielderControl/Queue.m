//
//  Queue.m
//  FocusControl
//
//  Created by roro on Thursday 17/10/13.
//  Copyright (c) 2013 RTI-Zone. All rights reserved.
//

#import "Queue.h"

@implementation Queue

- (id)init {
    if ((self = [super init])) {
        objects = [[NSMutableArray alloc] init];
    }
    return self;
}


- (void)addObject:(id)object {
    [objects addObject:object];
}

- (id)takeObject
{
    id object = nil;
    if ([objects count] > 0) {
        object = [objects objectAtIndex:0];
        [objects removeObjectAtIndex:0];
    }
return object;
}

- (id)objectAtIndex:(int)index
{
    return [objects objectAtIndex:index];
}

- (void) emptyQueue
{
    [objects removeAllObjects];
}

- (UInt16)queueLenght
{
    return [objects count];
}
@end