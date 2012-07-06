//
//  RLRequestQueue.m
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

#import "RLRequestQueue.h"
#import "RLOperation.h"
#import <libkern/OSAtomic.h>

@interface RLRequestQueue()

//call back on the main thread for post processing
- (void)operationFinished:(RLOperation *)operation;

// Removes all objects from the queue
- (void)removeAllOperations;

// Removes the "top-most" (as determined by the callback sort function) object from the queue
// and returns it
- (RLOperation *)nextOperation;

// Returns the "top-most" (as determined by the callback sort function) object from the queue
// without removing it from the queue
- (RLOperation *)peekOperation;
@end

@implementation RLRequestQueue

#pragma mark -
#pragma mark CFBinaryHeap functions for sorting the priority queue

static const void *ExampleObjectRetain(CFAllocatorRef allocator, const void *ptr)
{
    RLOperation *operation = (RLOperation *)ptr;
    return [operation retain];
}

static void ExampleObjectRelease(CFAllocatorRef allocator, const void *ptr)
{
    RLOperation *operation = (RLOperation *) ptr;
    [operation release];
}

static CFStringRef ExampleObjectCopyDescription(const void* ptr)
{
    RLOperation *operation = (RLOperation *) ptr;
    CFStringRef desc = (CFStringRef) [operation description];
    return CFRetain(desc);
}

static CFComparisonResult ExampleObjectCompare(const void* ptr1, const void* ptr2, void* context)
{
    RLOperation *item1 = (RLOperation *) ptr1;
    RLOperation *item2 = (RLOperation *) ptr2;
	
    // In this example, we're sorting by distance property of the object
    // Objects with smallest distance will be first in the queue
    if ([item1 priority] < [item2 priority])
	{
        return kCFCompareLessThan;
    }
	else if ([item1 heapId] == [item2 heapId])
	{
        return kCFCompareEqualTo;
    }
	else
	{
        return kCFCompareGreaterThan;
    }
}

#pragma mark -
#pragma mark NSObject methods

+ (RLRequestQueue *)sharedQueue
{
    static dispatch_once_t once;
    static RLRequestQueue *sharedQueue;
    dispatch_once(&once, ^ { sharedQueue = [[self alloc] init]; });
    return sharedQueue;
}

- (id)init
{
    if ((self = [super init]))
	{
        _nextOperationNumber = 0;
		_currentlyRunningOperaions = 0;
		_queueIsRunning = NO;
        CFBinaryHeapCallBacks callbacks;
        callbacks.version = 0;
		
        // Callbacks to the functions above
        callbacks.retain = ExampleObjectRetain;
        callbacks.release = ExampleObjectRelease;
        callbacks.copyDescription = ExampleObjectCopyDescription;
        callbacks.compare = ExampleObjectCompare;
		
        // Create the priority queue
        _heap = CFBinaryHeapCreate(kCFAllocatorDefault, 0, &callbacks, NULL);
		
		//create the GCD queue
		_operationQueue = dispatch_queue_create("com.rantlab.requestQueue", 0);
    }
	
    return self;
}

- (void)dealloc
{
    if (_heap)
	{
        CFRelease(_heap);
    }
	
    [super dealloc];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"PriorityQueue = {%@}",
            (_heap ? [[self allOperations] description] : @"null")];
}

#pragma mark -
#pragma mark Queue methods

- (void)runQueue
{
	while (_queueIsRunning && _currentlyRunningOperaions < MAX_OPERATIONS && [self count] > 0)
	{
		RLOperation *nextOp = [self nextOperation];
		
		if (nextOp && !nextOp.canceled)
		{
			_currentlyRunningOperaions++;
			
			dispatch_async(_operationQueue, ^{
				
				//do the operation
				[nextOp run];
				
				dispatch_queue_t mainQueue = dispatch_get_main_queue();
				dispatch_async(mainQueue,  ^{
					[self operationFinished:nextOp];
				});
			});
		}
	}
}

- (void)startQueue
{
	_queueIsRunning = YES;
	[self runQueue];
}

- (void)stopQueue
{
	_queueIsRunning = NO;
}

- (void)checkQueue
{
	if (_queueIsRunning && _currentlyRunningOperaions < MAX_OPERATIONS)
	{
		[self runQueue];
	}
}

- (void)operationFinished:(RLOperation *)operation
{	
	[operation finish];
	
	_currentlyRunningOperaions--;
	[self checkQueue];
}

- (NSUInteger)count
{
    return CFBinaryHeapGetCount(_heap);
}

- (NSArray *)allOperations
{
    const void **arrayC = calloc(CFBinaryHeapGetCount(_heap), sizeof(void *));
    CFBinaryHeapGetValues(_heap, arrayC);
    NSArray *array = [NSArray arrayWithObjects:(id *)arrayC
                                         count:CFBinaryHeapGetCount(_heap)];
    free(arrayC);
    return array;
}

- (void)addOperation:(RLOperation *)operation
{
    _nextOperationNumber++;
    if (_nextOperationNumber > 0xFFFFFFF)
    {
        _nextOperationNumber = 0;
    }
	//NSLog(@"adding operation to queue: %@", [operation description]);
    int priorityBitShift = operation.priority << 28;
    operation.heapId = _nextOperationNumber + priorityBitShift;
    CFBinaryHeapAddValue(_heap, operation);
	[self checkQueue];
}

- (void)removeAllOperations
{
    CFBinaryHeapRemoveAllValues(_heap);
}

- (RLOperation *)nextOperation
{
    RLOperation *obj = [[self peekOperation] retain];
    CFBinaryHeapRemoveMinimumValue(_heap);
    return [obj autorelease];
}

- (RLOperation *)peekOperation
{
    return (RLOperation *)CFBinaryHeapGetMinimum(_heap);
}

@end

