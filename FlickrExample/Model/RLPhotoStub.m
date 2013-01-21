//
//  RLPhotoStub.m
//  RLQueue
//
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


#import "RLPhotoStub.h"
#import "RLPhotoStorage.h"
#import "RLRequestQueue.h"
#import "RLOperation.h"
#import "RLDownloadOperation.h"
#import "RLImageDB.h"

@implementation RLPhotoStub

@synthesize photoURLString = _photoURLString;
@synthesize title = _title;
@synthesize photoId = _photoId;
@synthesize largePhotoId = _largePhotoId;
@synthesize photoSize = _photoSize;
@synthesize thumbnailId = _thumbnailId;
@synthesize thumbnailURLString = _thumbnailURLString;
@synthesize largeImageData = _largeImageData;
@synthesize downloadErrorCount = _downloadErrorCount;
@synthesize thumbnailSize = _thumbnailSize;

+ (RLPhotoStub *)stubWithDictionary:(NSDictionary *)dict
{
	NSString *photoId = [dict objectForKey:@"id"];
	
	RLPhotoStub *stub = [[RLPhotoStorage singleton] getStubWithId:photoId];
	
	if (photoId && !stub)
	{
		stub = [[RLPhotoStub alloc] initWithDictionary:dict];
	}
	
	return stub;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	self = [super init];
    if (self)
    {
		// Get title of the image
		NSString *title = [dict objectForKey:@"title"];
		self.photoId = [dict objectForKey:@"id"];
		
		// Save the title to the photo titles array
		self.title = (title.length > 0 ? title : @"Untitled");
		
		// Build the URL to where the image is stored (see the Flickr API)
		// In the format http://farmX.static.flickr.com/server/id_secret.jpg
		// Notice the "_s" which requests a "small" image 75 x 75 pixels
		self.thumbnailURLString = 
		[NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_s.jpg", 
		 [dict objectForKey:@"farm"], [dict objectForKey:@"server"], 
		 _photoId, [dict objectForKey:@"secret"]];
		
		// Build and save the URL to the large image so we can zoom
		// in on the image if requested
		self.photoURLString = 
		[NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_m.jpg", 
		 [dict objectForKey:@"farm"], [dict objectForKey:@"server"], 
		 _photoId, [dict objectForKey:@"secret"]];
        
        self.thumbnailId = RLImgDBNotFound;
    }
	
    return self;
}

- (CGImageRef)thumbnail 
{
    if (self.thumbnailId != RLImgDBNotFound) {
        
        RLImageDB *imageDB = [RLImageDB singleton];
        return [imageDB cgImageForSlot:self.thumbnailId];
    } else {
        static CGImageRef placeholder;
        
        if(!placeholder) {
            placeholder = [UIImage imageNamed:@"placeholder"].CGImage;
        }
        
        return placeholder;
    }
    
    return NULL;
}

- (void)loadThumbnail
{
	if (self.thumbnailId == RLImgDBNotFound)
    {
		OperationBlockType processingBlock = ^(RLOperation *operation)
		{
			RLDownloadOperation *op = (RLDownloadOperation *)operation;
            RLImageDB *imageDB = [RLImageDB singleton];
            UIImage *image = [UIImage imageWithData:op.data];
            CGSize size = image.size;
            if (size.width > dbMaxImageWidth || size.height > dbMaxImageHeight)
            {
                //scale the image to fit our max
                if (size.width > size.height)
                {
                    size.height = (dbMaxImageWidth/size.width);
                    size.width = dbMaxImageWidth;
                } else
                {
                    size.width = (dbMaxImageHeight/size.height);
                    size.height = dbMaxImageHeight;
                }
            }
            
            self.thumbnailSize = size;
            
            RLIntSize tmpSize = RLIntSizeMake(size.width, size.height);
            self.thumbnailId = [imageDB saveImage:image forSize:tmpSize]; 
		};
		
		OperationBlockType successBlock = ^(RLOperation *operation)
		{
			[[RLPhotoStorage singleton] addPhoto:self];
		};
		
		OperationErrorBlockType errorBlock = ^(RLOperation *operation, NSError *error)
		{
			self.downloadErrorCount = self.downloadErrorCount+1;
		};
		
		RLRequestQueue *queue = [RLRequestQueue singleton];
		RLDownloadOperation *op = [[RLDownloadOperation alloc] initWithURLString:self.thumbnailURLString 
																		priority:RLOperationHigh 
																 processingBlock:processingBlock
																		 successBlock:successBlock
																		   errorBlock:errorBlock];
		[queue addOperation:op];
	}
}

- (void)loadLargeImage
{
    
    OperationBlockType processingBlock = ^(RLOperation *operation)
    {
        RLDownloadOperation *op = (RLDownloadOperation *)operation;
        RLImageDB *imageDB = [RLImageDB singleton];
        UIImage *image = [UIImage imageWithData:op.data];
        CGSize size = image.size;
        if (size.width > dbMaxImageWidth || size.height > dbMaxImageHeight)
        {
            //scale the image to fit our max
            if (size.width > size.height)
            {
                size.height = (dbMaxImageWidth/size.width);
                size.width = dbMaxImageWidth;
            } else
            {
                size.width = (dbMaxImageHeight/size.height);
                size.height = dbMaxImageHeight;
            }
        }
        
        self.thumbnailSize = size;
        
        RLIntSize tmpSize = RLIntSizeMake(size.width, size.height);
        self.thumbnailId = [imageDB saveImage:image forSize:tmpSize];
    };
    
    OperationBlockType successBlock = ^(RLOperation *operation)
    {
        [[RLPhotoStorage singleton] addPhoto:self];
    };
    
    OperationErrorBlockType errorBlock = ^(RLOperation *operation, NSError *error)
    {
        self.downloadErrorCount = self.downloadErrorCount+1;
    };

    
	RLRequestQueue *queue = [RLRequestQueue singleton];
    RLDownloadOperation *op = [[RLDownloadOperation alloc] initWithURLString:self.photoURLString
                                                                    priority:RLOperationHigh
                                                             processingBlock:processingBlock
                                                                successBlock:successBlock
                                                                  errorBlock:errorBlock];
    [queue addOperation:op];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_photoId forKey:@"photoID"];
    [encoder encodeObject:[NSNumber numberWithUnsignedInt:_largePhotoId] forKey:@"largePhotoId"];
    [encoder encodeObject:_title forKey:@"title"];
    [encoder encodeObject:_photoURLString forKey:@"photoURLString"];
    [encoder encodeObject:_thumbnailURLString forKey:@"thumbnailURLString"];
    [encoder encodeObject:[NSNumber numberWithUnsignedInt:_thumbnailId] forKey:@"thumbnailID"];
    [encoder encodeCGSize:_thumbnailSize forKey:@"thumbnailSize"];
    [encoder encodeCGSize:_photoSize forKey:@"photoSize"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super init])
    {
        self.photoId = [decoder decodeObjectForKey:@"photoID"];
        self.title = [decoder decodeObjectForKey:@"title"];
        self.photoURLString = [decoder decodeObjectForKey:@"photoURLString"];
        self.thumbnailURLString = [decoder decodeObjectForKey:@"thumbnailURLString"];
        self.thumbnailId = [[decoder decodeObjectForKey:@"thumbnailID"] intValue];
        self.thumbnailSize = [decoder decodeCGSizeForKey:@"thumbnailSize"];
        self.photoSize = [decoder decodeCGSizeForKey:@"photoSize"];
        
        self.downloadErrorCount = 0;
    }
    
    return self;
}

@end
