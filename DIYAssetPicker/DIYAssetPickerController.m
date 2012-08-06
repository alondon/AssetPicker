//
//  DIYAssetPickerController.m
//  DIYAssetPicker
//
//  Created by Jonathan Beilin on 7/30/12.
//  Copyright (c) 2012 Jonathan Beilin. All rights reserved.
//

#import "DIYAssetPickerController.h"

@interface DIYAssetPickerController ()
@property (nonatomic, retain) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, retain) NSMutableArray *allAssets;
@property (nonatomic, retain) UITableView *assetsTable;
@property (nonatomic, retain) UINavigationBar *header;
@end

@implementation DIYAssetPickerController

@synthesize assetsLibrary = _assetsLibrary;
@synthesize allAssets = _allAssets;
@synthesize assetsTable = _assetsTable;
@synthesize header = _header;

@synthesize delegate = _delegate;
@synthesize numberColumns = _numberColumns;
@synthesize assetType = _assetType;
@synthesize validOrientation = _validOrientation;

#pragma mark - Init

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup
    [self setTitle:@"Asset Picker"];
    
    // Asset library & array
    self.assetsLibrary = [[[ALAssetsLibrary alloc] init] autorelease];
    
    self.allAssets = [[NSMutableArray alloc] init];
    [self getAssetsArray];
    
    // Header
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPicking)];
    
    _header = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    self.header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.header.barStyle = UIBarStyleBlack;
    self.header.translucent = true;
    [self.header setItems:@[ self.navigationItem ]];
    [self.view addSubview:self.header];
    
    // Asset Table
    _assetsTable = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    [self.assetsTable setContentInset:UIEdgeInsetsMake(self.header.frame.size.height, 0, 0, 0)];
    [self.assetsTable setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    [self.assetsTable setDelegate:self];
    [self.assetsTable setDataSource:self];
    [self.assetsTable setSeparatorColor:[UIColor clearColor]];
    [self.assetsTable setAllowsSelection:NO];
    [self.assetsTable reloadData];
    [self.view addSubview:self.assetsTable];
    
    [self.view bringSubviewToFront:self.header];
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return true;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.assetsTable performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:true];
}

#pragma mark - UI

- (void)cancelPicking
{
    [self.delegate pickerDidCancel:self];
}

#pragma mark - UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(!self.allAssets) {
        return 0;
    }
    return ceil([self.allAssets count]/((float)THUMB_COUNT_PER_ROW));
}

// Borrowed from PhotoPickerPlus

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"PickerCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    [cell.textLabel setText:@" "];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        UIView *v = [self tableView:tableView viewForIndexPath:indexPath];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if(v){
                for(UIView *view in cell.contentView.subviews){
                    [view removeFromSuperview];
                }
                [cell.contentView addSubview:v];
            }
            else{
                [cell setAccessoryType:UITableViewCellAccessoryNone];
                [cell setEditingAccessoryType:UITableViewCellAccessoryNone];
            }
        });
    });
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return THUMB_SPACING + THUMB_SIZE;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

// Borrowed heavily from PhotoPickerPlus

- (UIView *)tableView:(UITableView *)tableView viewForIndexPath:(NSIndexPath *)indexPath
{
int initialThumbOffset = ((int)self.assetsTable.frame.size.width+THUMB_SPACING-(THUMB_COUNT_PER_ROW*(THUMB_SIZE+THUMB_SPACING)))/2;
    
    UIView *view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.assetsTable.frame.size.width, [self tableView:self.assetsTable heightForRowAtIndexPath:indexPath])] autorelease];
    int index = indexPath.row * (THUMB_COUNT_PER_ROW);
    int maxIndex = index + ((THUMB_COUNT_PER_ROW)-1);
    CGRect rect = CGRectMake(initialThumbOffset, THUMB_SPACING/2, THUMB_SIZE, THUMB_SIZE);
    int x = THUMB_COUNT_PER_ROW;
    if (maxIndex >= [self.allAssets count]) {
        x = x - (maxIndex - [self.allAssets count]) - 1;
    }
    
    for (int i = 0; i < x; i++) {
        ALAsset *asset = [self.allAssets objectAtIndex:index+i];
        UIImageView *image = [[[UIImageView alloc] initWithFrame:rect] autorelease];
        [image setTag:index+i];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(getAssetFromGesture:)];
        [image addGestureRecognizer:tap];
        [tap release];
        [image setUserInteractionEnabled:YES];
        [image setImage:[UIImage imageWithCGImage:[asset thumbnail]]];
        [view addSubview:image];
        
        // Add video info view on video assets
        if ([[asset valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo]) {
            UIView *videoBar = [[[UIView alloc] initWithFrame:CGRectMake(0, THUMB_SIZE - 18, THUMB_SIZE, 18)] autorelease];
            videoBar.backgroundColor = [UIColor blackColor];
            videoBar.alpha = 0.75f;
            [view addSubview:videoBar];
            
            UIImageView *videoIcon = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ui_icon_tinyvideo@2x.png"]] autorelease];
            videoIcon.frame = CGRectMake(6, THUMB_SIZE - 13, videoIcon.frame.size.width/2.0f, videoIcon.frame.size.height/2.0f);
            [view addSubview:videoIcon];
            
            NSTimeInterval duration = [[asset valueForProperty:ALAssetPropertyDuration] doubleValue];
            int minutes = duration/60;
            int seconds = duration - (minutes * 60);
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                dispatch_sync(dispatch_get_main_queue(), ^{
                    UILabel *lengthLabel = [[[UILabel alloc] initWithFrame:CGRectMake(THUMB_SIZE/2.0f, THUMB_SIZE - 14, (THUMB_SIZE/2.0f) - 6, 12)] autorelease];
                    lengthLabel.text = [NSString stringWithFormat:@"%i:%02i", minutes, seconds];
                    lengthLabel.textAlignment = UITextAlignmentRight;
                    lengthLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:11.0f];
                    lengthLabel.textColor = [UIColor whiteColor];
                    lengthLabel.backgroundColor = [UIColor clearColor];
                    [view addSubview:lengthLabel];
                });
            });
        }

        rect = CGRectMake((rect.origin.x+THUMB_SIZE+THUMB_SPACING), rect.origin.y, rect.size.width, rect.size.height);
    }
    return view;
}

#pragma mark - Utility

- (void)getAssetsArray {
    [self.assetsLibrary
         enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
         usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
             [group setAssetsFilter:[ALAssetsFilter allAssets]];
             [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                 if (result != nil) {
                     [self.allAssets addObject:result];
                 }
                 else {
                     [self.assetsTable reloadData];
                     if ([self.delegate respondsToSelector:@selector(pickerDidFinishLoading)]) {
                         [self.delegate pickerDidFinishLoading];
                     }
                 }
             }];
         }
         failureBlock:^(NSError *error) {
             NSInteger code = [error code];
             if (code == ALAssetsLibraryAccessUserDeniedError || code == ALAssetsLibraryAccessGloballyDeniedError) {
                 UIAlertView *alert = [[UIAlertView alloc]
                                       initWithTitle:@"Error"
                                       message:@"Since photos may have location data attached, you must approve location data access to use the picker."
                                       delegate:nil
                                       cancelButtonTitle:@"OK"
                                       otherButtonTitles:nil];
                 [alert show];
                 [alert release];
             }
             else {
                 UIAlertView *alert = [[UIAlertView alloc]
                                       initWithTitle:@"Error"
                                       message:@"IDK, dude, something's busted."
                                       delegate:nil
                                       cancelButtonTitle:@"OK"
                                       otherButtonTitles:nil];
                 [alert show];
                 [alert release];
             }
             
             [self.delegate pickerDidCancel:self];
         }];
}

// Thanks to PhotoPickerPlus for being rad
- (void)getAssetFromGesture:(UIGestureRecognizer *)gesture {
    UIImageView *view = (UIImageView *)[gesture view];
    ALAsset *asset = [self.allAssets objectAtIndex:[view tag]];
    BOOL isPhoto = [asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto;

    NSDictionary *info;
    if (isPhoto) {
        info = @{ UIImagePickerControllerMediaType : [[asset defaultRepresentation] UTI],
                  UIImagePickerControllerOriginalImage : [UIImage imageWithCGImage:[[asset defaultRepresentation] fullResolutionImage] scale:1 orientation:(UIImageOrientation)[[asset defaultRepresentation] orientation]],
                  UIImagePickerControllerReferenceURL : [[asset defaultRepresentation] url],
                          };
    }
    else {
        info = @{ UIImagePickerControllerMediaType : [[asset defaultRepresentation] UTI],
                  UIImagePickerControllerReferenceURL : [[asset defaultRepresentation] url],
                    };
    }
    
    [self.delegate pickerDidFinishPickingWithInfo:info];
}

#pragma mark - Dealloc

- (void)releaseObjects
{
    [_allAssets release]; _allAssets = nil;
    [_assetsLibrary release]; _assetsLibrary = nil;
    [_assetsTable release]; _assetsTable = nil;
    [_header release]; _header = nil;
    
    _delegate = nil;
}

- (void)dealloc
{
    [super dealloc];
    [self releaseObjects];
}

@end
