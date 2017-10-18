//
//  ARMeasureViewController.m
//  MyARRuleTest
//
//  Created by yunfenghan Ling on 2017/10/17.
//  Copyright © 2017年 lingyfh. All rights reserved.
//

#import "ARMeasureViewController.h"

@import ARKit;
@import SceneKit;

@interface ARMeasureViewController () <ARSCNViewDelegate, ARSessionDelegate, ARSessionObserver>
{
    ARSession *arSession;
    ARWorldTrackingConfiguration *arSessionConfig;
    
    SCNVector3 startVector;
    SCNVector3 endVector;
    BOOL isMeasuring;
}

@property (weak, nonatomic) IBOutlet ARSCNView *arSCNView;
@property (weak, nonatomic) IBOutlet UILabel *resultInfoLabel;
@property (weak, nonatomic) IBOutlet UIView *measurePoint;


@end

@implementation ARMeasureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.arSCNView.delegate = self;
    
    arSession = [ARSession new];
    [arSession setDelegate:self];
    
    arSessionConfig = [ARWorldTrackingConfiguration new];
    [arSession runWithConfiguration:arSessionConfig];
    self.arSCNView.session = arSession;
    self.arSCNView.debugOptions = ARSCNDebugOptionShowFeaturePoints;
    
    [self resetMeasure];
    // Do any additional setup after loading the view.
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.arSCNView.session pause];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.arSCNView.session runWithConfiguration:arSessionConfig];
}

#pragma mark -

- (void)resetMeasure {
    [self.resultInfoLabel setText:@"0.0"];
    startVector = SCNVector3Zero;
    endVector = SCNVector3Zero;
    isMeasuring = NO;
}

#pragma mark -

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self resetMeasure];
    isMeasuring = YES;
    NSLog(@"touch began");
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    isMeasuring = NO;
    NSLog(@"touch end");
}

#pragma mark - ARSCNView Delegate

- (void)markMeasurable:(BOOL)measurable {
    if (measurable && self.measurePoint.tag == 1) {
        return;
    } else if (!measurable && self.measurePoint.tag == 0) {
        return;
    }
    [self.measurePoint setTag:measurable ? 1 : 0];
    [self.measurePoint setBackgroundColor:measurable ? [UIColor greenColor] : [UIColor redColor]];
}

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self detectObjects];
    });
}

- (void)detectObjects {
    ARHitTestResult *hitResult = [self.arSCNView hitTest:self.arSCNView.center types:ARHitTestResultTypeFeaturePoint].firstObject;
    
    SCNVector3 vector = SCNVector3Make(hitResult.worldTransform.columns[3].x, hitResult.worldTransform.columns[3].x, hitResult.worldTransform.columns[3].x);
    if (!isMeasuring) {
        return;
    }
    
    if ([self isMatchVector:startVector second:SCNVector3Zero]) {
        startVector = vector;
    }
    
    endVector = vector;
    float distanceX = startVector.x - endVector.x;
    float distanceY = startVector.y - endVector.y;
    float distanceZ = startVector.z - endVector.z;
    float distance = sqrtf(distanceX*distanceX + distanceY*distanceY + distanceZ*distanceZ);
    
    [self.resultInfoLabel setText:[NSString stringWithFormat:@"%fcm", distance*100]];
    NSLog(@"distance === %f", distance);
    
    // SCNGeometrySource *source = [SCNGeometrySource geometrySourceWithVertices:@[startVector, endVector] count:2];
    
}

- (BOOL)isMatchVector:(SCNVector3)first second:(SCNVector3)second {
    if (first.x == second.x && first.y == second.y && first.z == second.z) {
        return YES;
    }
    return NO;
}

#pragma mark - ARSession Observer
- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    NSLog(@"didFailWithError session = %@, error = %@", session, error);
}

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    NSLog(@"cameraDidChangeTrackingState session = %@, camera = %@", session, camera);
}

- (void)sessionWasInterrupted:(ARSession *)session {
    NSLog(@"sessionWasInterrupted session = %@", session);
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    NSLog(@"sessionInterruptionEnded session = %@", session);
}

- (void)session:(ARSession *)session didOutputAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer {
    NSLog(@"didOutputAudioSampleBuffer session = %@, audioSampleBuffer = %@", session, audioSampleBuffer);
}

#pragma mark -

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    // NSLog(@"didUpdateFrame session = %@, frame = %@", session, frame);
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<ARAnchor*>*)anchors {
    // NSLog(@"didAddAnchors session = %@, anchors = %@", session, anchors);
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<ARAnchor*>*)anchors {
    // NSLog(@"didUpdateAnchors session = %@, anchors = %@", session, anchors);
}

- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<ARAnchor*>*)anchors {
    // NSLog(@"didRemoveAnchors session = %@, anchors = %@", session, anchors);
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
