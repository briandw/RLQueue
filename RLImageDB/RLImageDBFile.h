
/*
 This can not be compiled with ARC
 Add the compiler flag -fno-objc-arc to use in an arc project
 */

#import <Foundation/Foundation.h>
#import "UIImageAdditions.h"

#define RLImgDBNotFound 0xFF

@interface RLImageDBFile : NSObject
{
    int     _openSlots;
    int     _mapFileDescriptor;
    char    *_imageDataMap;
    
    volatile int32_t    _accessCounter;
    volatile boolean_t  _closing;
    int                 _openImageProviders;
}

@property (readonly)BOOL isFull;

- (void)open;
- (void)close;
- (void)freeSlot:(UInt8)slot;
- (void)freeAllSlots;
- (UInt8)saveImage:(UIImage *)image forSize:(RLIntSize)imgSize;
- (CGImageRef)cgImageForSlot:(UInt8)slot;
- (void)deleteFileOnDisk;

@end
