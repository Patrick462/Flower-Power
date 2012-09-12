//
//  HelloWorldLayer.h
//  GravRockCollisions
//
//  Created by Justin Shacklette on 9/6/12.
//  Copyright Saturnboy 2012. All rights reserved.
//

#import "cocos2d.h"
@class Flower;

@interface HelloWorldLayer : CCLayer {
    CGSize _winsize;
    CGPoint _accelerometer;
    CCArray *_flowers;
    int blueFlowerCount, orangeFlowerCount;
}

+(CCScene *) scene;

@end
