//
//  HUDMainWindow.mm
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import "HUDMainWindow.h"

@implementation HUDMainWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_isSecure { return NO; }
- (BOOL)_shouldCreateContextAsSecure { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event { return NO; }

@end
