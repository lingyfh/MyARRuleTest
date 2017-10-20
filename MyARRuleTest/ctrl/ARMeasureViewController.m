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
    
    SCNNode *startNode;
    SCNNode *endNode;
    SCNNode *lineNode;
    
    NSMutableArray *measureNodes;
    
    NSMutableDictionary *planeNodes;
    NSMutableArray *recentPositions;
    
    int dotCount;
}

@property (weak, nonatomic) IBOutlet ARSCNView *arSCNView;
@property (weak, nonatomic) IBOutlet UILabel *resultInfoLabel;
@property (weak, nonatomic) IBOutlet UIView *measurePoint;


- (IBAction)action2AddPoint:(id)sender;
- (IBAction)action2ClearPoint:(id)sender;

@end

@implementation ARMeasureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    measureNodes = [[NSMutableArray alloc] init];
    planeNodes = [[NSMutableDictionary alloc] init];
    recentPositions = [[NSMutableArray alloc] init];
    
    
    self.arSCNView.delegate = self;
    
    arSession = [ARSession new];
    [arSession setDelegate:self];
    
    arSessionConfig = [ARWorldTrackingConfiguration new];
    arSessionConfig.planeDetection = ARPlaneDetectionHorizontal;
    
    [arSession runWithConfiguration:arSessionConfig];
    self.arSCNView.session = arSession;
    self.arSCNView.debugOptions = ARSCNDebugOptionShowFeaturePoints;
    dotCount = 0;
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
    NSLog(@"mark measurable === %d", measurable);
    [self.measurePoint setTag:measurable ? 1 : 0];
    [self.measurePoint setBackgroundColor:measurable ? [UIColor greenColor] : [UIColor redColor]];
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    
    NSLog(@"didAddNode anchor = %@", anchor);
    
    if (@"a" != nil) {
        return;
    }
    
    if (![anchor isKindOfClass:[ARPlaneAnchor class]]) {
        NSLog(@"didAddNode not plane Anchor = %@", anchor);
        return;
    }
    
    ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
    
    SCNPlane *plane = [SCNPlane planeWithWidth:planeAnchor.extent.x height:planeAnchor.extent.z];
    
    UIImage *image = [UIImage imageNamed:@"tron_grid.png"];
    SCNMaterial *material = [SCNMaterial material];
    material.diffuse.contents = image;
    plane.materials = @[material];
    
    SCNNode *planeNode = [SCNNode nodeWithGeometry:plane];
    planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z);
    planeNode.transform = SCNMatrix4MakeRotation(-M_PI/2.0, 1, 0, 0);
    [self.arSCNView.scene.rootNode addChildNode:planeNode];
    
    [planeNodes setValue:planeNode forKey:anchor.identifier.UUIDString];
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if (@"a" != nil) {
        return;
    }
    
    SCNNode *planeNode = [planeNodes valueForKey:anchor.identifier.UUIDString];
    if (planeNode == nil) {
        return;
    }
    
    ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
    
    
    SCNPlane *plane = (SCNPlane *)planeNode.geometry;
    plane.width = planeAnchor.extent.x;
    plane.height = planeAnchor.extent.z;
    planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z);
}

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self detectObjects];
    });
}


- (void)keepLastItems:(int)max array:(NSMutableArray *)array {
    if ([array count] > max) {
        [array removeObjectsInRange:NSMakeRange(0, [array count] - max)];
    }
}

- (SCNVector3)averageSCNVectorArray:(NSMutableArray *)array {
    SCNVector3 vector = SCNVector3Zero;
    float x = 0;
    float y = 0;
    float z = 0;
    
    for (NSValue *value in array) {
        SCNVector3 temp = SCNVector3Zero;
        [value getValue:&temp];
        x = x + temp.x;
        y = y + temp.y;
        z = z + temp.z;
    }
    
    x = x / [array count];
    y = y / [array count];
    z = z / [array count];
    
    return vector;
}

- (SCNVector3)hitResultPosition {
    NSArray<ARHitTestResult *> *results = [self.arSCNView hitTest:self.arSCNView.center types:ARHitTestResultTypeFeaturePoint];
    if ([results count] <= 0) {
        [self markMeasurable:NO];
        NSLog(@"hit results count === %d", (int)[results count]);
        return SCNVector3Zero;
    }
    ARHitTestResult *hitResult = [results firstObject];
    SCNVector3 vector = SCNVector3Make(hitResult.worldTransform.columns[3].x, hitResult.worldTransform.columns[3].x, hitResult.worldTransform.columns[3].x);
    return vector;
}

- (void)detectObjects {
    
    NSArray<ARHitTestResult *> *results = [self.arSCNView hitTest:self.arSCNView.center types:ARHitTestResultTypeFeaturePoint];
    
    if ([results count] <= 0) {
        [self markMeasurable:NO];
        NSLog(@"hit results count === %d", (int)[results count]);
        return;
    }
    
    // NSLog(@"results count === %d", (int)[results count]);
    
    [self markMeasurable:YES];
    
    if (startNode == nil) {
        return;
    }
    startVector = startNode.position;
    
    
    ARHitTestResult *hitResult = [results firstObject];
    SCNVector3 vector = SCNVector3Make(hitResult.worldTransform.columns[3].x, hitResult.worldTransform.columns[3].x, hitResult.worldTransform.columns[3].x);
    
    
    NSValue *value = [NSValue value:&vector withObjCType:@encode(SCNVector3)];
    [recentPositions addObject:value];
    [self keepLastItems:8 array:recentPositions];
    
    
    endVector = vector;
    // endVector = [self averageSCNVectorArray:recentPositions];
    float distanceX = startVector.x - endVector.x;
    float distanceY = startVector.y - endVector.y;
    float distanceZ = startVector.z - endVector.z;
    float distance = sqrtf(distanceX*distanceX + distanceY*distanceY + distanceZ*distanceZ);
    // endNode.position = endVector;
    
    [self.resultInfoLabel setText:[NSString stringWithFormat:@"%fcm", distance*100]];
    // NSLog(@"distance === %f", distance);
    [self lineBetweenStart:startNode.position end:vector];
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

#pragma mark - Action

- (IBAction)action2AddPoint:(id)sender {
    
    NSArray<ARHitTestResult *> *results = [self.arSCNView hitTest:self.arSCNView.center types:ARHitTestResultTypeFeaturePoint];
    ARHitTestResult *result = [results firstObject];
    if ([results count] <= 0) {
        NSLog(@"action2AddPoint hit result is zero");
        return;
    }
    SCNVector3 worldPostion = SCNVector3Make(result.worldTransform.columns[3].x, result.worldTransform.columns[3].y, result.worldTransform.columns[3].z);
    
    SCNSphere *dot = [SCNSphere sphereWithRadius:1];
    dot.firstMaterial.diffuse.contents = [UIColor whiteColor];
    SCNNode *pointNode = [SCNNode nodeWithGeometry:dot];
    pointNode.scale = SCNVector3Make(1/400.0, 1/400.0, 1/400.0);
    pointNode.position = worldPostion;
    
    [self.arSCNView.scene.rootNode addChildNode:pointNode];
    [measureNodes addObject:pointNode];
    
    if (startNode == nil) {
        startNode = pointNode;
    } else {
        endNode = pointNode;
        
        NSLog(@"end Node position , x = %0.2f, y = %0.2f, z = %0.2f", endNode.position.x, endNode.position.y, endNode.position.z);
        
        [self lineBetweenStart:startNode.position end:endNode.position];
        
        float distanceX = startNode.position.x - endNode.position.x;
        float distanceY = startNode.position.y - endNode.position.y;
        float distanceZ = startNode.position.z - endNode.position.z;
        float distance = sqrtf(distanceX*distanceX + distanceY*distanceY + distanceZ*distanceZ);
        [self.resultInfoLabel setText:[NSString stringWithFormat:@"%0.2f cm", distance*100]];
        [self distanceTextStart:startNode.position end:endNode.position];
    }
}

- (void)addDot:(SCNVector3)position {
    SCNSphere *dot = [SCNSphere sphereWithRadius:1];
    dot.firstMaterial.diffuse.contents = [UIColor whiteColor];
    SCNNode *pointNode = [SCNNode nodeWithGeometry:dot];
    pointNode.scale = SCNVector3Make(1/400.0, 1/400.0, 1/400.0);
    pointNode.position = position;
    
    [self.arSCNView.scene.rootNode addChildNode:pointNode];
    [measureNodes addObject:pointNode];
}

- (void)lineBetweenStart:(SCNVector3)start end:(SCNVector3)end {
    SCNVector3 positions[] = {start, end};
    int indices[] = {0, 1};
    NSLog(@"======== start x = %0.2f, y = %0.2f, z = %0.2f", start.x, start.y, start.z);
    NSLog(@"-------- end   x = %0.2f, y = %0.2f, z = %0.2f", end.x, end.y, end.z);
    
    SCNGeometrySource *source = [SCNGeometrySource geometrySourceWithVertices:positions count:2];
    
    // NSData *sourceData = [NSData dataWithBytes:positions_f length:sizeof(positions_f)];
//    source = [SCNGeometrySource geometrySourceWithData:sourceData semantic:SCNGeometrySourceSemanticVertex vectorCount:sizeof(positions_f) floatComponents:YES componentsPerVector:3 bytesPerComponent:sizeof(float) dataOffset:0 dataStride:(sizeof(float)) * 3];
//
    NSData *indexData = [NSData dataWithBytes:indices length:sizeof(indices)];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:indexData primitiveType:SCNGeometryPrimitiveTypeLine primitiveCount:1 bytesPerIndex:sizeof(int)];
    
    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[source] elements:@[element]];
    
    if (lineNode != nil) {
        [lineNode removeFromParentNode];
        lineNode = nil;
    }
    
    lineNode = [SCNNode nodeWithGeometry:geometry];
    [self.arSCNView.scene.rootNode addChildNode:lineNode];
}

- (void)distanceTextStart:(SCNVector3)start end:(SCNVector3)end {
    SCNText *text = [SCNText textWithString:@"--" extrusionDepth:0.1];
    text.font = [UIFont systemFontOfSize:10];
    text.firstMaterial.diffuse.contents = [UIColor whiteColor];
    text.truncationMode = kCATruncationMiddle;
    text.alignmentMode = kCAAlignmentCenter;
    
    float distanceMeter = [self distanceBetweenStart:start end:end];
    text.string = [NSString stringWithFormat:@"%0.2fCM", distanceMeter * 100];
    
    SCNNode *textNode = [SCNNode nodeWithGeometry:text];
    
    SCNVector3 min, max;
    [textNode getBoundingBoxMin:&min max:&max];
    
    SCNVector3 bound = SCNVector3Make(max.x - min.x, max.y - min.y, max.z - min.z);
    [textNode setPivot:SCNMatrix4MakeTranslation(bound.x/2, bound.y, bound.z/2)];
    
    NSLog(@"min === x =  %f, y = %f, z = %f, max x = %f, y = %f, z = %f", min.x, min.y, min.z, max.x, max.y, max.z);
    
    textNode.scale = SCNVector3Make(1/500.0, 1/500.0, 1/500.0);
    
    SCNVector3 middelPosition = SCNVector3Make((start.x + end.x) / 2.0, (start.y + end.y) / 2.0, (start.z + end.z) / 2.0);
    textNode.position = middelPosition;
    
    [self.arSCNView.scene.rootNode addChildNode:textNode];
    
    [measureNodes addObject:textNode];
}

- (float)distanceBetweenStart:(SCNVector3)start end:(SCNVector3)end {
    float distanceX = start.x - end.x;
    float distanceY = start.y - end.y;
    float distanceZ = start.z - end.z;
    float distance = sqrtf(distanceX*distanceX + distanceY*distanceY + distanceZ*distanceZ);
    return distance;
}

- (IBAction)action2ClearPoint:(id)sender {
    
    for (SCNNode *node in measureNodes) {
        if (node != nil) {
            [node removeFromParentNode];
        }
    }
    
    [measureNodes removeAllObjects];
    
    if (lineNode != nil) {
        [lineNode removeFromParentNode];
    }
    
    lineNode = nil;
    startNode = nil;
    endNode = nil;
}
@end
