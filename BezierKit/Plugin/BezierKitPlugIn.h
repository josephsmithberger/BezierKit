//
//  BezierKitPlugIn.h
//  BezierKit
//
//  Created by Joseph Smithberger on 11/21/25.
//

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>

@interface BezierKitPlugIn : NSObject <FxTileableEffect>
@property (assign) id<PROAPIAccessing> apiManager;
@end
