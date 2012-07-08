//
//  RLPhotoStorage.m
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


#import "RLPhotoStorage.h"
#import "RLPhotoStub.h"
#import "RLImageDB.h"

@interface RLPhotoStorage ()
    
    @property (nonatomic, strong)RLImageDB *imageDB;
@end

@implementation RLPhotoStorage

@synthesize imageDB = _imageDB;

NSString *const RLNewPhotosNotification = @"RLNewPhotosNotification";

+ (RLPhotoStorage *)sharedStorage
{
    static dispatch_once_t once;
    static RLPhotoStorage *sharedStorage;
    dispatch_once(&once, ^ { sharedStorage = [[self alloc] init]; });
    return sharedStorage;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _photosDict = [NSMutableDictionary dictionaryWithCapacity:300];
        _imageDB = [[RLImageDB alloc] init];
        [_imageDB open];
    }
    return self;
}

- (RLPhotoStub *)getStubWithId:(NSString *)photoId
{
	return [_photosDict objectForKey:photoId];
}

- (void)addPhoto:(RLPhotoStub *)stub
{
	[_photosDict setObject:stub forKey:stub.photoId];
	
	//
	NSNotification *note = [NSNotification notificationWithName:RLNewPhotosNotification object:self];
	
	[[NSNotificationQueue defaultQueue] enqueueNotification: note
											   postingStyle: NSPostASAP
											   coalesceMask: NSNotificationCoalescingOnName
                                                   forModes: nil];
}

- (NSArray *)photosArray
{
	return [_photosDict allValues];
}

@end
