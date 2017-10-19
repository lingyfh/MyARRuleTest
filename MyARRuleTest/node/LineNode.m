//
//  LineNode.m
//  MyARRuleTest
//
//  Created by yunfenghan Ling on 2017/10/19.
//  Copyright © 2017年 lingyfh. All rights reserved.
//

#import "LineNode.h"

#define MAX_ARRAY 8

@import ARKit;
@import SceneKit;

@interface LineNode ()
{
    ARSCNView *arScnView;
    
    SCNNode *startNode;
    SCNNode *endNode;
    SCNNode *lineNode;
    SCNNode *textNode;
    
    NSMutableArray *recentFocusSquarePositions;
}
@end

@implementation LineNode

- (void)keepLastItems:(int)max {
    if ([recentFocusSquarePositions count] > max) {
        [recentFocusSquarePositions removeObjectsInRange:NSMakeRange(0, [recentFocusSquarePositions count] - max)];
    }
}

- (instancetype)initWithStartPosition:(SCNVector3)startPos sceneView:(ARSCNView *)scnView {
    self = [super init];
    
    recentFocusSquarePositions = [NSMutableArray arrayWithCapacity:8];
    
    arScnView = scnView;
    
    SCNSphere *dot = [SCNSphere sphereWithRadius:1];
    dot.firstMaterial.diffuse.contents = [UIColor whiteColor];
    [dot.firstMaterial setDoubleSided:YES];
    
    startNode = [SCNNode nodeWithGeometry:dot];
    startNode.scale = SCNVector3Make(1/400.0, 1/400.0, 1/400.0);
    startNode.position = startPos;
    [arScnView.scene.rootNode addChildNode:startNode];
    
    endNode = [SCNNode nodeWithGeometry:dot];
    endNode.scale = SCNVector3Make(1/400.0, 1/400.0, 1/400.0);
    
    SCNText *text = [SCNText textWithString:@"--" extrusionDepth:0.1];
    text.font = [UIFont systemFontOfSize:10];
    text.firstMaterial.diffuse.contents = [UIColor whiteColor];
    text.alignmentMode = kCAGravityCenter;
    text.truncationMode = kCATruncationMiddle;
    [text.firstMaterial setDoubleSided:YES];
    
    textNode = [SCNNode nodeWithGeometry:text];
    textNode.scale = SCNVector3Make(1/500.0, 1/500.0, 1/500.0);
    return self;
}


- (float)updatePosition:(SCNVector3)position camera:(ARCamera *)camera {
    float length = 0;
    
    SCNVector3 posEnd = [self updateTransform:position camera:camera];
    
    if (endNode.parentNode == nil) {
        [arScnView.scene.rootNode addChildNode:endNode];
    }
    endNode.position = posEnd;
    
    SCNVector3 startPos = startNode.position;
    SCNVector3 middle = SCNVector3Make((startPos.x + posEnd.x) / 2, (startPos.y + posEnd.y) / 2, (startPos.z + posEnd.z) / 2);
    SCNText *text = (SCNText *)textNode.geometry;
    [text setString:[NSString stringWithFormat:@"%0.2fcm", length*100]];
    textNode.position = middle;
    
    if (textNode.parentNode == nil) {
        [arScnView.scene.rootNode addChildNode:textNode];
    }
    
    [lineNode removeFromParentNode];
    
    return length;
}

- (SCNVector3)updateTransform:(SCNVector3)position camera:(ARCamera *)camera {
    NSValue *value = [NSValue value:&position withObjCType:@encode(SCNVector3)];
    [recentFocusSquarePositions addObject:value];
    [self keepLastItems:8];
    
    float tile = fabsf(camera.eulerAngles.x);
    float threshold1 = M_PI / 2 * 0.65;
    float threshold2 = M_PI / 2 * 0.67;
    
    float yaw = atan2f(camera.transform.columns[0].x, camera.transform.columns[1].x);
    float angle = 0;
    
    if (tile >= 0 && tile <  threshold1) {
        angle = camera.eulerAngles.y;
    } else if (threshold1 >= 0 && tile <  threshold2) {
        float relativeInRange = fabsf((tile - threshold1) / (threshold2 - threshold1));
        float normalizedY = [self normalize:camera.eulerAngles.y forMinimalRotationTo:yaw];
        angle = normalizedY * (1 - relativeInRange) + yaw * relativeInRange;
    } else {
        angle = yaw;
    }
    
    [textNode runAction:[SCNAction rotateToX:0 y:angle z:0 duration:0]];
    
    SCNVector3 pos = SCNVector3Zero;
    NSValue *obj = [recentFocusSquarePositions lastObject];
    [obj getValue:&pos];
    
    return pos;
    
    // return SCNVector3Zero;
}

- (float)normalize:(float)angle forMinimalRotationTo:(float)ref {
    float normalized = angle;
    while (fabsf(normalized - ref) > (M_PI / 4)) {
        if (angle > ref) {
            normalized = normalized - M_PI / 2;
        } else {
            normalized = normalized + M_PI / 2;
        }
    }
    return normalized;
}



@end
