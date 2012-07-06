//
//  ImageDB.h
//  rawimagetest
//
//  Created by Brian Williams on 5/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

/*
 //ImageDB manages a list of ImageDBFiles. It finds a place for new images coming in
 // and the image that belongs to an image id requested from the outside.
 // New DB files are created and destroied as needed, and deleted on cleanup.
 //
*/


/*
 ---------------------- WARNING ---------------------- 
 This class is exempted from ARC
 Retain and Release must continue to be used
 remove the compiler flag -fno-objc-arc to use arc, but you must do the conversion first
 */

#import <Foundation/Foundation.h>
#import "UIImageAdditions.h"

//this is our 2 byte not found flag
#define RLImgDBNotFound 0xFF

#define RLImgDBLogOn 0

#if defined (DEBUG) && RLImgDBLogOn && !defined (RLImgDBLog)
//#define RLImgDBLog(fmt, ...) NSLog(fmt, __VA_ARGS__)
    #define RLImgDBLog(fmt, ...)
#else
    #define RLImgDBLog(fmt, ...)
#endif

@class RLImageDBFile;

@interface RLImageDB : NSObject
{    
    NSMutableDictionary *_imageDBObjects;
    RLImageDBFile *_openDBFile;
    BOOL _isOpen;
}

+ (RLImageDB *)singleton;

- (void)open;
- (void)close;

- (void)clearFilesFromDisk;
- (void)save;
- (UInt32)saveImage:(UIImage *)image forSize:(RLIntSize)size;
- (CGImageRef)cgImageForSlot:(UInt32)slot;
- (UIImage *)imageForSlot:(UInt32)slot;
- (void)freeSlot:(UInt32)slot;


@end
