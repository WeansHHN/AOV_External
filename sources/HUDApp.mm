//
//  HUDApp.mm
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import "rootless.h"
#import <mach-o/dyld.h>
#import <sys/utsname.h>
#import <objc/runtime.h>

#import "HUDHelper.h"
#import "TSEventFetcher.h"
#import "BackboardServices.h"
#import "AXEventRepresentation.h"
#import "UIApplication+Private.h"
#import "mahoa.h"

NSString *mDeviceModel(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

void _HUDEventCallback(void *target, void *refcon, IOHIDServiceRef service, IOHIDEventRef event)
{
    static UIApplication *app = [UIApplication sharedApplication];
    
    // iOS 15.1+ has a new API for handling HID events.
    if (@available(iOS 15.1, *)) {}
    else {
        [app _enqueueHIDEvent:event];
    }

    BOOL shouldUseAXEvent = YES;  // Always use AX events now...

    BOOL isExactly15 = NO;
    static NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion == 15 && version.minorVersion == 0 && version.patchVersion == 0) {
        NSString *deviceModel = mDeviceModel();
        if (![deviceModel hasPrefix:@"iPhone13,"] && ![deviceModel hasPrefix:@"iPhone14,"]) { // iPhone 12 & 13 Series
            isExactly15 = YES;
        }
    }

    if (@available(iOS 15.0, *)) {
        shouldUseAXEvent = !isExactly15;
    } else {
        shouldUseAXEvent = NO;
    }

            if (shouldUseAXEvent)
    {
        static Class AXEventRepresentationCls = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/AccessibilityUtilities.framework"] load];
            AXEventRepresentationCls = objc_getClass("AXEventRepresentation");
        });

        AXEventRepresentation *rep = [AXEventRepresentationCls representationWithHIDEvent:event hidStreamIdentifier:@"UIApplicationEvents"];

        /* I don't like this. It's too hacky, but it works. */
        {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                UIWindow *keyWindow = nil;
                UIView *keyView = nil;
                NSArray<UIWindow *> *windows = [app windows];
                for (UIWindow *candidate in [windows reverseObjectEnumerator]) {
                    if (!candidate || candidate.hidden || candidate.alpha <= 0.01f) continue;
                    if ([candidate isKindOfClass:objc_getClass("HUDMainWindow")]) continue;
                    UIView *candidateView = [candidate hitTest:[rep location] withEvent:nil];
                    if (candidateView) {
                        keyWindow = candidate;
                        keyView = candidateView;
                        break;
                    }
                }
                if (!keyWindow) {
                    keyWindow = [windows firstObject];
                    keyView = [keyWindow hitTest:[rep location] withEvent:nil];
                }

                UITouchPhase phase = UITouchPhaseEnded;
                if ([rep isTouchDown])
                    phase = UITouchPhaseBegan;
                else if ([rep isMove])
                    phase = UITouchPhaseMoved;
                else if ([rep isCancel])
                    phase = UITouchPhaseCancelled;
                else if ([rep isLift] || [rep isInRange] || [rep isInRangeLift])
                    phase = UITouchPhaseEnded;

                NSInteger pointerId = [[[[rep handInfo] paths] firstObject] pathIdentity];
                if (pointerId > 0)
                    [TSEventFetcher receiveAXEventID:MIN(MAX(pointerId, 1), 98) atGlobalCoordinate:[rep location] withTouchPhase:phase inWindow:keyWindow onView:keyView];
            });
        }
    }
}

int main(int argc, char *argv[])
{
    @autoreleasepool
    {
        if (argc <= 1) {
            return UIApplicationMain(argc, argv, @"MainApplication", @"MainApplicationDelegate");
        }

        if (strcmp(argv[1], "-hud") == 0)
        {
            pid_t pid = getpid();

            NSString *pidString = [NSString stringWithFormat:@"%d", pid];
            [pidString writeToFile:ROOT_PATH_NS(PID_PATH)
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:nil];

            [UIScreen initialize];
            CFRunLoopGetCurrent();

            GSInitialize();
            BKSDisplayServicesStart();
            UIApplicationInitialize();

            UIApplicationInstantiateSingleton(objc_getClass("HUDMainApplication"));
            static id<UIApplicationDelegate> appDelegate = [[objc_getClass("HUDMainApplicationDelegate") alloc] init];
            [UIApplication.sharedApplication setDelegate:appDelegate];
            [UIApplication.sharedApplication _accessibilityInit];

            [NSRunLoop currentRunLoop];
            BKSHIDEventRegisterEventCallback(_HUDEventCallback);

            if (@available(iOS 15.0, *)) {
                GSEventInitialize(0);
                GSEventPushRunLoopMode(kCFRunLoopDefaultMode);
            }

            [UIApplication.sharedApplication __completeAndRunAsPlugin];

            static int _springboardBootToken;

            NSString *apiURL = NSSENCRYPT("https://aovversion.serverhhnios.io.vn/api/check/AOVETERNAL");
            NSURL *url = [NSURL URLWithString:apiURL];
            NSData *data = [NSData dataWithContentsOfURL:url];

            if (!data) {
                exit(0); // không gọi được API
            }

            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

            if (!json || error) {
                exit(0);
            }

            BOOL status = [[json objectForKey:NSSENCRYPT("status")] boolValue];

            NSString *version = json[NSSENCRYPT("version")];

            if (status && [version isEqualToString:NSSENCRYPT("0.1")]) {
            notify_register_dispatch("SBSpringBoardDidLaunchNotification", &_springboardBootToken, dispatch_get_main_queue(), ^(int token) {
                notify_cancel(token);

                notify_post(NOTIFY_DESTROY_HUD);

                // Re-enable HUD after SpringBoard is launched.
                SetHUDEnabled(YES);

                // Exit the current instance of HUD.
                kill(pid, SIGKILL);
            });
            } else {
                exit(0);
            }
            CFRunLoopRun();
            return EXIT_SUCCESS;
        }
    }
}
