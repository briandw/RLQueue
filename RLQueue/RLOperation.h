//
//  RLOperation.h
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

#import <Foundation/Foundation.h>

typedef enum
{
	RLOperationHigh = 0,
	RLOperationMedium,
	RLOperationLow,
	RLOperationCount
} RLOperationPriority;

@class RLOperation;

typedef void (^OperationBlockType)(RLOperation *operation);
typedef void (^OperationErrorBlockType)(RLOperation *operation, NSError *error);

@interface RLOperation : NSObject
{
}

@property (nonatomic, strong)OperationBlockType successBlock;
@property (nonatomic, strong)OperationBlockType processingBlock;
@property (nonatomic, strong)OperationErrorBlockType errorBlock;

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSError *error;
@property (nonatomic) RLOperationPriority priority;
@property (readonly) BOOL running;
@property (readonly) BOOL canceled;

- (id)initWithName:(NSString *)name andPriority:(RLOperationPriority)priority;

- (id)initWithName:(NSString *)initName
		  priority:(RLOperationPriority)priority
		processingBlock:(OperationBlockType)processingBlock
		   successBlock:(OperationBlockType)successBlock
			 errorBlock:(OperationErrorBlockType)errorBlock;


//override this to perform the operations work
- (void)runOperation;

//final call to do cleanup etc. Put your final delegate call back here. 
- (void)finish;

//called from the queue. don't override
- (void)run;

- (void)makeHighPriority;

//used to stop an operation before being run
- (void)cancelOperation;

@end

