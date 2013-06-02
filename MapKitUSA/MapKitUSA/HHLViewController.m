#import "HHLViewController.h"

@interface HHLViewController ()

@property NSArray *overlays;
@property NSMutableArray *overlayViews;
@property NSMutableDictionary *beaData;
@property double minDataValue;
@property double maxDataValue;

@property (nonatomic, strong) IBOutlet MKMapView *stateMapView;
@property (nonatomic, strong) IBOutlet UISlider *dataScale;

@property (nonatomic, strong) IBOutlet UISlider *dataScaleSlider;
@property (nonatomic, strong) IBOutlet UILabel *dataScaleLabel;

@property (nonatomic, strong) IBOutlet UISlider *yearSlider;
@property (nonatomic, strong) IBOutlet UILabel *yearLabel;

@end

@implementation HHLViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.overlayViews = [[NSMutableArray alloc] init];
    self.overlays = [self usStatesAndTerritoryOverlays];
    [self.stateMapView addOverlays:self.overlays];
}

-(void)updateDataValues
{
    NSString *year = [NSNumber numberWithInt:_yearSlider.value].stringValue;
    NSMutableDictionary *yearDict = [self.beaData objectForKey: year];

    // find new min/max
    _minDataValue = 1.0e9;
    _maxDataValue = 0.0;
    for(NSString *key in yearDict)
    {
        NSString * value = [ yearDict objectForKey:key ];
        _minDataValue = value.floatValue < _minDataValue ? value.floatValue : _minDataValue;
        _maxDataValue = value.floatValue > _maxDataValue ? value.floatValue : _maxDataValue;
    }

    // this needs to repopulate the overlays and views with new year data
    for( int ii=0; ii<self.overlays.count; ++ii )
    {
        MKPolygon *polygon = self.overlays[ii];
        polygon.subtitle = ((NSNumber*)[yearDict objectForKey:polygon.title]).stringValue;
    }
    [self updateDataScale];
}

-(void)updateDataScale
{
    float range = _maxDataValue-_minDataValue;
    for( int ii=0; ii<self.overlays.count; ++ii )
    {
        MKPolygon *polygon = self.overlays[ii];
        MKPolygonView *polygonView = self.overlayViews[ii];
        float sliderValue = self.dataScaleSlider.value;
        float regionValue = polygon.subtitle.floatValue;
        float redValue = sliderValue*(regionValue-_minDataValue)/range;
        UIColor *ratio = [UIColor colorWithRed: redValue green:0.0f blue:1.0-redValue alpha:0.0f];
        polygonView.fillColor = [ratio colorWithAlphaComponent:0.8];
        [ polygonView setNeedsDisplayInMapRect: MKMapRectWorld ];
    }
}

-(IBAction)dataScaleSliderChange:(UISlider*)sender
{
    //    [self.stateMapView removeOverlays:self.overlays];
    //    [self.stateMapView addOverlays:self.overlays];
    
    self.dataScaleLabel.text = [ NSString stringWithFormat: @"%3d", (int)sender.value ];
    [ self updateDataScale ];
}


-(IBAction)yearSliderChange:(UISlider*)sender
{
    self.yearLabel.text = [ NSString stringWithFormat: @"%4d", (int)sender.value ];
    [ self updateDataValues ];
}

#pragma mark - Map Delegate

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolygon class]])
    {
        MKPolygonView *aView = [[MKPolygonView alloc] initWithPolygon:(MKPolygon *)overlay];
        
        CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
        CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
        CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
        UIColor *color = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
                
        UIColor *ratio = [UIColor colorWithRed:[overlay.subtitle floatValue ]*_dataScale.value  green:0.0f blue:0.0f alpha:0.0f];
        //        aView.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
        aView.fillColor = [ratio colorWithAlphaComponent:0.8];
        aView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.65];
        aView.lineWidth = 2;
        
        [self.overlayViews addObject: aView ];

        return aView;
    }
    
    return nil;
}

#pragma mark - Utilities

- (id)load_json: (NSString*) filename
{
    NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"json" ];
    NSData *blob = [NSData dataWithContentsOfFile:path];
    id json = [NSJSONSerialization JSONObjectWithData:blob options:NSJSONReadingAllowFragments error:nil];
    return json;
}

- (NSMutableDictionary *)indexed_data: (NSString*) filename
{
    NSArray *beaJSON = (NSArray*)[self load_json: filename ];
    NSInteger nbea = [beaJSON count];
    NSMutableDictionary *outData = [[ NSMutableDictionary alloc] init];
    for (NSDictionary *element in beaJSON)
    {
        NSString *value         = [element valueForKey:@"DataValue"];
        NSString *geoFIPS       = [element valueForKey:@"GeoFips"];
        NSString *geoName       = [element valueForKey:@"GeoName"];
        NSString *timePeriod    = [element valueForKey:@"TimePeriod"];

        NSMutableDictionary * yearDict = [ outData objectForKey: timePeriod ];
        if ( yearDict == nil )
        {
            yearDict = [[NSMutableDictionary alloc]init];
            [ outData setObject:yearDict forKey:timePeriod];
        }
        assert( yearDict != nil );
        
        [ yearDict setObject:value forKey:geoName ];
    }
    return outData;
}

- (NSArray *)usStatesAndTerritoryOverlays
{
    // country/state/county data: https://github.com/johan/world.geo.json
    NSString *fipsFileName = [[NSBundle mainBundle] pathForResource:@"fips" ofType:@"json" ];
    NSData *fipsData = [NSData dataWithContentsOfFile:fipsFileName];
    id fipsJSON = [NSJSONSerialization JSONObjectWithData:fipsData options:NSJSONReadingAllowFragments error:nil];
    NSMutableDictionary *stateIDToFIPS = [[ NSMutableDictionary alloc ] init ];
    for(id key in fipsJSON)
    {
        NSString *state = [[NSString alloc] initWithFormat:@"%@.state", key];
        [ stateIDToFIPS setObject:key forKey:[fipsJSON valueForKeyPath: state]];
    }

    const int washtenawFips = 26161;
    NSString *coFIPS = [fipsJSON valueForKeyPath: [[NSString alloc] initWithFormat:@"%d.county", washtenawFips]];
    NSString *stFIPS = [fipsJSON valueForKeyPath: [[NSString alloc] initWithFormat:@"%d.stateabbrev", washtenawFips]];
    
    self.beaData = [self indexed_data: @"per-capita-personal-income-by-state-1990-2012"];
    int minYear = 9999, maxYear = 0000;
    for(NSString *key in self.beaData)
    {
        minYear = key.integerValue < minYear ? key.integerValue : minYear;
        maxYear = key.integerValue > maxYear ? key.integerValue : maxYear;
    }
    self.yearLabel.text = [ NSNumber numberWithInt: minYear].stringValue;
    self.yearSlider.value = minYear;
    self.yearSlider.minimumValue = minYear;
    self.yearSlider.maximumValue = maxYear;
    
#if 0 // future our fips data outline processing & using
    NSString *stateFileName = [[NSBundle mainBundle] pathForResource:stFIPS ofType:@"geo.json" ];
    NSData *stateData = [NSData dataWithContentsOfFile:stateFileName];
    id stateJSON = [NSJSONSerialization JSONObjectWithData:stateData options:NSJSONReadingAllowFragments error:nil];
    NSNumber *stFIPSNumber = [stateJSON valueForKeyPath:@"features.properties.fips"];
    NSNumber *stName = [stateJSON valueForKeyPath:@"features.properties.name"];
    
    //    NSString *coFileName = [[NSBundle mainBundle] pathForResource:@"Washtenaw" ofType:@"geo.json"];
    //    NSData *coData = [NSData dataWithContentsOfFile:coFileName];
    //    id coJSON = [NSJSONSerialization JSONObjectWithData:coData options:NSJSONReadingAllowFragments error:nil];
    //    NSString *countyFIPS = [coJSON valueForKeyPath:@"features.properties.county"];
    //    NSString *stateFIPS = [coJSON valueForKeyPath:@"features.properties.name"];
#else
    NSString *fileName = [[NSBundle mainBundle] pathForResource:@"states" ofType:@"json"];
    NSData *overlayData = [NSData dataWithContentsOfFile:fileName];
    id parsedJSON = [NSJSONSerialization JSONObjectWithData:overlayData options:NSJSONReadingAllowFragments error:nil];
    NSArray *states = [parsedJSON valueForKeyPath:@"states.state"];
#endif
    
    NSMutableArray *overlays = [NSMutableArray array];

    for (NSDictionary *state in states)
    {
        NSArray *points = [state valueForKeyPath:@"point"];

        NSInteger numberOfCoordinates = [points count];
        CLLocationCoordinate2D *polygonPoints = malloc(numberOfCoordinates * sizeof(CLLocationCoordinate2D));

        NSInteger index = 0;
        for (NSDictionary *pointDict in points) {
            polygonPoints[index] = CLLocationCoordinate2DMake([[pointDict valueForKeyPath:@"latitude"] floatValue], [[pointDict valueForKeyPath:@"longitude"] floatValue]);
            index++;
        }

        MKPolygon *overlayPolygon = [MKPolygon polygonWithCoordinates:polygonPoints count:numberOfCoordinates];
        overlayPolygon.title = [state valueForKey:@"name"];
        NSString *yearString = [NSNumber numberWithFloat:self.yearSlider.value].stringValue;
        NSMutableDictionary *yearDict = [self.beaData objectForKey:yearString ];
        // overlayPolygon.title
        _minDataValue = 1.0e9;
        _maxDataValue = 0.0;
        for(NSString *key in yearDict)
        {
            NSString * value = [ yearDict objectForKey:key ];
            _minDataValue = value.floatValue < _minDataValue ? value.floatValue : _minDataValue;
            _maxDataValue = value.floatValue > _maxDataValue ? value.floatValue : _maxDataValue;
        }
        self.dataScaleSlider.value = 1.0;
        
        overlayPolygon.subtitle = ((NSNumber*)[yearDict objectForKey:overlayPolygon.title]).stringValue;

        [overlays addObject:overlayPolygon];

//        NSMutableDictionary *regions = [[NSMutableDictionary alloc] init];
//        [ regions setObject: overlayPolygon forKey: @"polygon" ];
//        [ regions setObject: nil forKey: @"fips" ];
//        NSString *stFIPS = [fipsJSON valueForKeyPath: [[NSString alloc] initWithFormat:@"%d.state", washtenawFips]];
        
        free(polygonPoints);
    }
    
    return overlays;
}

@end
