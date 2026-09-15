#import "UIView+SecureView.h"

static void applyMaskToLayer(CALayer *layer, NSString *key, NSInteger mask) {
    if (!layer || !key) return;
    if ([layer respondsToSelector:NSSelectorFromString(key)]) {
        [layer setValue:@(mask) forKey:key];
    }
    for (CALayer *sub in layer.sublayers) {
        applyMaskToLayer(sub, key, mask);
    }
}

@implementation UIView (SecureView)

- (BOOL)hideViewFromCapture:(BOOL)hide
{
    static dispatch_once_t onceToken;
    static NSString *propertyString;
    
    dispatch_once(&onceToken, ^{
        NSString *propertyBase64 = @"ZGlzYWJsZVVwZGF0ZU1hc2s="; /* "disableUpdateMask" encoded in base64 */
        NSData *propertyData = [[NSData alloc] initWithBase64EncodedString:propertyBase64
                                                               options:NSDataBase64DecodingIgnoreUnknownCharacters];
        if (propertyData) {
            propertyString = [[NSString alloc] initWithData:propertyData encoding:NSUTF8StringEncoding];
        }
    });

    if (!propertyString || ![self.layer respondsToSelector:NSSelectorFromString(propertyString)])
    {
        return NO;
    }
    
    // Mask 18 ( (1<<1) | (1<<4) ) hides from screenshots/recording
    NSInteger mask = hide ? 18 : 0;
    applyMaskToLayer(self.layer, propertyString, mask);
    return YES;
}

- (BOOL)showViewForCapture
{
    return [self hideViewFromCapture:NO];
}

@end
