//
//  BezierKitPlugIn.m
//  BezierKit
//
//  Created by Joseph Smithberger on 11/21/25.
//

#import "BezierKitPlugIn.h"
#import <IOSurface/IOSurfaceObjC.h>
#import "TileableRemoteBrightnessShaderTypes.h"
#import "MetalDeviceCache.h"
#import <math.h>

// Parameter IDs
enum {
    kParamID_Progress = 1,
    kParamID_EasingType,
    kParamID_StartPosX,
    kParamID_StartPosY,
    kParamID_EndPosX,
    kParamID_EndPosY,
    kParamID_StartScale,
    kParamID_EndScale,
    kParamID_StartRotation,
    kParamID_EndRotation,
    kParamID_StartOpacity,
    kParamID_EndOpacity
};

// Easing Types
enum {
    kEasingType_Linear = 0,
    kEasingType_EaseInQuad,
    kEasingType_EaseOutQuad,
    kEasingType_EaseInOutQuad,
    kEasingType_EaseInCubic,
    kEasingType_EaseOutCubic,
    kEasingType_EaseInOutCubic,
    kEasingType_EaseInBack,
    kEasingType_EaseOutBack,
    kEasingType_EaseInOutBack,
    kEasingType_EaseInBounce,
    kEasingType_EaseOutBounce,
    kEasingType_EaseInOutBounce
};

typedef struct {
    double progress;
    int easingType;
    double startPosX, startPosY;
    double endPosX, endPosY;
    double startScale, endScale;
    double startRotation, endRotation;
    double startOpacity, endOpacity;
} PluginState;

static double applyEasing(int type, double t);

@implementation BezierKitPlugIn

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- (nullable instancetype)initWithAPIManager:(id<PROAPIAccessing>)newApiManager;
{
    self = [super init];
    if (self != nil)
    {
        _apiManager = newApiManager;
    }
    return self;
}

//---------------------------------------------------------
// properties
//
// This method should return an NSDictionary defining the
// properties of the effect.
//---------------------------------------------------------

- (BOOL)properties:(NSDictionary * _Nonnull *)properties
             error:(NSError * _Nullable *)error
{
    *properties = @{
                    kFxPropertyKey_MayRemapTime : [NSNumber numberWithBool:NO],
                    kFxPropertyKey_PixelTransformSupport : [NSNumber numberWithInt:kFxPixelTransform_ScaleTranslate],
                    kFxPropertyKey_VariesWhenParamsAreStatic : [NSNumber numberWithBool:NO]
                    };
    
    return YES;
}

//---------------------------------------------------------
// addParametersWithError
//
// This method is where a plug-in defines its list of parameters.
//---------------------------------------------------------

- (BOOL)addParametersWithError:(NSError**)error
{
    id<FxParameterCreationAPI_v5>   paramAPI    = [_apiManager apiForProtocol:@protocol(FxParameterCreationAPI_v5)];
    if (paramAPI == nil)
    {
        NSDictionary*   userInfo    = @{
                                        NSLocalizedDescriptionKey : @"Unable to obtain an FxPlug API Object"
                                        };
        if (error != NULL)
            *error = [NSError errorWithDomain:FxPlugErrorDomain
                                         code:kFxError_APIUnavailable
                                     userInfo:userInfo];
        
        return NO;
    }
    
    [paramAPI addFloatSliderWithName:@"Progress" parameterID:kParamID_Progress defaultValue:0.0 parameterMin:0.0 parameterMax:100.0 sliderMin:0.0 sliderMax:100.0 delta:0.1 parameterFlags:kFxParameterFlag_DEFAULT];

    NSArray *menuEntries = @[@"Linear", @"Ease In Quad", @"Ease Out Quad", @"Ease In Out Quad", @"Ease In Cubic", @"Ease Out Cubic", @"Ease In Out Cubic", @"Ease In Back", @"Ease Out Back", @"Ease In Out Back", @"Ease In Bounce", @"Ease Out Bounce", @"Ease In Out Bounce"];
    [paramAPI addPopupMenuWithName:@"Easing Type" parameterID:kParamID_EasingType defaultValue:kEasingType_EaseInOutQuad menuEntries:menuEntries parameterFlags:kFxParameterFlag_DEFAULT];

    [paramAPI startParameterSubGroup:@"Start Transform" parameterID:100 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"Start Position X" parameterID:kParamID_StartPosX defaultValue:0.0 parameterMin:-4000.0 parameterMax:4000.0 sliderMin:-1000.0 sliderMax:1000.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"Start Position Y" parameterID:kParamID_StartPosY defaultValue:0.0 parameterMin:-4000.0 parameterMax:4000.0 sliderMin:-1000.0 sliderMax:1000.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"Start Scale" parameterID:kParamID_StartScale defaultValue:100.0 parameterMin:0.0 parameterMax:1000.0 sliderMin:0.0 sliderMax:200.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"Start Rotation" parameterID:kParamID_StartRotation defaultValue:0.0 parameterMin:-3600.0 parameterMax:3600.0 sliderMin:-180.0 sliderMax:180.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"Start Opacity" parameterID:kParamID_StartOpacity defaultValue:100.0 parameterMin:0.0 parameterMax:100.0 sliderMin:0.0 sliderMax:100.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI endParameterSubGroup];

    [paramAPI startParameterSubGroup:@"End Transform" parameterID:200 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"End Position X" parameterID:kParamID_EndPosX defaultValue:0.0 parameterMin:-4000.0 parameterMax:4000.0 sliderMin:-1000.0 sliderMax:1000.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"End Position Y" parameterID:kParamID_EndPosY defaultValue:0.0 parameterMin:-4000.0 parameterMax:4000.0 sliderMin:-1000.0 sliderMax:1000.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"End Scale" parameterID:kParamID_EndScale defaultValue:100.0 parameterMin:0.0 parameterMax:1000.0 sliderMin:0.0 sliderMax:200.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"End Rotation" parameterID:kParamID_EndRotation defaultValue:0.0 parameterMin:-3600.0 parameterMax:3600.0 sliderMin:-180.0 sliderMax:180.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI addFloatSliderWithName:@"End Opacity" parameterID:kParamID_EndOpacity defaultValue:100.0 parameterMin:0.0 parameterMax:100.0 sliderMin:0.0 sliderMax:100.0 delta:1.0 parameterFlags:kFxParameterFlag_DEFAULT];
    [paramAPI endParameterSubGroup];
    
    return YES;
}

//---------------------------------------------------------
// pluginState:atTime:quality:error
//
// Your plug-in should get its parameter values, do any calculations it needs to
// from those values, and package up the result to be used later with rendering.
// The host application will call this method before rendering. The
// FxParameterRetrievalAPI* is valid during this call. Use it to get the values of
// your plug-in's parameters, then put those values or the results of any calculations
// you need to do with those parameters to render into an NSData that you return
// to the host application. The host will pass it back to you during subsequent calls.
// Do not re-use the NSData; always create a new one as this method may be called
// on multiple threads at the same time.
//---------------------------------------------------------

- (BOOL)pluginState:(NSData**)pluginState
             atTime:(CMTime)renderTime
            quality:(FxQuality)qualityLevel
              error:(NSError**)error
{
    BOOL    succeeded = NO;
    id<FxParameterRetrievalAPI_v6>  paramGetAPI = [_apiManager apiForProtocol:@protocol(FxParameterRetrievalAPI_v6)];
    if (paramGetAPI != nil)
    {
        PluginState state;
        [paramGetAPI getFloatValue:&state.progress fromParameter:kParamID_Progress atTime:renderTime];
        int easingTypeInt;
        [paramGetAPI getIntValue:&easingTypeInt fromParameter:kParamID_EasingType atTime:renderTime];
        state.easingType = easingTypeInt;
        
        [paramGetAPI getFloatValue:&state.startPosX fromParameter:kParamID_StartPosX atTime:renderTime];
        [paramGetAPI getFloatValue:&state.startPosY fromParameter:kParamID_StartPosY atTime:renderTime];
        [paramGetAPI getFloatValue:&state.endPosX fromParameter:kParamID_EndPosX atTime:renderTime];
        [paramGetAPI getFloatValue:&state.endPosY fromParameter:kParamID_EndPosY atTime:renderTime];
        
        [paramGetAPI getFloatValue:&state.startScale fromParameter:kParamID_StartScale atTime:renderTime];
        [paramGetAPI getFloatValue:&state.endScale fromParameter:kParamID_EndScale atTime:renderTime];
        
        [paramGetAPI getFloatValue:&state.startRotation fromParameter:kParamID_StartRotation atTime:renderTime];
        [paramGetAPI getFloatValue:&state.endRotation fromParameter:kParamID_EndRotation atTime:renderTime];
        
        [paramGetAPI getFloatValue:&state.startOpacity fromParameter:kParamID_StartOpacity atTime:renderTime];
        [paramGetAPI getFloatValue:&state.endOpacity fromParameter:kParamID_EndOpacity atTime:renderTime];
        
        *pluginState = [NSData dataWithBytes:&state length:sizeof(state)];
        if (*pluginState != nil) succeeded = YES;
    }
    else
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:FxPlugErrorDomain
                                         code:kFxError_ThirdPartyDeveloperStart + 20
                                     userInfo:@{
                                                NSLocalizedDescriptionKey :
                                                    @"Unable to retrieve FxParameterRetrievalAPI_v6 in \
                                                    [-pluginStateAtTime:]" }];
    }
    
    return succeeded;
}

//---------------------------------------------------------
// destinationImageRect:sourceImages:destinationImage:pluginState:atTime:error
//
// This method will calculate the rectangular bounds of the output
// image given the various inputs and plug-in state
// at the given render time.
// It will pass in an array of images, the plug-in state
// returned from your plug-in's -pluginStateAtTime:error: method,
// and the render time.
//---------------------------------------------------------

- (BOOL)destinationImageRect:(FxRect *)destinationImageRect
                sourceImages:(NSArray<FxImageTile *> *)sourceImages
            destinationImage:(nonnull FxImageTile *)destinationImage
                 pluginState:(NSData *)pluginState
                      atTime:(CMTime)renderTime
                       error:(NSError * _Nullable *)outError
{
    if (sourceImages.count < 1)
    {
        NSLog (@"No inputImages list");
        return NO;
    }
    
    // In the case of a filter that only changed RGB values,
    // the output rect is the same as the input rect.
    *destinationImageRect = sourceImages [ 0 ].imagePixelBounds;
    
    return YES;
    
}

//---------------------------------------------------------
// sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginState:atTime:error
//
// Calculate tile of the source image we need
// to render the given output tile.
//---------------------------------------------------------

- (BOOL)sourceTileRect:(FxRect *)sourceTileRect
      sourceImageIndex:(NSUInteger)sourceImageIndex
          sourceImages:(NSArray<FxImageTile *> *)sourceImages
   destinationTileRect:(FxRect)destinationTileRect
      destinationImage:(FxImageTile *)destinationImage
           pluginState:(NSData *)pluginState
                atTime:(CMTime)renderTime
                 error:(NSError * _Nullable *)outError
{
    if (pluginState == nil) return NO;
    
    PluginState state;
    [pluginState getBytes:&state length:sizeof(state)];
    
    double t = state.progress / 100.0;
    double easedT = applyEasing(state.easingType, t);
    
    double currentPosX = state.startPosX + (state.endPosX - state.startPosX) * easedT;
    double currentPosY = state.startPosY + (state.endPosY - state.startPosY) * easedT;
    double currentScale = state.startScale + (state.endScale - state.startScale) * easedT;
    double currentRotation = state.startRotation + (state.endRotation - state.startRotation) * easedT;
    
    // Inverse transform:
    // v = ScaleInv(RotateInv(v' - Pos))
    
    double scaleFactor = currentScale / 100.0;
    if (scaleFactor < 0.001) scaleFactor = 0.001;
    double invScale = 1.0 / scaleFactor;
    
    // In renderDestinationImage, we used rotationRad = -currentRotation * ...
    // So we rotated by -currentRotation.
    // Inverse rotation is +currentRotation.
    double rotRad = currentRotation * M_PI / 180.0;
    
    double cosR = cos(rotRad);
    double sinR = sin(rotRad);
    
    // Destination corners
    double l = destinationTileRect.left;
    double r = destinationTileRect.right;
    double b = destinationTileRect.bottom;
    double top = destinationTileRect.top;
    
    struct Point { double x, y; };
    struct Point corners[4] = { {l, b}, {r, b}, {r, top}, {l, top} };
    
    double minX = 1e15, minY = 1e15, maxX = -1e15, maxY = -1e15;
    
    for (int i=0; i<4; i++) {
        // Translate
        double x = corners[i].x - currentPosX;
        double y = corners[i].y - currentPosY;
        
        // Rotate
        double rx = x * cosR - y * sinR;
        double ry = x * sinR + y * cosR;
        
        // Scale
        double sx = rx * invScale;
        double sy = ry * invScale;
        
        if (sx < minX) minX = sx;
        if (sx > maxX) maxX = sx;
        if (sy < minY) minY = sy;
        if (sy > maxY) maxY = sy;
    }
    
    sourceTileRect->left = (int)floor(minX);
    sourceTileRect->right = (int)ceil(maxX);
    sourceTileRect->bottom = (int)floor(minY);
    sourceTileRect->top = (int)ceil(maxY);
    
    return YES;
}

static double applyEasing(int type, double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    
    switch (type) {
        case kEasingType_Linear: return t;
        case kEasingType_EaseInQuad: return t * t;
        case kEasingType_EaseOutQuad: return t * (2 - t);
        case kEasingType_EaseInOutQuad: return t < .5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
        case kEasingType_EaseInCubic: return t * t * t;
        case kEasingType_EaseOutCubic: t = t - 1; return t * t * t + 1;
        case kEasingType_EaseInOutCubic: return t < .5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
        case kEasingType_EaseInBack: {
            double s = 1.70158;
            return t * t * ((s + 1) * t - s);
        }
        case kEasingType_EaseOutBack: {
            double s = 1.70158;
            t = t - 1;
            return t * t * ((s + 1) * t + s) + 1;
        }
        case kEasingType_EaseInOutBack: {
            double s = 1.70158 * 1.525;
            t = t * 2;
            if (t < 1) return 0.5 * (t * t * ((s + 1) * t - s));
            t = t - 2;
            return 0.5 * (t * t * ((s + 1) * t + s) + 2);
        }
        case kEasingType_EaseInBounce: return 1 - applyEasing(kEasingType_EaseOutBounce, 1 - t);
        case kEasingType_EaseOutBounce: {
            if (t < (1/2.75)) {
                return (7.5625 * t * t);
            } else if (t < (2/2.75)) {
                t = t - (1.5/2.75);
                return (7.5625 * t * t + 0.75);
            } else if (t < (2.5/2.75)) {
                t = t - (2.25/2.75);
                return (7.5625 * t * t + 0.9375);
            } else {
                t = t - (2.625/2.75);
                return (7.5625 * t * t + 0.984375);
            }
        }
        case kEasingType_EaseInOutBounce: {
            if (t < 0.5) return applyEasing(kEasingType_EaseInBounce, t * 2) * 0.5;
            return applyEasing(kEasingType_EaseOutBounce, t * 2 - 1) * 0.5 + 0.5;
        }
    }
    return t;
}

//---------------------------------------------------------
// renderDestinationImage:sourceImages:pluginState:atTime:error:
//
// The host will call this method when it wants your plug-in to render an image
// tile of the output image. It will pass in each of the input tiles needed as well
// as the plug-in state needed for the calculations. Your plug-in should do all its
// rendering in this method. It should not attempt to use the FxParameterRetrievalAPI*
// object as it is invalid at this time. Note that this method will be called on
// multiple threads at the same time.
//---------------------------------------------------------

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
                  sourceImages:(NSArray<FxImageTile *> *)sourceImages
                   pluginState:(NSData *)pluginState
                        atTime:(CMTime)renderTime
                         error:(NSError * _Nullable *)outError
{
    if ((pluginState == nil) || (sourceImages [ 0 ].ioSurface == nil) || (destinationImage.ioSurface == nil))
    {
        NSDictionary*   userInfo    = @{
                                        NSLocalizedDescriptionKey : @"Invalid plugin state received from host"
                                        };
        if (outError != NULL)
            *outError = [NSError errorWithDomain:FxPlugErrorDomain
                                            code:kFxError_InvalidParameter
                                        userInfo:userInfo];
        return NO;
    }
    
    PluginState state;
    [pluginState getBytes:&state length:sizeof(state)];
    
    double t = state.progress / 100.0;
    double easedT = applyEasing(state.easingType, t);
    
    double currentPosX = state.startPosX + (state.endPosX - state.startPosX) * easedT;
    double currentPosY = state.startPosY + (state.endPosY - state.startPosY) * easedT;
    double currentScale = state.startScale + (state.endScale - state.startScale) * easedT;
    double currentRotation = state.startRotation + (state.endRotation - state.startRotation) * easedT;
    double currentOpacity = state.startOpacity + (state.endOpacity - state.startOpacity) * easedT;
    
    double rotationRad = -currentRotation * M_PI / 180.0; // Negative to match expected rotation direction usually
    double scaleFactor = currentScale / 100.0;
    float opacityFactor = (float)(currentOpacity / 100.0);
    
    MetalDeviceCache*  deviceCache     = [MetalDeviceCache deviceCache];
    MTLPixelFormat     pixelFormat     = [MetalDeviceCache MTLPixelFormatForImageTile:destinationImage];
    id<MTLCommandQueue> commandQueue   = [deviceCache commandQueueWithRegistryID:sourceImages[0].deviceRegistryID
                                                                     pixelFormat:pixelFormat];
    if (commandQueue == nil)
    {
        return NO;
    }
    
    id<MTLCommandBuffer>    commandBuffer   = [commandQueue commandBuffer];
    commandBuffer.label = @"DynamicRegXPC Command Buffer";
    [commandBuffer enqueue];
    
    id<MTLTexture>  inputTexture    = [sourceImages[0] metalTextureForDevice:[deviceCache deviceWithRegistryID:sourceImages[0].deviceRegistryID]];
    id<MTLTexture>  outputTexture   = [destinationImage metalTextureForDevice:[deviceCache deviceWithRegistryID:destinationImage.deviceRegistryID]];
    
    MTLRenderPassColorAttachmentDescriptor* colorAttachmentDescriptor   = [[MTLRenderPassColorAttachmentDescriptor alloc] init];
    colorAttachmentDescriptor.texture = outputTexture;
    colorAttachmentDescriptor.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0); // Clear to transparent
    colorAttachmentDescriptor.loadAction = MTLLoadActionClear;
    MTLRenderPassDescriptor*    renderPassDescriptor    = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments [ 0 ] = colorAttachmentDescriptor;
    id<MTLRenderCommandEncoder>   commandEncoder  = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    // Rendering
    float   outputWidth     = (float)(destinationImage.tilePixelBounds.right - destinationImage.tilePixelBounds.left);
    float   outputHeight    = (float)(destinationImage.tilePixelBounds.top - destinationImage.tilePixelBounds.bottom);
    
    float halfW = outputWidth / 2.0;
    float halfH = outputHeight / 2.0;
    
    float cosR = cos(rotationRad);
    float sinR = sin(rotationRad);
    
    vector_float2 (^transform)(float, float) = ^(float x, float y) {
        float sx = x * scaleFactor;
        float sy = y * scaleFactor;
        float rx = sx * cosR - sy * sinR;
        float ry = sx * sinR + sy * cosR;
        return (vector_float2){ (float)(rx + currentPosX), (float)(ry + currentPosY) };
    };
    
    Vertex2D    vertices[4];
    // BR
    vertices[0].position = transform(halfW, -halfH);
    vertices[0].textureCoordinate = (vector_float2){ 1.0, 1.0 };
    // BL
    vertices[1].position = transform(-halfW, -halfH);
    vertices[1].textureCoordinate = (vector_float2){ 0.0, 1.0 };
    // TR
    vertices[2].position = transform(halfW, halfH);
    vertices[2].textureCoordinate = (vector_float2){ 1.0, 0.0 };
    // TL
    vertices[3].position = transform(-halfW, halfH);
    vertices[3].textureCoordinate = (vector_float2){ 0.0, 0.0 };
    
    MTLViewport viewport    = {
        0, 0, outputWidth, outputHeight, -1.0, 1.0
    };
    [commandEncoder setViewport:viewport];
    
    id<MTLRenderPipelineState>  pipelineState  = [deviceCache pipelineStateWithRegistryID:sourceImages[0].deviceRegistryID
                                                                              pixelFormat:pixelFormat];
    [commandEncoder setRenderPipelineState:pipelineState];
    
    [commandEncoder setVertexBytes:vertices
                            length:sizeof(vertices)
                           atIndex:BVI_Vertices];
    
    simd_uint2  viewportSize = {
        (unsigned int)(outputWidth),
        (unsigned int)(outputHeight)
    };
    [commandEncoder setVertexBytes:&viewportSize
                            length:sizeof(viewportSize)
                           atIndex:BVI_ViewportSize];
    
    [commandEncoder setFragmentTexture:inputTexture
                               atIndex:BTI_InputImage];
    
    [commandEncoder setFragmentBytes:&opacityFactor
                              length:sizeof(opacityFactor)
                             atIndex:BFI_Opacity];
    
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                       vertexStart:0
                       vertexCount:4];
    
    [commandEncoder endEncoding];
    [commandBuffer commit];
    
    [commandBuffer waitUntilCompleted];
    
    [colorAttachmentDescriptor release];
    
    [deviceCache returnCommandQueueToCache:commandQueue];
    
    return YES;
    
}

@end
