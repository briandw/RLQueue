//
//  RLDownloadOperation.m
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


#import "RLDownloadOperation.h"

@implementation RLDownloadOperation
@synthesize url = _url;
@synthesize data = _data;

- (id)initWithURLString:(NSString *)urlString
			   priority:(RLOperationPriority)priority
		processingBlock:(OperationBlockType)processingBlock
		   successBlock:(OperationBlockType)successBlock
			 errorBlock:(OperationErrorBlockType)errorBlock;
				   
{
	if ((self = [super initWithName:@"Download Operation" 
						   priority:priority 
						 processingBlock:processingBlock
							successBlock:successBlock
							  errorBlock:errorBlock]))
	{
		self.url = [NSURL URLWithString:urlString];
	}
	
	return self;
}

- (void)runOperation
{	
	NSURLResponse *response;
	NSError *error;
	
	NSURLRequest *request = [NSURLRequest requestWithURL:_url];
	self.data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	if (!error)
	{
		if (self.processingBlock)
        {
			self.processingBlock(self);
		}
	}
	else
	{
		self.error = error;
	}
}

@end
