//
//  ImageDBFileMetaData.m
//  rawimagetest
//
//  Created by Brian Williams on 6/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RLImageDBFile.h"
#import "RLImageDB.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <libkern/OSAtomic.h>


/*
 ---------------------- WARNING ---------------------- 
 This class is exempted from ARC
 Retain and Release must continue to be used
 remove the compiler flag -fno-objc-arc to use arc, but you must do the conversion first
 */


//this struct holds the metadata for each image slot
typedef struct 
{
    UInt32  slotFilled;
    UInt32  width;
    UInt32  height;
    UInt32  length;
}RLImageHeader;

//this makes cf object autorelease-able
#define RLCFAutorelease(cf) ((__typeof(cf))[NSMakeCollectable(cf) autorelease])

#define dbMaxImageWidth     386 //pixels
#define dbMaxImageHeight    386 //pixels
#define dbMaxImageLength    kOGBytesPerPixel*dbMaxImageWidth*dbMaxImageHeight //bytes
#define dbImagesPerFile     30 //images
#define dbHeaderSize        16 //bytes
#define dbHeaderLength      dbHeaderSize*dbImagesPerFile //bytes

//about 28MBs per file // 29 799 200 Bytes
//the total length of this file on disk
#define dbFileLength        dbHeaderLength + (dbMaxImageLength * dbImagesPerFile) //bytes

@implementation RLImageDBFile

@synthesize fileNumber = _fileNumber;
@synthesize isOpen = _open;
@dynamic isFull;
@dynamic isEmpty;

+ (NSString *)dbDirectoryPath
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

- (id)initWithFileNumber:(NSNumber *)fileNumber
{
    self = [super init];
    if (self)
    {
        _closeAndDelete = NO;
        _closing = NO;
        _open = NO;
        self.fileNumber = fileNumber;
        _openImageProviders = 0;
        _accessCounter = 0;
        _openSlots = dbImagesPerFile;
        _mapFileDescriptor = -1;
        
        RLImgDBLog(@"init imdbfile %p, num%@", self, _fileNumber);
    }
    
    return self;
}

- (void)dealloc
{   
    RLImgDBLog(@"dealloc imdbfile %p, num%@", self, _fileNumber);
    [self close:YES];
    NSAssert(!_closeAndDelete, @"ImageDB is getting dealloced without deleting the file first");
    [_fileNumber release];
    [super dealloc];
}

- (NSString *)dbFilePath
{
    NSString *imageDirectory = [[self class] dbDirectoryPath];
    return [NSString stringWithFormat:@"%@/imgDB%@.dat", imageDirectory, _fileNumber];
}

- (void)openOnMainThread
{
    if (!_open && _fileNumber)
    {        
        RLImgDBLog(@"opening dbfile %p %@", self, self.fileNumber);
        
        NSString *imageDBPath = [self dbFilePath];
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:imageDBPath];
        
        //if there is no file, make one
        _open = YES;
        if (!exists)
        {
            RLImgDBLog(@"creating dbfile %@", self.fileNumber);
            
            NSAssert(sizeof(RLImageHeader) == dbHeaderSize,@"doh math is hard");
            void *zeroData = malloc(dbFileLength);
            memset(zeroData, 0, dbHeaderLength);
            NSData *tmpData = [NSData dataWithBytes:zeroData length:dbFileLength];
            
            NSError *error = nil;
            _open = [tmpData writeToFile:imageDBPath options:(NSDataWritingAtomic |NSDataWritingFileProtectionNone ) error:&error];
        }
        
        if (_open)
        {
            //get the file descriptor
            _mapFileDescriptor = open([imageDBPath cStringUsingEncoding:NSASCIIStringEncoding], O_RDWR);
            
            if(_mapFileDescriptor >=0)
            {
                RLImgDBLog(@"opended file %@ FD=%i", imageDBPath, _mapFileDescriptor);
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
                _open = NO;
            }
        }
    }
    
    if(!_open)
    {
        NSLog(@"Error, can't open imageDB");
    }
}

- (void)open
{
    NSAssert(!_closing, @"Can't open this file while it's closing");
    NSAssert(!_closeAndDelete, @"Opening a file that should be deleted");
    OSAtomicIncrement32(&_accessCounter);
    if (!_open)
    {
        //open and close must happen on the main thread
        if (![NSThread isMainThread])
        {
            [self performSelectorOnMainThread:@selector(openOnMainThread) withObject:nil waitUntilDone:YES];
        }
        else
        {
            [self openOnMainThread];
        }
    }
    OSAtomicDecrement32Barrier(&_accessCounter);
}

- (void)closeOnMainThread:(NSNumber *)forceNum
{
    BOOL force = [forceNum boolValue];
    if ( _open  && (force || (_accessCounter == 0 && _openImageProviders == 0)) )
    {
        RLImgDBLog(@"closing file %i", _mapFileDescriptor);
        
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
        _open = NO;
    
        RLImgDBLog(@"closed dbfile %p %@", self, self.fileNumber);
        //if previously this was marked as to be deleted, kill it
        if (_closeAndDelete)
        {
            [self deleteFileOnDisk];
            _closeAndDelete = NO;
        }
    }
}

- (void)close:(BOOL)force
{
    _closing = YES;
    NSNumber *forceNum = [NSNumber numberWithBool:force];
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(closeOnMainThread:) withObject:forceNum waitUntilDone:YES];
    }
    else
    {
        [self closeOnMainThread:forceNum];
    }
    
    _closing = NO;
}

- (BOOL)isFull
{
    return (_openSlots < 1);
}

- (BOOL)isEmpty
{
    return (_openSlots == dbImagesPerFile);
}

//walk the header until the first open slot if found
- (UInt8)nextOpenSlotInDataMap:(char *)map
{
    UInt8 openSlot = RLImgDBNotFound;
    if (_open)
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

- (UInt8)saveImage:(UIImage *)image forSize:(RLIntSize)imgSize
{    
   OSAtomicIncrement32(&_accessCounter);    
    if (_closing || !_open)
    {
        [self open];
    }
    
    //get the next open slot
    UInt8 openSlot = [self nextOpenSlotInDataMap:_imageDataMap];
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
        RLImgDBLog(@"DB full %@", _fileNumber);
    }
    
    //find the slot offset
    char *imagePos = _imageDataMap+dbHeaderLength+(openSlot*dbMaxImageLength);
    //copy the data into place
    memcpy(imagePos, [data bytes], [data length]);
    
    RLImgDBLog(@"saving image to slot %i in db file %@", openSlot, self.fileNumber);

   OSAtomicDecrement32(&_accessCounter);    
    //return where we put the image
    return openSlot;
}

- (void)providerDone
{
    _openImageProviders--;
    
    if (_openImageProviders == 0 && _closeAndDelete)
    {
        [self deleteFileOnDisk];
    }
    [self release];
}

void RLImageDBReleaseData (void *info, const void *data, size_t size);
void RLImageDBReleaseData (void *info, const void *data, size_t size)
{
	[(RLImageDBFile*)info providerDone];
}

//return an image for this slot.
//this creates an image provider and points it at the mmap file
//we increment the provider count so this wont be shut down prematurly
- (CGImageRef)cgImageForSlot:(UInt8)slot
{
    OSAtomicIncrement32(&_accessCounter);
    
    NSAssert([NSThread isMainThread], @"Calling on background thread, don't");
    if (!_open)
    {
        [self open];
    }

    CGImageRef cgImage = nil;
    
    RLImgDBLog(@"geting image for slot %i in db file %@", slot, self.fileNumber);
    
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
                                            kOGBitsPerComponent,   // bits per component
                                            kOGBitsPerPixel,        //bits per pixel
                                            width*kOGBytesPerPixel, //bytes per row
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
         NSLog(@"!!!! Error:trying to get an image from an empty slot");
    }
   
     
    OSAtomicDecrement32(&_accessCounter);
    return cgImage;
}

- (void)freeSlotOnMainThread:(NSNumber *)slotNumber
{
    OSAtomicIncrement32(&_accessCounter);
    
    if (!_open)
    {
        [self open];
    }
    
    UInt8 slot = [slotNumber unsignedIntValue];
    
    RLImgDBLog(@"freeing slot %i in db file %@", slot, self.fileNumber);
    
    RLImageHeader *header = (RLImageHeader *)_imageDataMap;
    
    if (header[slot].slotFilled == 1)
    {
        header[slot].slotFilled = 0;
        _openSlots++;
        
        NSAssert(_openSlots <= dbImagesPerFile, @"More slots free than possible for this file size");
    }

    OSAtomicDecrement32(&_accessCounter);
}

//mark the image slot as free so it can be reused
- (void)freeSlot:(UInt8)slot
{
    NSNumber *slotnumber = [NSNumber numberWithUnsignedInt:slot];
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(freeSlotOnMainThread:) withObject:slotnumber waitUntilDone:YES];
    }
    else
    {
        [self freeSlotOnMainThread:slotnumber];
    }
}

- (void)freeAllSlots
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(freeAllSlots) withObject:nil waitUntilDone:YES];
    }
    
    if (!_open)
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
    if (_openSlots != dbImagesPerFile)
    {
        RLLog(@"Warning, deleting a non empty imageDB file. Open slots %i", _openSlots);
    }
    
    if (_open)
    {
        [self close:YES];
    }
    
    if (_accessCounter == 0 && !_open)
    {
        NSString *imageDBPath = [self dbFilePath];
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:imageDBPath];

        if (exists)
        {
            RLImgDBLog(@">>>>> Deleting imgdb file %p %@", self, self.fileNumber);
            
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:imageDBPath error:&error];
            if (error)
            {
                NSLog(@"Couldn't delete image db file %@ error:%@", imageDBPath, error);
            }
        }
    }
    else
    {
        _closeAndDelete = YES;
    }
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_fileNumber forKey:@"_fileNumber"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    NSNumber *fileNumber = [decoder decodeObjectForKey:@"_fileNumber"];
    self = [self initWithFileNumber:fileNumber];
    
    return self;
}

@end
