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
#define MAX_FLOWERS 20
#define BLUE_FLOWER_TAG 1
#define ORANGE_FLOWER_TAG 2

@interface HelloWorldLayer()
@property (assign) BOOL isFingerDown;
@property (retain) CCSprite *demonBar;
@property (retain) NSDate *startTime;
@property (assign) NSInteger score;
@property (assign) BOOL levelComplete;
@property (assign) BOOL quitLevel;
@property (retain) CCLabelTTF *scoreLabel;
@end

#pragma mark - HelloWorldLayer

@implementation HelloWorldLayer

+(CCScene *) scene {
    CCLOG(@"HWL/scene");
	CCScene *scene = [CCScene node];
	HelloWorldLayer *layer = [HelloWorldLayer node];
	[scene addChild: layer];
	return scene;
}

-(CGPoint)randomPoint {
    u_int32_t randomX = arc4random_uniform(_winsize.width);
    u_int32_t randomY = arc4random_uniform(_winsize.height);
    CCLOG(@"HWL/randomPoint             x:%4d,   y:%4d", randomX, randomY);
    
    return CGPointMake(randomX, randomY);
}

-(void) addFlowers:(NSUInteger)count {
    CCLOG(@"HWL/addFlowers");
    for (NSUInteger i = 0; i < count; i++) {
        
        Flower *blueFlower = [self makeFlowerAtPoint:[self randomPoint] ofColor:@"blue"];
        [self addChild:blueFlower];
        [_flowers addObject:blueFlower];
        
        Flower *orangeFlower = [self makeFlowerAtPoint:[self randomPoint] ofColor:@"orange"];
        [self addChild:orangeFlower];
        [_flowers addObject:orangeFlower];
    }
}

-(id) init {
    CCLOG(@"HWL/init");
    firstCallToUpdate = YES;
	if( (self=[super init]) ) {
        blueFlowerCount = 0;
        orangeFlowerCount = 0;
        self.score = 0;
        self.levelComplete = NO;
        self.quitLevel = NO;
        
        [[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"background-music-aac.wav"];
        
        self.isTouchEnabled = YES;
        
        // compute window size
		_winsize = [[CCDirector sharedDirector] winSize];
        CCLOG(@"HWL/init windowsize: _%.0fx%.0f", _winsize.width, _winsize.height);
        
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
        
        // init flowers array
        _flowers = [[CCArray alloc] initWithCapacity:MAX_FLOWERS];
        
        [self startLevel];
 	}
	return self;
}

- (void) startLevel
{
    CCLOG(@"HWL/startLevel");
    [self removeChild:self.scoreLabel cleanup:YES];
    [self addFlowers:1];
    [self startTimer];
    if (self.levelComplete) {
        [self resumeSchedulerAndActions];
    } else {
        [self scheduleUpdate];
    }
    self.levelComplete = NO;
}

- (void) endLevel
{
    CCLOG(@"HWL/endLevel");
    self.levelComplete = YES;
    [self stopTimer];
    [self pauseSchedulerAndActions];
    [self showScore];
    NSLog(@"Flowers are segregated by color. You win! Your Score is: %d", self.score);
}

- (void) showScore
{
    CCLOG(@"HWL/showScore");
    NSString *string = [NSString stringWithFormat:@"Level Complete! Score %d", self.score];
    CCLabelTTF *label = [CCLabelTTF labelWithString:string fontName:@"Marker Felt" fontSize:40];
    label.position = ccp( _winsize.width/2, _winsize.height/2);
    label.rotation = -90;
    self.scoreLabel = label;
    [self addChild:label];
}

- (void) update:(ccTime)dt {
    if (firstCallToUpdate) {
        CCLOG(@"HWL/update (first call) array count: %d",
              [_flowers count]);
        firstCallToUpdate = NO;
    }
    Flower *flower;
    int i = 0;
    CCARRAY_FOREACH(_flowers, flower) {
        CGFloat growthFactor = 1.001;
        
        // don't let the flowers get too big - grow them only if they're less than 1/6 of the screen.
        if ( flower.radius < _winsize.width / 9 ) {
            flower.radius = flower.radius * growthFactor;
            flower.scale = flower.scale * growthFactor;
        }
        

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
        
        // collide with other flowers
        for (int j = i + 1; j < _flowers.count; j++) {
            Flower *flower2 = [_flowers objectAtIndex:j];
            
            CGPoint delta = ccpSub(flower.position, flower2.position);
            
            // assume flowers are circles to make collision math easy
            float collisionDistSQ = (flower.radius + flower2.radius) * (flower.radius + flower2.radius);
            float distSQ = ccpDot(delta, delta);
            //CCLOG(@"before pos: (%.3f,%.3f) (%.3f,%.3f)",rock.position.x,rock.position.y,rock2.position.x,rock2.position.y);                       
            //CCLOG(@"before vel: (%.3f,%.3f) (%.3f,%.3f)",rock.vel.x,rock.vel.y,rock2.vel.x,rock2.vel.y);
            if (distSQ <= collisionDistSQ) {  
                // compute separation vector -- distance need to push flowers appart
                float d = ccpLength(delta);
                CGPoint sep = ccpMult(delta, ((flower.radius + flower2.radius) - d)/d);
                
                // compute sum of masses
                float sum = flower.mass + flower2.mass;
                
                // pull both flowers apart weighted by their mass
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
    BOOL iAmOnTheLeft = flower.position.y < ( _winsize.height / 2 );
    CCLOG(@"HWL/flowerIsOnLeft x:%6.1f, y:%6.1f, scale:%5.2f, On Left? %d",
          flower.position.x, flower.position.y, flower.scale, iAmOnTheLeft);
    return iAmOnTheLeft;
}

-(BOOL) areFlowersSegregated {
    CCLOG(@"HWL/areFlowersSegregated");
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
        }
        return YES;
    }
    return NO;
}

# pragma mark - Timer and Score
#define kLevel 1
#define kFactor 50          // kFactor * kLevelTime is maximum score (if solve at start of level)
#define kLevelTime 40       // seconds from start of level to drop to minimum score
#define kMinimumScore 100

- (void) startTimer
{
    CCLOG(@"HWL/startTimer");

    self.startTime = [NSDate dateWithTimeIntervalSinceNow:0];
}

- (void) stopTimer
{
    CCLOG(@"HWL/stopTimer");
    NSDate *stopTime = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval elapsedTime = [stopTime timeIntervalSinceDate:self.startTime];
    if (self.quitLevel == NO) {
         self.score = kMinimumScore + round(kLevel * kFactor * max(0,(kLevelTime - elapsedTime)));
    } else {
        self.quitLevel = NO;
        self.score = 0;}
   
}


# pragma mark - Demon Bar Management
-(void) showDemonBar {
    CCLOG(@"HWL/showDemonBar");
    [self addChild:self.demonBar z:1];
    self.isFingerDown = YES;
    if ( [self areFlowersSegregated] ) {
        [self endLevel];        
    } else {
        NSLog(@"You still have flowers mixed by color. Segregate all Blue flowers to one side, Orange to the other.");
    }
}

-(void) hideDemonBar {
    CCLOG(@"HWL/hideDemonBar");
    [self.demonBar removeFromParentAndCleanup:YES];
    self.isFingerDown = NO;
}

#pragma mark - Other
-(void) registerWithTouchDispatcher {
    CCLOG(@"HWL/registerWithTouchDispatcher");
	[[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

-(BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    int fingerCount = [[event allTouches] count];
    CCLOG(@"HWL/ccTouchBegan fingers:%d", fingerCount);
    if ( self.levelComplete) {
        [self startLevel];
    } else {
        if (fingerCount == 1) {
            [self showDemonBar];
        } else {
            self.quitLevel = YES;
            [self endLevel];}
    }
    return YES;
}

-(void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    CCLOG(@"HWL/ccTouchEnded");
    [self hideDemonBar];
}

-(Flower *) makeFlowerAtPoint:(CGPoint)pos ofColor:(NSString *) flowerColor {
    NSString *flowerPath;
    int xVel, yVel, flowerTag;
    float flowerMass;
    
    if ([flowerColor isEqualToString:@"blue"]) {
        // set up blue flower
        blueFlowerCount++;
        flowerPath = [[NSBundle mainBundle]pathForResource:@"purple-flower" ofType:@"png" ];
        xVel = -100 + arc4random_uniform(200);
        yVel = -100 + arc4random_uniform(200);
        flowerTag = BLUE_FLOWER_TAG;
        flowerMass = 1.0f;
    }
    else {
        // set up orange flower
        orangeFlowerCount++;
        flowerPath = [[NSBundle mainBundle]pathForResource:@"orange-flower" ofType:@"png" ];
        xVel = -75 + arc4random_uniform(150);
        yVel = -75 + arc4random_uniform(150);
        flowerTag = ORANGE_FLOWER_TAG;
        flowerMass = 2.0f;
    }
   
    float scale = 0.1f;
    Flower *flower = [Flower spriteWithFile:flowerPath];
    flower.position = pos;
    if ((xVel < 10) && (xVel >=0)) {xVel = 10;}
    if ((xVel > -10) && (xVel <=0)) {xVel = -10;}
    if ((yVel < 10) && (yVel >=0)) {yVel = 10;}
    if ((yVel > -10) && (yVel <=0)) {yVel = -10;}
    CGPoint initialVelocity = CGPointMake(xVel, yVel);
    flower.vel = initialVelocity;
    flower.acc = ccp(0,0);
    flower.mass = flowerMass;
    flower.radius = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 1 : 0.5)
                    * flower.boundingBox.size.width * scale;
    flower.rot = random() / 0x30000000 - 0.5;
    flower.scale = scale;
    flower.tag = flowerTag;
    CCLOG(@"HWL/makeFlower   count:%3d, x:%6.1f, y:%6.1f, xVel:%6.1f, yVel:%6.1f, color:%@",
          blueFlowerCount, flower.position.x, flower.position.y, flower.vel.x, flower.vel.y, flowerColor);
    return flower;
}

- (void) dealloc {
    [_flowers release]; _flowers = nil;
	[super dealloc];
}

@end
