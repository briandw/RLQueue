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

#import "RLImageDB.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <libkern/OSAtomic.h>
#include "SynthesizeSingleton.h"


/*
 This can not be compiled with ARC
 Add the compiler flag -fno-objc-arc to use in an arc project
 */


//this struct holds the metadata for each image slot
typedef struct 
{
    UInt32  slotFilled;
    UInt32  width;
    UInt32  height;
    UInt32  length;
}RLImageHeader;

//this makes cf objects autorelease-able
#define RLCFAutorelease(cf) ((__typeof(cf))[NSMakeCollectable(cf) autorelease])

#define dbMaxImageWidth     386 //pixels
#define dbMaxImageHeight    386 //pixels
#define dbMaxImageLength    kRLBytesPerPixel*dbMaxImageWidth*dbMaxImageHeight //bytes
#define dbImagesPerFile     300 //images
#define dbHeaderSize        16 //bytes
#define dbHeaderLength      dbHeaderSize*dbImagesPerFile //bytes

//about 85MBs per file // 297992 * 300 Bytes

//the total length of this file on disk
#define dbFileLength        dbHeaderLength + (dbMaxImageLength * dbImagesPerFile) //bytes


@implementation RLImageDB

@dynamic isFull;

SYNTHESIZE_SINGLETON_FOR_CLASS (RLImageDB)

+ (NSString *)dbCacheDir
{
    static NSString *dbDirPath = nil;
    
    if (!dbDirPath)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if ([paths count] > 0)
        {
            NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
            dbDirPath = [[[paths objectAtIndex:0] stringByAppendingPathComponent:bundleName] retain];
        }
    }
    
    return dbDirPath;
}


- (id)init
{

    self = [super init];
    if (self)
    {
        _openImageProviders = 0;
        _openSlots = dbImagesPerFile;
        _mapFileDescriptor = -1;
        _isOpen = NO;
        [self open];
    }
    
    return self;
}

- (void)dealloc
{   
    [self close];
    [super dealloc];
}


- (void)open
{
    RLAssert ([NSThread isMainThread], @"May only be opened on main thread");
    if (!_isOpen)
    {        
        
        NSString *imageDBPath = [NSString stringWithFormat:@"%@/imgDB.dat", [RLImageDB dbCacheDir]];
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:imageDBPath];
        
        //if there is no file, make one
        _isOpen = YES;
        if (!exists)
        {
            NSError *error = nil;
            
            [[NSFileManager defaultManager] createDirectoryAtPath:[RLImageDB dbCacheDir] withIntermediateDirectories:YES attributes:nil error:&error];
             
            _isOpen = [[NSFileManager defaultManager] createFileAtPath:imageDBPath contents:nil attributes:nil];
            
            NSAssert(sizeof(RLImageHeader) == dbHeaderSize,@"doh math is hard");
            void *zeroData = malloc(dbFileLength);
            memset(zeroData, 0, dbHeaderLength);
            NSData *tmpData = [NSData dataWithBytes:zeroData length:dbFileLength];
            free(zeroData);
            
            _isOpen = [tmpData writeToFile:imageDBPath options:(NSDataWritingFileProtectionNone ) error:&error];
            
            if(!_isOpen)NSLog(@"Error, %@", error);
        }
        
        if (_isOpen)
        {
            //get the file descriptor
            _mapFileDescriptor = open([imageDBPath cStringUsingEncoding:NSASCIIStringEncoding], O_RDWR);
            
            if(_mapFileDescriptor >=0)
            {
                //create the memorymap
                _imageDataMap = mmap( NULL , dbFileLength , PROT_READ | PROT_WRITE, MAP_SHARED, _mapFileDescriptor, 0);
                
                //count the open slots
                RLImageHeader *header = (RLImageHeader *)_imageDataMap;
                _openSlots = 0;
                for (int i=0; i<dbImagesPerFile; i++)
                {
                    if (header[i].slotFilled == 0)
                    {
                        _openSlots++;
                    }
                }
            }
            else
            {
                _isOpen = NO;
            }
        }
    }
    
    if(!_isOpen)
    {
        NSLog(@"Error, can't open imageDB");
    }
}


- (void)close
{
    RLAssert ([NSThread isMainThread], @"May only be closed on main thread");
    
    RLAssert( _isOpen && _openImageProviders == 0, @"Closing in unsafe condition" );
    {
        int success = munmap(_imageDataMap, dbFileLength);
        if (success < 0)
        {
            NSLog(@"error munmap file %i", errno);
        }
        _imageDataMap = nil;
        
        success = close(_mapFileDescriptor);
        if (success < 0)
        {
            NSLog(@"error closing file %i", errno);
        }
        _mapFileDescriptor = -1;
        _isOpen = NO;
    }
}


- (BOOL)isFull
{
    return (_openSlots < 1);
}

//walk the header until the first open slot if found
- (UInt16)nextOpenSlotInDataMap:(char *)map
{
    UInt16 openSlot = RLImgDBNotFound;
    if (_isOpen)
    {
        RLImageHeader *header = (RLImageHeader *)map;
        
        for (int i=0; i<dbImagesPerFile; i++)
        {
            if (header[i].slotFilled == 0)
            {
                openSlot = i;
                break;
            }
        }
        
        if (openSlot == RLImgDBNotFound)
        {
            _openSlots = 0;
        }
    }

    return openSlot;
}

- (UInt16)saveImage:(UIImage *)image forSize:(RLIntSize)imgSize
{    
   
    RLAssert(_isOpen, @"Can't save to a closed file");
    
    //get the next open slot
    UInt16 openSlot = [self nextOpenSlotInDataMap:_imageDataMap];
    RLImageHeader *header = (RLImageHeader *)_imageDataMap;
    NSAssert(openSlot != RLImgDBNotFound && header[openSlot].slotFilled == 0, @"Attempting to save in a full or not found slot");
    
    NSData *data = [image ARGBDataForSize:imgSize];
    int dataLength = [data length];
    NSAssert(dataLength <= dbMaxImageLength, @"Image is too large to save in the DB");
    
    header[openSlot].slotFilled = 1;
    header[openSlot].width = imgSize.width;
    header[openSlot].height = imgSize.height;
    header[openSlot].length = dataLength;
    
    //decrement our available slot count
    _openSlots--;
    
    if(_openSlots < 1)
    {
        NSLog(@"DB full");
    }
    
    //find the slot offset
    char *imagePos = _imageDataMap+dbHeaderLength+(openSlot*dbMaxImageLength);
    //copy the data into place
    memcpy(imagePos, [data bytes], [data length]);
    
    //return where we put the image
    return openSlot;
}

- (void)providerDone
{
    _openImageProviders--;
    
    if (_openImageProviders == 0)
    {
        [self deleteFileOnDisk];
    }
    [self release];
}

void RLImageDBReleaseData (void *info, const void *data, size_t size);
void RLImageDBReleaseData (void *info, const void *data, size_t size)
{
	[(RLImageDB*)info providerDone];
}

//return an image for this slot.
//this creates an image provider and points it at the mmap file
//we increment the provider count so this wont be shut down prematurly
- (CGImageRef)cgImageForSlot:(UInt16)slot
{
    NSAssert([NSThread isMainThread], @"Calling on background thread, don't");
    if (!_isOpen)
    {
        [self open];
    }

    CGImageRef cgImage = nil;
    
    RLImageHeader *header = (RLImageHeader *)_imageDataMap;
    if (header[slot].slotFilled)
    {
        UInt32 length   = header[slot].length;
        UInt32 width    = header[slot].width;
        UInt32 height   = header[slot].height;
        
        void *imageData = _imageDataMap+dbHeaderLength+(slot*dbMaxImageLength);
        
        _openImageProviders++;
        [self retain];//released in providerDone
        
        CGDataProviderRef provider = CGDataProviderCreateWithData(self,
                                                                  imageData,
                                                                  length,
                                                                  RLImageDBReleaseData);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        cgImage = CGImageCreate (width,
                                            height,                              
                                            kRLBitsPerComponent,   // bits per component
                                            kRLBitsPerPixel,        //bits per pixel
                                            width*kRLBytesPerPixel, //bytes per row
                                            colorSpace,
                                            (kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Little),
                                            provider,
                                            NULL,
                                            NO,
                                            kCGRenderingIntentDefault
                                            );
        
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpace);
        
        cgImage = RLCFAutorelease(cgImage);
    }else
    {
         NSLog(@"Error:trying to get an image from an empty slot");
    }
   
    return cgImage;
}

//mark the image slot as free so it can be reused
- (void)freeSlot:(UInt16)slot
{
    
    if (!_isOpen)
    {
        [self open];
    }
    
    RLImageHeader *header = (RLImageHeader *)_imageDataMap;
    
    if (header[slot].slotFilled == 1)
    {
        header[slot].slotFilled = 0;
        _openSlots++;
        
        NSAssert(_openSlots <= dbImagesPerFile, @"More slots free than possible for this file size");
    }

}

- (void)freeAllSlots
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(freeAllSlots) withObject:nil waitUntilDone:YES];
    }
    
    if (!_isOpen)
    {
        [self open];
    }
    
    RLImageHeader *header = (RLImageHeader *)_imageDataMap;
    for (int i=0; i<dbImagesPerFile; i++)
    {
        header[i].slotFilled = 0;
    }
        
    _openSlots = dbImagesPerFile;
}

//we are done with this file, free up the space
- (void)deleteFileOnDisk
{
    
    RLAssert(!_isOpen, @"File must be closed to delete");
    
    NSString *imageDBPath = [NSString stringWithFormat:@"%@/imgDB.dat", [RLImageDB dbCacheDir]];
    
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:imageDBPath];

    if (exists)
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:imageDBPath error:&error];
        if (error)
        {
            NSLog(@"Couldn't delete image db file %@ error:%@", imageDBPath, error);
        }
    }
}


@end
