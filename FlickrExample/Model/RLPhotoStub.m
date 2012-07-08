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
@synthesize thumbnailId = _thumbnailId;
@synthesize thumbnailURLString = _thumbnailURLString;
@synthesize largeImageData = _largeImageData;
@synthesize downloadErrorCount = _downloadErrorCount;

+ (RLPhotoStub *)stubWithDictionary:(NSDictionary *)dict
{
	NSString *photoId = [dict objectForKey:@"photoId"];
	
	RLPhotoStub *stub = [[RLPhotoStorage sharedStorage] getStubWithId:photoId];
	
	if (!stub)
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
                
                if (size.width > size.height)
                {
                    
                } else
                {
                    
                }
            }
            RLIntSize tmpSize = RLIntSizeMake(size.width, size.height);
            self.thumbnailId = [imageDB saveImage:image forSize:tmpSize]; 
		};
		
		OperationBlockType successBlock = ^(RLOperation *operation)
		{
			[[RLPhotoStorage sharedStorage] addPhoto:self];
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
	
}


@end
