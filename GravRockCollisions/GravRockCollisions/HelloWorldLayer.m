//
//  HelloWorldLayer.m
//  GravRockCollisions
//
//  Created by Justin Shacklette on 9/6/12.
//  Copyright Saturnboy 2012. All rights reserved.
//

#import "HelloWorldLayer.h"
#import "AppDelegate.h"
#import "Flower.h"

#define PX_TO_M (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 50 : 25)
#define BOUNCE_RESTITUTION 1.0f
#define ACCELEROMETER_INTERP_FACTOR 0.1f
#define MAX_ROCKS 20

@interface HelloWorldLayer()
@property (assign) BOOL isFingerDown;
@property (retain) CCSprite *demonBar;
@end

#pragma mark - HelloWorldLayer

@implementation HelloWorldLayer

+(CCScene *) scene {
	CCScene *scene = [CCScene node];
	HelloWorldLayer *layer = [HelloWorldLayer node];
	[scene addChild: layer];
	return scene;
}

-(id) init {
	if( (self=[super init]) ) {
        blueFlowerCount = 0;
        orangeFlowerCount = 0;
        
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
        CCSprite *greenBackground = [CCSprite spriteWithFile:@"Background Green 480x320.png"];
        [greenBackground setPosition:ccp((_winsize.height / 2), (_winsize.width / 2))];
        [self addChild:greenBackground z:0];
        
        // add the demon bar in the middle of the screen
        CCSprite *demonBar = [CCSprite spriteWithFile:@"Demon Bar.png"];
        [demonBar setPosition:ccp((_winsize.height) / 2, (_winsize.width / 2))];
        self.demonBar = demonBar;
        
        // load texture
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:texturePlist];
        CCSpriteBatchNode *sheet = [CCSpriteBatchNode batchNodeWithFile:textureFile];
        [self addChild:sheet];
        
        // init rocks array
        _rocks = [[CCArray alloc] initWithCapacity:MAX_ROCKS];    
        
//        // init arrow
//        _arrow = [CCSprite spriteWithSpriteFrameName:@"arrow.png"];
//        _arrow.position = ccp(_winsize.width/2, _winsize.height/2);
//        _arrow.anchorPoint = ccp(0.25f,0.5f);
//        [self addChild:_arrow z:2 tag:234];

        [self scheduleUpdate];
	}
	return self;
}

- (void) update:(ccTime)dt {
    Flower *rock;
    int i = 0;
    CCARRAY_FOREACH(_rocks, rock) {
        // velocity verlet
        rock.position = ccpAdd(ccpAdd(rock.position, ccpMult(rock.vel, dt)), ccpMult(rock.acc, dt*dt));
        rock.vel = ccpAdd(rock.vel, ccpMult(rock.acc, dt));
        rock.rotation = rock.rotation + rock.rot;

        // bounce the rock off the walls
        if (rock.position.y < rock.radius) {
            rock.position = ccp(rock.position.x, rock.radius);
            rock.vel = ccp(rock.vel.x, -rock.vel.y * BOUNCE_RESTITUTION);
        }
        if (rock.position.y > (_winsize.height - rock.radius)) {
            rock.position = ccp(rock.position.x, _winsize.height - rock.radius);
            rock.vel = ccp(rock.vel.x, -rock.vel.y * BOUNCE_RESTITUTION); 
        }
        if (rock.position.x < rock.radius) {
            rock.position = ccp(rock.radius, rock.position.y); 
            rock.vel = ccp(-rock.vel.x * BOUNCE_RESTITUTION, rock.vel.y); 
        }
        if (rock.position.x > _winsize.width - rock.radius) {
            rock.position = ccp(_winsize.width - rock.radius, rock.position.y); 
            rock.vel = ccp(-rock.vel.x * BOUNCE_RESTITUTION, rock.vel.y);
        }
        
        // collide with other rocks
        for (int j = i + 1; j < _rocks.count; j++) {
            Flower *rock2 = [_rocks objectAtIndex:j];
            
            CGPoint delta = ccpSub(rock.position, rock2.position);
            
            // assume rocks are circles to make collision math easy
            float collisionDistSQ = (rock.radius + rock2.radius) * (rock.radius + rock2.radius);
            float distSQ = ccpDot(delta, delta);
            //CCLOG(@"before pos: (%.3f,%.3f) (%.3f,%.3f)",rock.position.x,rock.position.y,rock2.position.x,rock2.position.y);                       
            //CCLOG(@"before vel: (%.3f,%.3f) (%.3f,%.3f)",rock.vel.x,rock.vel.y,rock2.vel.x,rock2.vel.y);
            if (distSQ <= collisionDistSQ) {  
                // compute separation vector -- distance need to push rocks appart
                float d = ccpLength(delta);
                CGPoint sep = ccpMult(delta, ((rock.radius + rock2.radius) - d)/d);
                
                // compute sum of masses
                float sum = rock.mass + rock2.mass;
                
                // pull both rocks apart weighted by their mass
                rock.position = ccpAdd(rock.position, ccpMult(sep, rock2.mass / sum));
                rock2.position = ccpSub(rock2.position, ccpMult(sep, rock.mass / sum));
                
                // compute normal unit and tangential unit vectors
                CGPoint normUnit = ccpNormalize(sep);
                CGPoint tanUnit = ccpPerp(normUnit);
                
                // project v1 & v2 into normal & tangential space
                CGPoint v = ccp(ccpDot(normUnit, rock.vel), ccpDot(tanUnit, rock.vel));
                CGPoint v2 = ccp(ccpDot(normUnit, rock2.vel), ccpDot(tanUnit, rock2.vel));
                
                // tangential is preserved, normal is elastic collision
                CGPoint vFinal = ccp( (BOUNCE_RESTITUTION * rock2.mass * (v2.x - v.x) + rock.mass * v.x + rock2.mass * v2.x) / sum, v.y);
                CGPoint v2Final = ccp( (BOUNCE_RESTITUTION * rock.mass * (v.x - v2.x) + rock.mass * v.x + rock2.mass * v2.x) / sum, v2.y);
                
                // project back to real space
                CGPoint vBackN = ccpMult(normUnit, vFinal.x);
                CGPoint vBackT = ccpMult(tanUnit, vFinal.y);
                CGPoint v2BackN = ccpMult(normUnit, v2Final.x);
                CGPoint v2BackT = ccpMult(tanUnit, v2Final.y);
                
                // sum Normal + Tangential velocities to get the final velocity
                rock.vel = ccpAdd(vBackN, vBackT);
                rock2.vel = ccpAdd(v2BackN, v2BackT);
            }
            
            //CCLOG(@"after pos: (%.3f,%.3f) (%.3f,%.3f)",rock.position.x,rock.position.y,rock2.position.x,rock2.position.y);                       
            //CCLOG(@"after vel: (%.3f,%.3f) (%.3f,%.3f)",rock.vel.x,rock.vel.y,rock2.vel.x,rock2.vel.y);
        }
        
        i++;
    }
}

- (void) accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {    
    _accelerometer = ccpLerp(_accelerometer, ccp(-acceleration.x, -acceleration.y), ACCELEROMETER_INTERP_FACTOR);
    float angle = -CC_RADIANS_TO_DEGREES(ccpToAngle(_accelerometer));
    CCLOG(@"ang=%.3f mag=%.5f", angle, ccpLength(_accelerometer));
    
    // rotate arrow
    _arrow.rotation = angle + 180.0f;

    // update gravity on each rock
    CGPoint grav = ccpMult(_accelerometer, -10.0f * PX_TO_M);
    Flower *rock;
    CCARRAY_FOREACH(_rocks, rock) {
        rock.acc = grav;
    }
}

# pragma mark - Demon Bar Management
-(void) showDemonBar {
    [self addChild:self.demonBar z:1];
    self.isFingerDown = YES;
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
    CCLOG(@"Orange Flower: count %d, x %f, y%f",
          orangeFlowerCount, flower.position.x, flower.position.y);

    return flower;
}

-(Flower *) makeRock:(CGPoint)pos {
    int rockSize = random() % 3;
    if ( rockSize < 1 ) return [self makeBlueFlower:(pos)];
    if ( rockSize < 2 ) return [self makeOrangeFlower:(pos)];
    NSLog(@"rockSize: %d", rockSize);
    return [self makeBlueFlower:pos];
}

- (void) dealloc {
    [_rocks release]; _rocks = nil;
	[super dealloc];
}

@end
