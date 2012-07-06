//
//  ImageDB.m
//  rawimagetest
//
//  Created by Brian Williams on 5/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

/*
 ---------------------- WARNING ---------------------- 
 This class is exempted from ARC
 Retain and Release must continue to be used
 remove the compiler flag -fno-objc-arc to use arc, but you must do the conversion first
 */

#import "RLImageDB.h"
#import "RLImageDBFile.h"
#import "SynthesizeSingleton.h"

#define kOGDBMetaDataKey @"kOGDBMetaDataKey"

@interface RLImageDB ()

- (RLImageDBFile *)addNewDB;

@end

@implementation RLImageDB

SYNTHESIZE_SINGLETON_FOR_CLASS(RLImageDB)

//delete all the files that imagedb knows of and remove the metadata about them
- (void)clearFilesFromDisk
{
    for (RLImageDBFile *dbFile in [_imageDBObjects allValues])
    {
        [dbFile deleteFileOnDisk];
    }
    
    [_imageDBObjects release];
    _imageDBObjects = nil;
    
    [_openDBFile release];
    _openDBFile = nil;

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOGDBMetaDataKey];
    _isOpen = NO;
    
    RLImgDBLog(@"closing the imagedb %@", @"");
}

- (void)openOnMainThread
{
    if (!_isOpen)
    {
        //find the stored imagedbfiles in user prefs
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:kOGDBMetaDataKey];
        if (data)
        {
            _imageDBObjects = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
            RLImgDBLog(@"init imageDB, loading %i db files", [_imageDBObjects count]);
        }else
        {
            _imageDBObjects = nil;
            RLImgDBLog(@"init imageDB %@", @"");
        }
        
        //open all the files to get the correct slot count
        //catch any straglers that didn't get deleted
        NSMutableArray *deletedKeys = [NSMutableArray arrayWithCapacity:2];
        for (NSNumber *key in [_imageDBObjects allKeys])
        {
            RLImageDBFile *file = [_imageDBObjects objectForKey:key];
            [file open];
            if (file.isEmpty)
            {
                [deletedKeys addObject:key];
            }
            [file close:NO];
        }
        
        //don't delete all the files, leave one
        if ([deletedKeys count] > 0 && [deletedKeys count] == [_imageDBObjects count])
        {
            [deletedKeys removeLastObject];
        }
        for (NSNumber *key in deletedKeys)
        {
            RLImageDBFile *file = [_imageDBObjects objectForKey:key];
            [file deleteFileOnDisk];
            [_imageDBObjects removeObjectForKey:key];
        }
        
        //if we dont have dictionary to put the dbfiles in make one
        if (!_imageDBObjects)
        {
            _imageDBObjects = [[NSMutableDictionary alloc] initWithCapacity:5];
            [self addNewDB];
        }
        
        [self save];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        _isOpen = YES;
    }
}

- (void)open
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(openOnMainThread) withObject:nil waitUntilDone:YES];
    }
    else
    {
        [self openOnMainThread];
    }
}

- (void)closeOnMainThread
{
    if (_isOpen)
    {
        [self save];
        for (RLImageDBFile *dbFile in _imageDBObjects)
        {
            [dbFile close:YES];
        }
        [_imageDBObjects release];
        _imageDBObjects = nil;
        
        [_openDBFile release];
        _openDBFile = nil;
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        _isOpen = NO;
        RLImgDBLog(@"closing the imagedb %@", @"");
    }
}

- (void)close
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(closeOnMainThread) withObject:nil waitUntilDone:YES];
    }
    else
    {
        [self closeOnMainThread];
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _isOpen = NO;
        [self open];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_imageDBObjects release];
    [_openDBFile release];
    
    [super dealloc];
}

- (void)save
{
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:_imageDBObjects];
    [[NSUserDefaults standardUserDefaults] setObject:archive forKey:kOGDBMetaDataKey];
}

//create a new dbfile
- (RLImageDBFile *)addNewDB
{
    int maxFileNumber = 0;
    for (RLImageDBFile *file in [_imageDBObjects allValues])
    {
        int fileNumber = [file.fileNumber unsignedIntValue];
        if (fileNumber > maxFileNumber)
        {
            maxFileNumber = fileNumber;
        }
    }
    
    maxFileNumber++;
    
    if (maxFileNumber >= UINT16_MAX)
    {
        maxFileNumber = 0;
    }
    
    RLImgDBLog(@"addNewDB with file number %i", maxFileNumber);
    NSNumber *fileKey = [NSNumber numberWithUnsignedInt:maxFileNumber];

    RLImageDBFile *newFile = [[RLImageDBFile alloc] initWithFileNumber:fileKey];
    
    //remove any old data if still on disk
    [newFile deleteFileOnDisk];
    [newFile open];
    [_imageDBObjects setObject:newFile forKey:fileKey];
    [newFile release];
    
    //save the meta data
    [self save];

    NSAssert(newFile, @"nil db file");
    return newFile;
}

- (void)findOpenDBFile
{
    if (!_openDBFile || _openDBFile.isFull)
    {
        RLImgDBLog(@"Need a new db file, openDBFile is %@", (!_openDBFile)?@"nil":@"full");
        [_openDBFile release];
        _openDBFile = nil;
        
        //first check for an open db with space
        for (RLImageDBFile *db in [_imageDBObjects allValues])
        {
            if (db.isOpen && !db.isFull)
            {
                RLImgDBLog(@"Found an open one with space %@", @"");
                _openDBFile = [db retain];
                break;
            }
        }
        
        //next open the dbs and get the first one with space
        if (!_openDBFile)
        {
            for (RLImageDBFile *db in [_imageDBObjects allValues])
            {
                if (!db.isOpen)
                {
                    [db open];
                    if (!db.isFull)
                    {
                        RLImgDBLog(@"Opened a db file and it's not full%@", @"");
                        _openDBFile = [db retain];
                        break;
                    }else
                    {
                        [db close:NO];
                    }
                }
            }
        }
        
        [_openDBFile open];
        
        //create a new file if no db is available
        if (!_openDBFile || _openDBFile.isFull)
        {
            RLImgDBLog(@"No DB file available, creating a new one%@", @"");
            [_openDBFile release];
            _openDBFile = [[self addNewDB] retain];
            [_openDBFile open];
        }
    }
}

//return the last dbfile used if its not full, if full make a new one
- (RLImageDBFile *)openDBFile
{
    if ([NSThread isMainThread])
    {
        [self findOpenDBFile];
    }
    else
    {
        [self performSelectorOnMainThread:@selector(findOpenDBFile) withObject:nil waitUntilDone:YES];
    }
    
    NSAssert(_openDBFile && !_openDBFile.isFull, @"No db or it's full");
    
    return _openDBFile;
}

- (UInt32)slotForDB:(UInt16)dbNumber andImage:(UInt8)imageNumber
{
    UInt32 imageSlot = dbNumber << 16;
    imageSlot = imageSlot | imageNumber;
    return imageSlot;
}

- (UInt8)imageNumberForSlot:(UInt32)slot
{
    return slot & 0x0000FFFF;
}

- (UInt16)dbNumberForSlot:(UInt32)slot
{
    return slot >> 16;
}

//add a image to db and return the id created
- (UInt32)saveImage:(UIImage *)image forSize:(RLIntSize)size
{
    if (!_isOpen)
    {
        [self open];
    }
    
    RLImageDBFile *db = [self openDBFile];
    NSAssert(db,@"nil db");
    UInt16 dbNumber = [db.fileNumber unsignedIntValue];
    UInt8 imageId = [db saveImage:image forSize:size];
    NSAssert(imageId != RLImgDBNotFound, @"Can't save image");
       
    RLImgDBLog(@"saved imageid:%i db:%i",imageId ,dbNumber);
    
    return [self slotForDB:dbNumber andImage:imageId];
}

//return the image for the given slot id
- (CGImageRef)cgImageForSlot:(UInt32)slot
{
	CGImageRef imageToReturn = nil;
    if (!_isOpen)
    {
        [self open];
    }
    
    UInt16 dbInt = [self dbNumberForSlot:slot];
    NSNumber *dbNumber = [NSNumber numberWithUnsignedInt:dbInt];
    RLImageDBFile *dbFile = [_imageDBObjects objectForKey:dbNumber];
    
    if (dbFile)
    {
        imageToReturn = [dbFile cgImageForSlot:[self imageNumberForSlot:slot]];
    }
	#ifdef DEBUG
	else
	{
		//Debugger;
		NSLog(@"!!!!! Error: No file for the image");
	}
	#endif
    
    return imageToReturn;
}

- (UIImage *)imageForSlot:(UInt32)slot
{
    return [UIImage imageWithCGImage:[self cgImageForSlot:slot]];
}

//free up the image in the dbfiles header info
- (void)freeSlot:(UInt32)slot
{
    if (!_isOpen)
    {
        [self open];
    }
    
    NSNumber *dbNumber = [NSNumber numberWithUnsignedInt:[self dbNumberForSlot:slot]];
    RLImageDBFile *dbFile = [_imageDBObjects objectForKey:dbNumber];
    
    RLAssert(dbFile, @"Error! No file for the image");
    if (dbFile)
    {
        UInt16 imageId = [self imageNumberForSlot:slot];
        
        RLImgDBLog(@"freeing imageid %i db %@", imageId, dbNumber);
        
        [dbFile freeSlot:imageId];
        
        if ([dbFile isEmpty])
        {
            RLImgDBLog(@">>>>> deleting img DB %@", dbNumber);
            [dbFile close:NO];
            if (!dbFile.isOpen)
            {
                if (_openDBFile == dbFile)
                {
                    [_openDBFile release];
                    _openDBFile = nil;
                }
                [dbFile deleteFileOnDisk];
                [_imageDBObjects removeObjectForKey:dbNumber];
            }
            [self save];
        }
    }
}

//close all the dbfiles that can be closed
- (void)receiveMemoryWarning
{
    RLImgDBLog(@"img db mem warning %@", @"");    
    for (RLImageDBFile *dbFile in [_imageDBObjects allValues])
    {
        [dbFile close:NO];
    }
}

@end
