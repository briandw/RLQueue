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
#include "SynthesizeSingleton.h"

@interface RLPhotoStorage ()
    
    @property (nonatomic, strong)RLImageDB *imageDB;
@end

@implementation RLPhotoStorage

@synthesize imageDB = _imageDB;

NSString *const RLNewPhotosNotification = @"RLNewPhotosNotification";
NSString *const RLPhotoDataKey = @"RLPhotoDataKey";

SYNTHESIZE_SINGLETON_FOR_CLASS (RLPhotoStorage);

+ (NSString *)storageFile
{
    static NSString *storagePath = nil;
    
    if (!storagePath)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if ([paths count] > 0)
        {
            NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
            storagePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:bundleName];
        }
    }
    
    return [NSString stringWithFormat:@"%@/metaStore.data", storagePath];
}


- (id)init
{
    self = [super init];
    if (self)
    {
        [self load];
        _imageDB = [RLImageDB singleton];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(save) name:RLNewPhotosNotification object:nil];
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
	
	//used to notify the thumbnail view that new photos are ready to display
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

- (void)save
{
    
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver encodeObject:_photosDict forKey:RLPhotoDataKey];
    [archiver finishEncoding];
    [data writeToFile:[RLPhotoStorage storageFile] atomically:YES];
}

- (void)load
{
    NSString *storagePath = [RLPhotoStorage storageFile];
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:storagePath];
    
    if (exists) {
        
        NSData *data = [[NSMutableData alloc]initWithContentsOfFile:storagePath];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        _photosDict = [unarchiver decodeObjectForKey:RLPhotoDataKey];
        [unarchiver finishDecoding];

    } else {
        
         _photosDict = [NSMutableDictionary dictionaryWithCapacity:300];
    }
}

@end
