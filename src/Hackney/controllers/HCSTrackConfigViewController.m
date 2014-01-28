//
//  HCSTrackConfigViewController.m
//  CycleStreets
//
//  Created by Neil Edwards on 20/01/2014.
//  Copyright (c) 2014 CycleStreets Ltd. All rights reserved.
//

#import "HCSTrackConfigViewController.h"
#import "AppConstants.h"
#import "UserLocationManager.h"
#import "RMMapView.h"
#import "CycleStreets.h"
#import "SVPulsingAnnotationView.h"
#import "UIView+Additions.h"
#import "GlobalUtilities.h"
#import "UIActionSheet+BlocksKit.h"

#import "HCSMapViewController.h"
#import "PickerViewController.h"
#import "HCSUserDetailsViewController.h"
#import "PhotoWizardViewController.h"
#import "TripManager.h"
#import "Trip.h"
#import "User.h"
#import "RMUserLocation.h"
#import "UserManager.h"

#import "CoreDataStore.h"

#import <CoreLocation/CoreLocation.h>

static NSString *const LOCATIONSUBSCRIBERID=@"HCSTrackConfig";

@interface HCSTrackConfigViewController ()<GPSLocationProvider,RMMapViewDelegate,UIActionSheetDelegate,UIPickerViewDelegate>


// hackney
@property (nonatomic, strong) TripManager								*tripManager;
@property (nonatomic,strong)  Trip										*currentTrip;


@property (nonatomic, strong) IBOutlet RMMapView						* mapView;//map of current area
@property (nonatomic, strong) IBOutlet UILabel							* attributionLabel;// map type label


@property(nonatomic,weak) IBOutlet UILabel								*trackDurationLabel;
@property(nonatomic,weak) IBOutlet UILabel								*trackSpeedLabel;
@property(nonatomic,weak) IBOutlet UILabel								*trackDistanceLabel;

@property(nonatomic,weak) IBOutlet UIButton								*actionButton;
@property (weak, nonatomic) IBOutlet UIView								*actionView;


@property (nonatomic, strong) CLLocation								* lastLocation;// last location
@property (nonatomic, strong) CLLocation								* currentLocation;

@property (nonatomic, strong) SVPulsingAnnotationView					* gpsLocationView;


// opration

@property (nonatomic,strong)  NSTimer									*trackTimer;


// state
@property (nonatomic,assign)  BOOL										isRecordingTrack;
@property (nonatomic,assign)  BOOL										shouldUpdateDuration;
@property (nonatomic,assign)  BOOL										didUpdateUserLocation;
@property (nonatomic,assign)  BOOL										userInfoSaved;


-(void)updateUI;


@end

@implementation HCSTrackConfigViewController



//
/***********************************************
 * @description		NOTIFICATIONS
 ***********************************************/
//

-(void)listNotificationInterests{
	
	[self initialise];
    
	[notifications addObject:GPSLOCATIONCOMPLETE];
	[notifications addObject:GPSLOCATIONUPDATE];
	[notifications addObject:GPSLOCATIONFAILED];
	
	[notifications addObject:HCSDISPLAYTRIPMAP];
	
	[super listNotificationInterests];
	
}

-(void)didReceiveNotification:(NSNotification*)notification{
	
	[super didReceiveNotification:notification];
	
	NSString		*name=notification.name;
	
	
	
	if([name isEqualToString:HCSDISPLAYTRIPMAP]){
		[self displayUploadedTripMap];
	}
	
}



#pragma mark - Location updates


- (void)mapView:(RMMapView *)mapView didUpdateUserLocation:(RMUserLocation *)userLocation{
	
	CLLocation *location=userLocation.location;
	CLLocationDistance deltaDistance = [location distanceFromLocation:_lastLocation];
	
	self.lastLocation=_currentLocation;
	self.currentLocation=location;
	
    
	if ( !_didUpdateUserLocation ){
		
		[_mapView setCenterCoordinate:_currentLocation.coordinate animated:YES];
		
		_didUpdateUserLocation = YES;
		
	}else if ( deltaDistance > 1.0 ){
		
		[_mapView setCenterCoordinate:_currentLocation.coordinate animated:YES];
	}
	
	if ( _isRecordingTrack ){
		
		
		self.currentTrip=[TripManager sharedInstance].currentRecordingTrip;
		
		CLLocationDistance distance = [_tripManager addCoord:_currentLocation];
		_trackDistanceLabel.text = [NSString stringWithFormat:@"%.1f mi", distance / 1609.344];
	}
	
	
	if ( _currentLocation.speed >= 0 )
		_trackSpeedLabel.text = [NSString stringWithFormat:@"%.1f mph", _currentLocation.speed * 3600 / 1609.344];
	else
		_trackSpeedLabel.text = @"0.0 mph";
	
}



// assess wether user has been in the same place too long
-(void)determineUserLocationStopped{
	
	
	// compare last lcoation and new location
	
	// if same within certain accurcy > start auto stop timer
	
	// next location does not compare clear timer
	
	// if timer expires auto stop Trip and save
	
	
	
}


//
/***********************************************
 * @description			VIEW METHODS
 ***********************************************/
//

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.tripManager=[TripManager sharedInstance];

	[self hasUserInfoBeenSaved];
	
    [self createPersistentUI];
}


-(void)viewWillAppear:(BOOL)animated{
    
    [self createNonPersistentUI];
    
    [super viewWillAppear:animated];
}


-(void)createPersistentUI{
	
	
	[RMMapView class];
	[_mapView setDelegate:self];
	_mapView.showsUserLocation=YES;
	
	
	
	UIButton *button=[[UIButton alloc]initWithFrame:CGRectMake(0, 0, 33, 33)];
	[button setImage:[UIImage imageNamed:@"UIButtonBarCameraSmall.png"] forState:UIControlStateNormal];
	[button addTarget:self action:@selector(didSelectPhotoWizardButton:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *barbutton=[[UIBarButtonItem alloc] initWithCustomView:button];
	[self.navigationItem setRightBarButtonItem:barbutton animated:NO];
	
	
	
	//TODO: UI styling
	[_actionButton addTarget:self action:@selector(didSelectActionButton:) forControlEvents:UIControlEventTouchUpInside];
	
	
}

-(void)createNonPersistentUI{
    
	
}



-(void)updateUI{
	
	if ( _shouldUpdateDuration )
	{
		NSDate *startDate = [[_trackTimer userInfo] objectForKey:@"StartDate"];
		NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:startDate];
		
		static NSDateFormatter *inputFormatter = nil;
		if ( inputFormatter == nil )
			inputFormatter = [[NSDateFormatter alloc] init];
		
		[inputFormatter setDateFormat:@"HH:mm:ss"];
		NSDate *fauxDate = [inputFormatter dateFromString:@"00:00:00"];
		[inputFormatter setDateFormat:@"HH:mm:ss"];
		NSDate *outputDate = [[NSDate alloc] initWithTimeInterval:interval sinceDate:fauxDate];
		
		self.trackDurationLabel.text = [inputFormatter stringFromDate:outputDate];
	}
	
	
}


- (void)resetDurationDisplay
{
	_trackDurationLabel.text = @"00:00:00";
	
	_trackDistanceLabel.text = @"0 mi";
}

-(void)resetTimer{
	
	if(_trackTimer!=nil)
		[_trackTimer invalidate];
}



#pragma mark - RMMap delegate


-(void)doubleTapOnMap:(RMMapView*)map At:(CGPoint)point{
	
}

- (void) afterMapMove: (RMMapView*) map {
	[self afterMapChanged:map];
}


- (void) afterMapZoom: (RMMapView*) map byFactor: (float) zoomFactor near:(CGPoint) center {
	[self afterMapChanged:map];
}

- (void) afterMapChanged: (RMMapView*) map {
	
	if(_gpsLocationView.superview!=nil)
		[_gpsLocationView updateToLocation];
	
}



#pragma mark - UI events


-(IBAction)didSelectActionButton:(id)sender{
	
	if(_isRecordingTrack == NO){
		
        BetterLog(@"start");
        
        // start the timer if needed
        if ( _trackTimer == nil )
        {
			[self resetDurationDisplay];
			self.trackTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f
													 target:self selector:@selector(updateUI)
												   userInfo:[self newTripTimerUserInfo] repeats:YES];
        }
        
       // set start button to "Save"
		
		
        _isRecordingTrack = YES;
		self.currentTrip=[[TripManager sharedInstance] createTrip];
		[[TripManager sharedInstance] startTrip];
		
		_mapView.userTrackingMode=RMUserTrackingModeFollow;
		
		[self updateActionStateForTrip];
        
        // set flag to update counter
        _shouldUpdateDuration = YES;
		
    }else {
		
		__weak __block HCSTrackConfigViewController *weakSelf=self;
		UIActionSheet *actionSheet=[UIActionSheet sheetWithTitle:@""];
		[actionSheet setDestructiveButtonWithTitle:@"Discard"	handler:^{
			[weakSelf resetRecordingInProgress];
			[[TripManager sharedInstance] removeCurrentRecordingTrip];
		}];
		[actionSheet addButtonWithTitle:@"Save" handler:^{
			[weakSelf initiateSaveTrip];
		}];
		
		[actionSheet setCancelButtonWithTitle:@"Continue" handler:^{
			_shouldUpdateDuration=YES;
		}];
		
		
		
		[actionSheet showInView:[[[UIApplication sharedApplication]delegate]window]];
		
    }
	
}



-(void)updateActionStateForTrip{
	
	if(_isRecordingTrack){
		
		[_actionButton setTitle:@"Save" forState:UIControlStateNormal];
		
		[UIView animateWithDuration:0.4 animations:^{
			_actionView.backgroundColor=UIColorFromRGB(0xCB0000);
		}];
		
	}else{
		
		[_actionButton setTitle:@"Start" forState:UIControlStateNormal];
		
		[UIView animateWithDuration:0.4 animations:^{
			_actionView.backgroundColor=UIColorFromRGB(0x509720);
		}];
		
	}
	
}


- (void)initiateSaveTrip{
	
	[[NSUserDefaults standardUserDefaults] setInteger:0 forKey: @"pickerCategory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
	
	
	if ( _isRecordingTrack ){
		
		UINavigationController *nav=nil;
		
		if([[UserManager sharedInstance] hasUser]){
			
			PickerViewController *tripPurposePickerView = [[PickerViewController alloc] initWithNibName:@"TripPurposePicker" bundle:nil];
			tripPurposePickerView.delegate=self;
			
			nav=[[UINavigationController alloc]initWithRootViewController:tripPurposePickerView];
			
		}else{
			
			HCSUserDetailsViewController *userController=[[HCSUserDetailsViewController alloc]initWithNibName:[HCSUserDetailsViewController nibName] bundle:nil];
			userController.tripDelegate=self;
			userController.viewMode=HCSUserDetailsViewModeSave;
			nav=[[UINavigationController alloc]initWithRootViewController:userController];
			
		}
		
		[self.navigationController presentViewController:nav animated:YES	completion:^{
			
		}];
		
	}
    
}



-(void)dismissTripSaveController{
	
	[self.navigationController dismissModalViewControllerAnimated:YES];
	
}

- (void)displayUploadedTripMap{
	
    [self resetRecordingInProgress];
    
}


#pragma mark - UI Events

-(IBAction)didSelectPhotoWizardButton:(id)sender{
	
	PhotoWizardViewController *photoWizard=[[PhotoWizardViewController alloc]initWithNibName:[PhotoWizardViewController nibName] bundle:nil];
	photoWizard.extendedLayoutIncludesOpaqueBars=NO;
	photoWizard.edgesForExtendedLayout = UIRectEdgeNone;
	photoWizard.isModal=YES;
	
	[self presentViewController:photoWizard animated:YES completion:^{
		
	}];
	
}



#pragma mark - Trip methods

- (BOOL)hasUserInfoBeenSaved
{
	BOOL response = NO;
	
	NSError *error;
	NSArray *fetchResults=[[CoreDataStore mainStore] allForEntity:@"User" error:&error];
	
	if ( fetchResults.count>0 ){
		
		if ( fetchResults != nil ){
			
			User *user = (User*)[fetchResults objectAtIndex:0];
			
			self.userInfoSaved = [user userInfoSaved];
			response = _userInfoSaved;
			
		}else{
			// Handle the error.
			NSLog(@"no saved user");
			if ( error != nil )
				NSLog(@"PersonalInfo viewDidLoad fetch error %@, %@", error, [error localizedDescription]);
		}
	}else{
		NSLog(@"no saved user");
	}
		
	
	return response;
}


- (NSDictionary *)newTripTimerUserInfo
{
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSDate date], @"StartDate",
			[NSNull null], @"TripManager", nil ];
}



- (void)resetRecordingInProgress
{
	[[TripManager sharedInstance] resetTrip];
	_isRecordingTrack=NO;
	
	[self updateActionStateForTrip];
	
	_mapView.userTrackingMode=RMUserTrackingModeNone;
	
	[self resetDurationDisplay];
	[self resetTimer];
}



#pragma mark - Location Provider


- (float)getX {
	CGPoint p = [self.mapView coordinateToPixel:self.currentLocation.coordinate];
	return p.x;
}

- (float)getY {
	CGPoint p = [self.mapView coordinateToPixel:self.currentLocation.coordinate];
	return p.y;
}

- (float)getRadius {
	
	double metresPerPixel = [_mapView metersPerPixel];
	float locationRadius=(self.currentLocation.horizontalAccuracy / metresPerPixel);
	
	return MAX(locationRadius, 40.0f);
}



#pragma mark TripPurposeDelegate methods

- (NSString *)setPurpose:(unsigned int)index
{
	NSString *purpose = [_tripManager setPurpose:index];
	return [self updatePurposeWithString:purpose];
}


- (NSString *)getPurposeString:(unsigned int)index
{
	return [_tripManager getPurposeString:index];
}

- (NSString *)updatePurposeWithString:(NSString *)purpose
{
	// only enable start button if we don't already have a pending trip
	if ( _trackTimer == nil )
		_actionButton.enabled = YES;
	
	_actionButton.hidden = NO;
	
	return purpose;
}

- (NSString *)updatePurposeWithIndex:(unsigned int)index
{
	return [self updatePurposeWithString:[_tripManager getPurposeString:index]];
}



- (void)didCancelSaveJourneyController
{
	[self.navigationController dismissModalViewControllerAnimated:YES];
    
	[[TripManager sharedInstance] startTrip];
	_isRecordingTrack = YES;
	_shouldUpdateDuration = YES;
}


- (void)didPickPurpose:(unsigned int)index
{
	_isRecordingTrack = NO;
    [[TripManager sharedInstance]resetTrip];
	_actionButton.enabled = YES;
	[self resetTimer];
	
	[_tripManager setPurpose:index];
}


//
/***********************************************
 * @description			MEMORY
 ***********************************************/
//
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}


@end