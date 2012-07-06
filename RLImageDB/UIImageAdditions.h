
/*
 ---------------------- WARNING ---------------------- 
 This class is exempted from ARC
 Retain and Release must continue to be used
 remove the compiler flag -fno-objc-arc to use arc, but you must do the conversion first
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
#define kOGBitsPerComponent 5
#define kOGBytesPerPixel    2
#define kOGBitsPerPixel    16

@interface UIImage (UIImageAdditions) 

+ (UIImage *)imageNamedDontCache:(NSString *)imageName;

- (NSData *)ARGBDataForSize:(RLIntSize)imageSize;
+ (UIImage *)imageFromBGRAData:(NSData *)data ofSize:(RLIntSize)size;
- (UIImage *)toBlackAndWhite;

@end

