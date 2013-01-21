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

#import "UIImageAdditions.h"

@implementation UIImage (UIImageAdditions)

inline RLIntSize
RLIntSizeMake(UInt16 width, UInt16 height)
{
    RLIntSize size; size.width = width; size.height = height; return size;
}

CGContextRef CreateARGBBitmapContext (RLIntSize size);

CGContextRef CreateARGBBitmapContext (RLIntSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;
    
    // Get image width, height. We'll use the entire image.
    UInt16 pixelsWide = size.width;
    UInt16 pixelsHigh = size.height;

    bitmapBytesPerRow   = (pixelsWide * kRLBytesPerPixel);
    
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
    {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
    
       
    // Create the bitmap context. We want pre-multiplied BGRA, 8-bits 
    // per component. Regardless of what the source image format is 
    // (CMYK, Grayscale, and so on) it will be converted over to the format
    // specified here by CGBitmapContextCreate.
    
    //Pass in NULL for the data, CG will allocate the data in iOS 4.0 and later
    context = CGBitmapContextCreate (NULL,
                                     pixelsWide,
                                     pixelsHigh,
                                     kRLBitsPerComponent,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     (kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Little));
    
    // Make sure and release colorspace before returning
    CGColorSpaceRelease( colorSpace );
    
    return context;
}

- (UIImage *)toBlackAndWhite 
{
    // http://stackoverflow.com/a/5276658/28422
    
    const int RED = 1;
    const int GREEN = 2;
    const int BLUE_PIXEL = 3;
    const int ALPHA = 4;
    
    // Create image rectangle with current image width/height
    CGRect imageRect = CGRectMake(0, 0, self.size.width * self.scale, self.size.height * self.scale);
    
    int width = imageRect.size.width;
    int height = imageRect.size.height;
    
    // the pixels will be painted to this array
    uint32_t *pixels = (uint32_t *) malloc(width * height * sizeof(uint32_t));
    
    // clear the pixels so any transparency is preserved
    memset(pixels, 0, width * height * sizeof(uint32_t));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // create a context with RGBA pixels
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * sizeof(uint32_t), colorSpace, 
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);
    
    // paint the bitmap to our context which will fill in the pixels array
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), [self CGImage]);
    
    for(int y = 0; y < height; y++) {
        for(int x = 0; x < width; x++) {
            uint8_t *rgbaPixel = (uint8_t *) &pixels[y * width + x];
            
            // set the pixels to gray
            if (rgbaPixel[ALPHA] > 0)
            {
                rgbaPixel[RED] = 0x00;
                rgbaPixel[GREEN] = 0x00;
                rgbaPixel[BLUE_PIXEL] = 0x00;
            }
        }
    }
    
    // create a new CGImageRef from our context with the modified pixels
    CGImageRef image = CGBitmapContextCreateImage(context);
    
    // we're done with the context, color space, and pixels
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    
    // make a new UIImage to return
    UIImage *resultUIImage = [UIImage imageWithCGImage:image
                                                 scale:self.scale 
                                           orientation:UIImageOrientationUp];
    
    // we're done with image now too
    CGImageRelease(image);
    
    // composite two images
    CGRect arect = CGRectMake(0, 0, self.size.width, self.size.height);
    UIGraphicsBeginImageContext(arect.size);
    CGContextTranslateCTM(context, 0, arect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectOffset(arect, 0.f, -5.f), resultUIImage.CGImage);
    CGContextDrawImage(context, arect, self.CGImage);
    UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return output;
}

+ (UIImage *)imageNamedDontCache:(NSString *)imageName
{
    NSArray *nameComponents = [imageName componentsSeparatedByString:@"."];
    
    if([nameComponents count] == 2){
        NSString *path = [[NSBundle mainBundle] pathForResource:[nameComponents objectAtIndex:0] ofType:[nameComponents objectAtIndex:1]];
        NSData *imageData = [NSData dataWithContentsOfFile:path];
        
        if (imageData){
            
            return [UIImage imageWithData:imageData];
        }
    }
    return nil;
}

void RLProviderReleaseData (void *info, const void *data, size_t size);
void RLProviderReleaseData (void *info, const void *data, size_t size)
{
	free((void *)data);
}

+ (UIImage *)imageFromBGRAData:(NSData *)uncompressedData ofSize:(RLIntSize)imgSize
{
    
    NSUInteger dataBytesLength = [uncompressedData length];
    Byte *byteData = (Byte*)malloc(dataBytesLength);
    memcpy(byteData, [uncompressedData bytes], dataBytesLength);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    NSUInteger numBytes = imgSize.width*imgSize.height*kRLBytesPerPixel;
    
    NSAssert2((dataBytesLength == numBytes), @"wrong number of bytes, expected %iu, found %iu", numBytes, dataBytesLength);
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL,
                                                             byteData,
                                                             numBytes,
                                                             RLProviderReleaseData);
    CGImageRef cgImage = CGImageCreate (imgSize.width,
                                        imgSize.height,                              
                                        kRLBitsPerComponent,   // bits per component
                                        kRLBitsPerPixel,        //bits per pixel
                                        imgSize.width*kRLBytesPerPixel,//bytes per row
                                        colorSpace,
                                        (kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Little),
                                        provider,
                                        NULL,
                                        NO,
                                        kCGRenderingIntentDefault
                              );
    
    
//     CG_EXTERN CGImageRef CGImageCreate(size_t width, size_t height,
//     size_t bitsPerComponent, size_t bitsPerPixel, size_t bytesPerRow,
//     CGColorSpaceRef space, CGBitmapInfo bitmapInfo, CGDataProviderRef provider,
//     const CGFloat decode[], bool shouldInterpolate,
//     CGColorRenderingIntent intent)
     
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGDataProviderRelease(provider);
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    
    return  image;
}

- (NSData *)ARGBDataForSize:(RLIntSize)imageSize
{
	CGContextRef context = CreateARGBBitmapContext(imageSize);
    NSData *dataShort = nil;
    
	if (context != NULL)
    {
        UInt16 w = imageSize.width;
        UInt16 h = imageSize.height;
        CGRect rect = {{0,0},{w,h}};
        CGContextDrawImage(context, rect, self.CGImage);
        
        void *data = CGBitmapContextGetData(context);
        
        if (data)
        {
            dataShort = [NSData dataWithBytes:data length:kRLBytesPerPixel*w*h];
            free(data);
            data = NULL;
        }
    }
    
    CGContextRelease(context);
	    
	return dataShort;
}

@end
