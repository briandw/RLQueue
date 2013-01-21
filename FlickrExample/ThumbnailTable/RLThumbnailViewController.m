//
//  RLThumbnailViewController.m
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


#import "RLThumbnailViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "RLPhotoStorage.h"
#import "RLPhotoStub.h"

#define PADDING 9.0

@implementation RLThumbnailViewController

@synthesize photos = _photos;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
	{
        _thumbnailSize = 70;
        _imagesPerRow = [self thumbnailsPerRow];
        [self calculateMarginWidth];
    }
    return self;
}

- (NSInteger) thumbnailsPerRow {
    
    return (NSInteger)roundf(self.view.bounds.size.width/(_thumbnailSize+PADDING));
}

- (void) calculateMarginWidth {
    _marginWidth = roundf((self.view.bounds.size.width - (_imagesPerRow*(_thumbnailSize+PADDING)-PADDING)) /2);
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newPhotos:) name:RLNewPhotosNotification object:nil];
	self.photos = [[RLPhotoStorage singleton] photosArray];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    int thumbsPerRow = [self thumbnailsPerRow];
    if (thumbsPerRow != _imagesPerRow){
        _imagesPerRow = thumbsPerRow;
        [self calculateMarginWidth];
        [self.tableView reloadData];
    }
}

- (void)newPhotos:(NSNotification *)note
{
	self.photos = [[RLPhotoStorage singleton] photosArray];
    if ([_photos count] > 0) {
        RLPhotoStub *stub = [_photos objectAtIndex:0];
        _thumbnailSize = stub.thumbnailSize.width;
    }
    
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
	{
		return [self.photos count]/_imagesPerRow;
	}
	else
	{
		return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"RLCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSArray *sublayers = cell.layer.sublayers;
    
    int deltaLayers = _imagesPerRow - ([sublayers count] - 1);
    
    if (deltaLayers > 0) {
        for (int i = 0; i < deltaLayers; i += 1) {
            
            CALayer *layer = [CALayer layer];
            layer.contentsGravity = kCAGravityCenter;
            layer.masksToBounds = YES;
            [cell.layer addSublayer:layer];
        }
    } else if (deltaLayers < 0){
        
        for (int i = [sublayers count]-1; i >= _imagesPerRow+1; i -= 1) {
            
            CALayer *layer = [sublayers objectAtIndex:i];
            layer.opacity = 0.0;
            layer.contents = nil;
            //why you crash here?
            //[layer removeFromSuperlayer];
        }
    }
    
    
    int row = indexPath.row;
    
    NSAssert([sublayers count] >= _imagesPerRow+1, @"Expecting %i sublayers", _imagesPerRow);
    
    for (int i = 0; i < _imagesPerRow; i += 1) {
        
        NSAssert( i+1 < [sublayers count], @"Can't find layer %i", i);
        
        CALayer *layer = [sublayers objectAtIndex:i+1];
        layer.opacity = 1.0;
        //NSLog(@" laying out layer %p", layer);
        layer.anchorPoint = CGPointMake(0, 0);
        layer.frame = CGRectMake(_marginWidth+i*(_thumbnailSize+PADDING), 0, _thumbnailSize, _thumbnailSize);
        
        int index = row*_imagesPerRow+i;
        NSAssert(index < [_photos count], @" Photo Index out of bounds: %i",index);
            
        RLPhotoStub *stub = [_photos objectAtIndex:index];
        
        layer.contents = (id)stub.thumbnail;
        
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{

}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RLPhotoStub *stub = [_photos objectAtIndex:indexPath.row];
    return stub.thumbnailSize.height+_marginWidth;
}

@end
