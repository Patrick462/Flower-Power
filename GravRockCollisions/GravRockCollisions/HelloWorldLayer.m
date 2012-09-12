//
//  HelloWorldLayer.m
//  GravRockCollisions
//
//  Created by Justin Shacklette on 9/6/12.
//  Copyright Saturnboy 2012. All rights reserved.
//  Flower code by Sean McMains, James Stewart, Patrick Weigel

#import "HelloWorldLayer.h"
#import "AppDelegate.h"
#import "Flower.h"

#define PX_TO_M (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 50 : 25)
#define BOUNCE_RESTITUTION 1.0f
#define ACCELEROMETER_INTERP_FACTOR 0.1f
#define MAX_ROCKS 20
#define BLUE_FLOWER_TAG 1
#define ORANGE_FLOWER_TAG 2

@interface HelloWorldLayer()
@property (assign) BOOL isFingerDown;
@property (retain) CCSprite *demonBar;
@property (retain) NSDate *startTime;
@property (assign) NSInteger score;
@end

#pragma mark - HelloWorldLayer

@implementation HelloWorldLayer

+(CCScene *) scene {
	CCScene *scene = [CCScene node];
	HelloWorldLayer *layer = [HelloWorldLayer node];
	[scene addChild: layer];
	return scene;
}

-(CGPoint)randomPoint {
    _winsize = [[CCDirector sharedDirector] winSize];
    return CGPointMake( arc4random_uniform(_winsize.width), arc4random_uniform(_winsize.height));
}

-(void) addFlowers:(NSUInteger)count {
    for (NSUInteger i = 0; i < count; i++) {
        
        Flower *blueFlower = [self makeBlueFlower:[self randomPoint]];
        [self addChild:blueFlower];
        [_flowers addObject:blueFlower];
        
        Flower *orangeFlower = [self makeOrangeFlower:[self randomPoint]];
        [self addChild:orangeFlower];
        [_flowers addObject:orangeFlower];
    }
}

-(id) init {
	if( (self=[super init]) ) {
        blueFlowerCount = 0;
        orangeFlowerCount = 0;
        self.score = 0;
        
        self.isTouchEnabled = YES;
        self.isAccelerometerEnabled = YES;
        
        // compute window size
		_winsize = [[CCDirector sharedDirector] winSize];
        CCLOG(@"window : size=%.0fx%.0f", _winsize.width, _winsize.height);
        
        // compute texture filename
        NSString *texturePlist = @"tex.plist";
        NSString *textureFile = @"tex.png";
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            texturePlist = @"tex-hd.plist";
            textureFile = @"tex-hd.png";
        }
        
        // put up the green background
        CCSprite *greenBackground = [CCSprite spriteWithFile:@"Background Green.png"];
        [greenBackground setPosition:ccp((_winsize.width / 2), (_winsize.height / 2))];
        [self addChild:greenBackground z:0];
        
        // add the demon bar in the middle of the screen
        CCSprite *demonBar = [CCSprite spriteWithFile:@"Demon Bar.png"];
        [demonBar setPosition:ccp((_winsize.width) / 2, (_winsize.height / 2))];
        self.demonBar = demonBar;
        
        // load texture
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:texturePlist];
        CCSpriteBatchNode *sheet = [CCSpriteBatchNode batchNodeWithFile:textureFile];
        [self addChild:sheet];
        
        // init rocks array
        _flowers = [[CCArray alloc] initWithCapacity:MAX_ROCKS];    
        
        [self addFlowers:1];
        [self startTimer];
        [self scheduleUpdate];
	}
	return self;
}

- (void) update:(ccTime)dt {
    Flower *flower;
    int i = 0;
    CCARRAY_FOREACH(_flowers, flower) {
        // velocity verlet
        flower.position = ccpAdd(ccpAdd(flower.position, ccpMult(flower.vel, dt)), ccpMult(flower.acc, dt*dt));
        flower.vel = ccpAdd(flower.vel, ccpMult(flower.acc, dt));
        flower.rotation = flower.rotation + flower.rot;

        // bounce the rock off the walls
        if (flower.position.y < flower.radius) {
            flower.position = ccp(flower.position.x, flower.radius);
            flower.vel = ccp(flower.vel.x, -flower.vel.y * BOUNCE_RESTITUTION);
        }
        if (flower.position.y > (_winsize.height - flower.radius)) {
            flower.position = ccp(flower.position.x, _winsize.height - flower.radius);
            flower.vel = ccp(flower.vel.x, -flower.vel.y * BOUNCE_RESTITUTION); 
        }
        if (flower.position.x < flower.radius) {
            flower.position = ccp(flower.radius, flower.position.y); 
            flower.vel = ccp(-flower.vel.x * BOUNCE_RESTITUTION, flower.vel.y); 
        }
        if (flower.position.x > _winsize.width - flower.radius) {
            flower.position = ccp(_winsize.width - flower.radius, flower.position.y); 
            flower.vel = ccp(-flower.vel.x * BOUNCE_RESTITUTION, flower.vel.y);
        }
        
        // bounce flower off of barrier if the barrier is there
        if (self.isFingerDown)
        {
            // if traveling to the right, and close to the barrier but not beyond it, turn around
            if    ((flower.position.y > (_winsize.height / 2) - flower.radius)
                && (flower.position.y < (_winsize.height / 2))
                && (flower.vel.y > 0))
            {
                flower.vel = ccp(flower.vel.x, -flower.vel.y * BOUNCE_RESTITUTION);
            }
            
            // if traveling to the left, and close to the barrier but not beyond it, turn around
            if    ((flower.position.y < (_winsize.height / 2) + flower.radius)
                   && (flower.position.y > (_winsize.height / 2))
                   && (flower.vel.y < 0))
            {
                flower.vel = ccp(flower.vel.x, -flower.vel.y * BOUNCE_RESTITUTION);
            }
            
 
        }
        
        // collide with other rocks
        for (int j = i + 1; j < _flowers.count; j++) {
            Flower *flower2 = [_flowers objectAtIndex:j];
            
            CGPoint delta = ccpSub(flower.position, flower2.position);
            
            // assume rocks are circles to make collision math easy
            float collisionDistSQ = (flower.radius + flower2.radius) * (flower.radius + flower2.radius);
            float distSQ = ccpDot(delta, delta);
            //CCLOG(@"before pos: (%.3f,%.3f) (%.3f,%.3f)",rock.position.x,rock.position.y,rock2.position.x,rock2.position.y);                       
            //CCLOG(@"before vel: (%.3f,%.3f) (%.3f,%.3f)",rock.vel.x,rock.vel.y,rock2.vel.x,rock2.vel.y);
            if (distSQ <= collisionDistSQ) {  
                // compute separation vector -- distance need to push rocks appart
                float d = ccpLength(delta);
                CGPoint sep = ccpMult(delta, ((flower.radius + flower2.radius) - d)/d);
                
                // compute sum of masses
                float sum = flower.mass + flower2.mass;
                
                // pull both rocks apart weighted by their mass
                flower.position = ccpAdd(flower.position, ccpMult(sep, flower2.mass / sum));
                flower2.position = ccpSub(flower2.position, ccpMult(sep, flower.mass / sum));
                
                // compute normal unit and tangential unit vectors
                CGPoint normUnit = ccpNormalize(sep);
                CGPoint tanUnit = ccpPerp(normUnit);
                
                // project v1 & v2 into normal & tangential space
                CGPoint v = ccp(ccpDot(normUnit, flower.vel), ccpDot(tanUnit, flower.vel));
                CGPoint v2 = ccp(ccpDot(normUnit, flower2.vel), ccpDot(tanUnit, flower2.vel));
                
                // tangential is preserved, normal is elastic collision
                CGPoint vFinal = ccp( (BOUNCE_RESTITUTION * flower2.mass * (v2.x - v.x) + flower.mass * v.x + flower2.mass * v2.x) / sum, v.y);
                CGPoint v2Final = ccp( (BOUNCE_RESTITUTION * flower.mass * (v.x - v2.x) + flower.mass * v.x + flower2.mass * v2.x) / sum, v2.y);
                
                // project back to real space
                CGPoint vBackN = ccpMult(normUnit, vFinal.x);
                CGPoint vBackT = ccpMult(tanUnit, vFinal.y);
                CGPoint v2BackN = ccpMult(normUnit, v2Final.x);
                CGPoint v2BackT = ccpMult(tanUnit, v2Final.y);
                
                // sum Normal + Tangential velocities to get the final velocity
                flower.vel = ccpAdd(vBackN, vBackT);
                flower2.vel = ccpAdd(v2BackN, v2BackT);
            }
            
            //CCLOG(@"after pos: (%.3f,%.3f) (%.3f,%.3f)",rock.position.x,rock.position.y,rock2.position.x,rock2.position.y);                       
            //CCLOG(@"after vel: (%.3f,%.3f) (%.3f,%.3f)",rock.vel.x,rock.vel.y,rock2.vel.x,rock2.vel.y);
        }
        
        i++;
    }
}

-(BOOL)flowerIsOnLeft:(CCSprite*)flower {
    return flower.position.y < ( _winsize.height / 2 );
}

-(BOOL) areFlowersSegregated {
    CCSprite *lastFlower = [_flowers lastObject];
    BOOL lastFlowerIsOnLeft = [self flowerIsOnLeft:lastFlower];
    if ( lastFlower != nil ) {
        for (NSInteger i = 0; i < [_flowers count] - 1; i++) {
            CCSprite *flower = [_flowers objectAtIndex:i];
            if ( flower.tag == lastFlower.tag ) {
                if ( [self flowerIsOnLeft:flower] != lastFlowerIsOnLeft ) return NO;
            } else {
                if ( [self flowerIsOnLeft:flower] == lastFlowerIsOnLeft ) return NO;
            }
            return YES;
        }
    }
    return NO;
}

# pragma mark - Timer 
#define kLevel 1
#define kFactor 10
#define kLevelTime 20

- (void) startTimer
{
    self.startTime = [NSDate dateWithTimeIntervalSinceNow:0];
}

- (void) stopTimer
{
    NSDate *stopTime = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval elapsedTime = [stopTime timeIntervalSinceDate:self.startTime];
    self.score = round(kLevel * kFactor * (kLevelTime - elapsedTime));
}


# pragma mark - Demon Bar Management
-(void) showDemonBar {
    [self addChild:self.demonBar z:1];
    self.isFingerDown = YES;
    if ( [self areFlowersSegregated] ) {
        [self stopTimer];
        NSLog(@"Flowers are segregated. You win! Your Score is: %d", self.score);
        
    } else {
        NSLog(@"You still have mixed flowers. Fix it!");
    }
}

-(void) hideDemonBar {
    [self.demonBar removeFromParentAndCleanup:YES];
    self.isFingerDown = NO;
}

-(void) registerWithTouchDispatcher {
	[[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

-(BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    [self showDemonBar];
    return YES;
}

-(void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    [self hideDemonBar];
}

-(Flower *) makeBlueFlower:(CGPoint)pos {
    blueFlowerCount++;
    float scale = 0.3f;
    NSString *flowerPath = [[NSBundle mainBundle]pathForResource:@"blue-flower" ofType:@"png" ];
    Flower *flower = [Flower spriteWithFile:flowerPath];
    flower.position = pos;
    CGPoint initialVelocity = CGPointMake(random() % 200 - 100, random() % 200 - 100);
    flower.vel = initialVelocity;
    flower.acc = ccp(0,0);
    flower.mass = 1.0f;
    flower.radius = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 1 : 0.5) * flower.boundingBox.size.width * scale;
    flower.rot = random() / 0x30000000 - 0.5;
    flower.scale = 0.3;
    flower.tag = BLUE_FLOWER_TAG;
    CCLOG(@"Blue Flower: count %d, x %f, y%f",
          blueFlowerCount, flower.position.x, flower.position.y);
    return flower;
}

-(Flower *) makeOrangeFlower:(CGPoint)pos {
    orangeFlowerCount++;
    float scale = 0.3f;
    NSString *flowerPath = [[NSBundle mainBundle]pathForResource:@"orange-flower" ofType:@"png" ];
    Flower *flower = [Flower spriteWithFile:flowerPath];
    flower.position = pos;
    CGPoint initialVelocity = CGPointMake(random() % 150 - 75, random() % 150 - 75);
    flower.vel = initialVelocity;
    flower.acc = ccp(0,0);
    flower.mass = 2.0f;
    flower.radius = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 1 : 0.5) * flower.boundingBox.size.width * scale;
    flower.rot = random() / 0x30000000 - 0.5;
    flower.scale = scale;
    flower.tag = ORANGE_FLOWER_TAG;
    CCLOG(@"Orange Flower: count %d, x %f, y%f",
          orangeFlowerCount, flower.position.x, flower.position.y);

    return flower;
}

- (void) dealloc {
    [_flowers release]; _flowers = nil;
	[super dealloc];
}

@end
