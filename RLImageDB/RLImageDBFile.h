//
//  ImageDBFileMetaData.h
//  rawimagetest
//
//  Created by Brian Williams on 6/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

/*
 //each db file references a file on disk that contains a header and raw image data
 //the file is mmaped to make supplying images with data as fast as possible
 //ImageDBFiles are persisted with the single value of their file number
 //everything else can be generated
 //
  these objects are thread safe in that they can be read from on anythread
    while they are beeing written to from a different thread. The same area of memory is not writeable from different threads at the same time
 
    files will not close if being accessed.
    
    atomic operators are used the track access in a thread safe manor
    
 */



/*
 ---------------------- WARNING ---------------------- 
 This class is exempted from ARC
 Retain and Release must continue to be used
 remove the compiler flag -fno-objc-arc to use arc, but you must do the conversion first
 */

#import <Foundation/Foundation.h>
#import "UIImageAdditions.h"

@interface RLImageDBFile : NSObject <NSCoding>
{
    NSNumber *_fileNumber;
    int    _openSlots;
    BOOL   _open;
    BOOL   _closeAndDelete;
    
    int _mapFileDescriptor;
    char *_imageDataMap;
    
    volatile int32_t	_accessCounter;
    volatile boolean_t  _closing;
    int _openImageProviders;
}

@property (readonly)BOOL isOpen;
@property (readonly)BOOL isFull;
@property (readonly)BOOL isEmpty;
@property (nonatomic, retain)NSNumber *fileNumber;

- (id)initWithFileNumber:(NSNumber *)fileNumber;

- (void)open;
- (void)close:(BOOL)force;
- (void)freeSlot:(UInt8)slot;
- (void)freeAllSlots;
- (UInt8)saveImage:(UIImage *)image forSize:(RLIntSize)imgSize;
- (CGImageRef)cgImageForSlot:(UInt8)slot;
- (void)deleteFileOnDisk;

@end
