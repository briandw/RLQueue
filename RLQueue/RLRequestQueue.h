//
//  RLRequestQueue.h
//  RLQueue
//
//The MIT License (MIT) Copyright (c) 2011 Brian D Williams
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of
//this software and associated documentation files (the "Software"), to deal in
//the Software without restriction, including without limitation the rights to
//use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//the Software, and to permit persons to whom the Software is furnished to do so,
//subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

//The starting point for this code was taken from
//http://three20.pypt.lt/cocoa-objective-c-priority-queue
//but has been substantially changed and added to

// This file has been exampted from ARC due to the CF code
//

#import <Foundation/Foundation.h>
#import "RLOperation.h"

#define MAX_OPERATIONS 5

@interface RLRequestQueue : NSObject
{
@private
	// Heap itself
	CFBinaryHeapRef _heap;
	dispatch_queue_t _operationQueue;
	NSUInteger _currentlyRunningOperaions;
	BOOL _queueIsRunning;
    volatile NSInteger _nextOperationNumber;
}

+ (RLRequestQueue *)singleton;

- (void)startQueue;
- (void)stopQueue;

// Returns number of items in the queue
- (NSUInteger)count;

// Returns all (sorted) objects in the queue
- (NSArray *)allOperations;

// Adds an object to the queue
- (void)addOperation:(RLOperation *)operation;

@end