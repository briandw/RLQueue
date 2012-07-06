//
//  RLOperation.m
//  RLQueue

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


#import "RLOperation.h"
#import "RLRequestQueue.h"

@implementation RLOperation

@synthesize name = _name;
@synthesize priority = _priority;
@synthesize canceled = _canceled;
@synthesize running = _running;
@synthesize error = _error;
@synthesize successBlock = _successBlock;
@synthesize errorBlock = _errorBlock;
@synthesize processingBlock = _processingBlock;
@synthesize heapId = _heapId;

//designated initalizer
- (id)initWithName:(NSString *)initName
		  priority:(RLOperationPriority)priority
   processingBlock:(OperationBlockType)processingBlock
	  successBlock:(OperationBlockType)successBlock
		errorBlock:(OperationErrorBlockType)errorBlock;
			  
{
    self = [super init];
    if (self)
    {
        _canceled = NO;
		_running = NO;
		_error = nil;
		
		self.name = initName;
		self.priority = priority;
		self.processingBlock = processingBlock;
		self.successBlock = successBlock;
		self.errorBlock = errorBlock;
    }
	
    return self;
}

- (id)initWithName:(NSString *)name andPriority:(RLOperationPriority)priority
{
	if ((self = [self initWithName:name 
						  priority:priority
						processingBlock:nil
						   successBlock:nil
							errorBlock:nil]))
	{
	
	}
	
	return self;
}

- (void)run
{
	if (!_canceled)
	{
		_running = YES;
		[self runOperation];
	}
}

//this should be overridden completly in a subclass
- (void)runOperation
{
	if (_processingBlock)
	{
		_processingBlock(self);
	}
}

- (void)cancelOperation
{
	if (!_running)
	{
		_canceled = YES;
	}
}

- (RLOperation *)makeHighPriority
{
    RLOperation *returnOperation = self;
    if (self.priority > RLOperationHigh)
    {
        self.priority = RLOperationHigh;
        [self cancelOperation];
        returnOperation = [self copy];
    }
    
    return returnOperation;
}

- (void)finish
{
	NSAssert( (!_canceled && _running) || (_canceled && !_running), @"didn't cancel correctly");
	
	if (_error)
	{
		if (_errorBlock)
        {
			_errorBlock(self, _error);
		}
	}
	else
	{
		if (_successBlock)
        {
			_successBlock(self);
		}
	}
	
	NSLog(@"completed operation %@", [self description]);
}

- (id)copyWithZone:(NSZone *)zone
{
    RLOperation *copy = [[self class] allocWithZone:zone];
    copy = [copy initWithName:self.name
              priority:self.priority
       processingBlock:self.processingBlock
          successBlock:self.successBlock
            errorBlock:self.errorBlock];
    
    return copy;
}

// This method is not required
- (NSString *)description
{
    return [NSString stringWithFormat:
            @"%@:%i",
            [_name description],
            _priority];
}

@end