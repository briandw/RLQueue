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

/*
 This can not be compiled with ARC
 Add the compiler flag -fno-objc-arc to use in an arc project
 */

#import <UIKit/UIKit.h>

typedef struct 
{
    UInt16 width;
    UInt16 height;
}RLIntSize;

extern inline RLIntSize RLIntSizeMake(UInt16 width, UInt16 height);


/*
 http://stackoverflow.com/questions/2428483/optimal-pixel-format-for-drawing-on-iphone
 32 bit BGRA or 16 bit LE565 are the best for quartz
 
 The only pixel formats for 16 and 32 bit like this are:
 
 RGB 16 bpp, 5 bpc, kCGImageAlphaNoneSkipFirst
 
 RGB 32 bpp, 8 bpc, kCGImageAlphaNoneSkipFirst
 
 RGB 32 bpp, 8 bpc, kCGImageAlphaNoneSkipLast
 
 RGB 32 bpp, 8 bpc, kCGImageAlphaPremultipliedFirst
 
 RGB 32 bpp, 8 bpc, kCGImageAlphaPremultipliedLast
 */
//kCGImageAlphaNoneSkipFirst
//-RRRRRGGGGGBBBBB 16 bits per pixel, 5 bits per RGB component.
#define kRLBitsPerComponent 5
#define kRLBytesPerPixel    2
#define kRLBitsPerPixel    16

@interface UIImage (UIImageAdditions) 

+ (UIImage *)imageNamedDontCache:(NSString *)imageName;

- (NSData *)ARGBDataForSize:(RLIntSize)imageSize;
+ (UIImage *)imageFromBGRAData:(NSData *)data ofSize:(RLIntSize)size;
- (UIImage *)toBlackAndWhite;

@end

