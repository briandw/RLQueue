
/*
 Saves raw thumbnails of photos into a memorymapped file so
 they can be quickly loaded later.
 
 This is not thread safe.
 It is possible to read on the main thread while writing on a background thread
 if care is taken to stop all background access before closing
 
 This can not be compiled with ARC
 Add the compiler flag -fno-objc-arc to use in an arc project
 */

#import <Foundation/Foundation.h>
#import "UIImageAdditions.h"

#define RLImgDBNotFound 0xFFFF
#define dbMaxImageWidth     386 //pixels
#define dbMaxImageHeight    386 //pixels

@interface RLImageDB : NSObject
{
    int     _openSlots;
    int     _mapFileDescriptor;
    char    *_imageDataMap;
    
    int     _openImageProviders;
    BOOL    _isOpen;
}

@property (readonly)BOOL isFull;

+ (RLImageDB *)singleton;

- (void)open;
- (void)close;
- (void)freeSlot:(UInt16)slot;
- (void)freeAllSlots;
- (UInt16)saveImage:(UIImage *)image forSize:(RLIntSize)imgSize;
- (CGImageRef)cgImageForSlot:(UInt16)slot;
- (void)deleteFileOnDisk;

@end
