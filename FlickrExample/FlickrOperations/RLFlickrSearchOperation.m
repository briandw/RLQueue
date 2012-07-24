//
//  RLFlickrListOperation.m
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
//


#import "RLFlickrSearchOperation.h"
#import "JSONKit.h"
#import "RLPhotoStorage.h"
#import "RLPhotoStub.h"

#include "FlickrKey.h"


@implementation RLFlickrSearchOperation

@synthesize searchText = _searchText;
@synthesize photoStubs = _photoStubs;

- (id)initWithSearchString:(NSString *)searchString andPriority:(RLOperationPriority)priority
{
    self = [super initWithName:@"Flicker Search" andPriority:priority];
    if (self)
    {
        self.searchText = searchString;
        
		NSString *urlString = 
		[NSString stringWithFormat:
		 @"http://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&tags=%@&per_page=25&format=json&nojsoncallback=1", 
		 FlickrAPIKey, self.searchText];
		
		self.url = [NSURL URLWithString:urlString];
		
		self.photoStubs = [NSMutableArray arrayWithCapacity:10];
		
		OperationBlockType processing = ^(RLOperation *operation)
		{
			// Create a dictionary from the JSON string
			NSDictionary *results = [self.data objectFromJSONData];
			
			NSArray *photos = [[results objectForKey:@"photos"] objectForKey:@"photo"];
			
			// Loop through each entry in the dictionary...
			for (NSDictionary *photoDict in photos)
			{
				RLPhotoStub *photoStub = [RLPhotoStub stubWithDictionary:photoDict];
                [[RLPhotoStorage singleton] addPhoto:photoStub];
				[self.photoStubs addObject:photoStub];
				[photoStub loadThumbnail];
			} 
		};
		
		self.processingBlock = processing;
	}
	
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    RLFlickrSearchOperation *copy = [super copyWithZone:zone];
    
    copy.url = self.url;
    
    return copy;
}

@end
