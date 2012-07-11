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

@implementation RLThumbnailViewController

@synthesize photos = _photos;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
	{

    }
    return self;
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

- (void)newPhotos:(NSNotification *)note
{
	self.photos = [[RLPhotoStorage singleton] photosArray];
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
		return [self.photos count]/4;
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
        
        CALayer *cellLayer = cell.layer;
       //  NSArray *layers = cell.layer.sublayers;
        
        for (int i = 0; i < 4; i += 1) {
            
            CALayer *layer = [CALayer layer];
            [cellLayer addSublayer:layer];
        }
    }
    
    int row = indexPath.row;
    NSArray *layers = cell.layer.sublayers;
    
    NSAssert([layers count] >= 4, @"Expecting 4 sublayers");
    
    for (int i = 0; i < 4; i +=1) { 
        
        CALayer *layer = [layers objectAtIndex:i+1];
        layer.anchorPoint = CGPointMake(0, 0);
        layer.frame = CGRectMake(i*80.0, 0, 75.0, 75.0);
        
        int index = row*4+i;
        if (index < [_photos count]) {
            
            RLPhotoStub *stub = [_photos objectAtIndex:index];
            
            layer.contentsGravity = kCAGravityCenter;
            layer.contents = (id)stub.thumbnail;
        }
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
    return stub.thumbnailSize.height+6.0;
}

@end
