
/*
 ---------------------- WARNING ---------------------- 
 This class is exempted from ARC
 Retain and Release must continue to be used
 remove the compiler flag -fno-objc-arc to use arc, but you must do the conversion first
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
    void *          bitmapData;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    // Get image width, height. We'll use the entire image.
    UInt16 pixelsWide = size.width;
    UInt16 pixelsHigh = size.height;

    bitmapBytesPerRow   = (pixelsWide * kOGBytesPerPixel);
    bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);
    
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
    {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
    
    // Allocate memory for image data. This is the destination in memory
    // where any drawing to the bitmap context will be rendered.
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) 
    {
        fprintf (stderr, "Memory not allocated!");
        CGColorSpaceRelease( colorSpace );
        return NULL;
    }
    
    // Create the bitmap context. We want pre-multiplied BGRA, 8-bits 
    // per component. Regardless of what the source image format is 
    // (CMYK, Grayscale, and so on) it will be converted over to the format
    // specified here by CGBitmapContextCreate.
    context = CGBitmapContextCreate (bitmapData,
                                     pixelsWide,
                                     pixelsHigh,
                                     kOGBitsPerComponent,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     (kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Little));
    if (context == NULL)
    {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
    }
    
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
    
    NSUInteger numBytes = imgSize.width*imgSize.height*kOGBytesPerPixel;
    
    NSAssert2((dataBytesLength == numBytes), @"wrong number of bytes, expected %iu, found %iu", numBytes, dataBytesLength);
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL,
                                                             byteData,
                                                             numBytes,
                                                             RLProviderReleaseData);
    CGImageRef cgImage = CGImageCreate (imgSize.width,
                                        imgSize.height,                              
                                        kOGBitsPerComponent,   // bits per component
                                        kOGBitsPerPixel,        //bits per pixel
                                        imgSize.width*kOGBytesPerPixel,//bytes per row
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
            dataShort = [NSData dataWithBytes:data length:kOGBytesPerPixel*w*h];
            free(data);
            data = NULL;
        }
    }
    
    CGContextRelease(context);
	    
	return dataShort;
}

@end
