#import "cfg.h"
#import "esp.h"
#import <notify.h>

NSString * const ESPSettingBox           = @"esp_box_enabled";
NSString * const ESPSettingBoxOutline    = @"esp_box_outline";
NSString * const ESPSettingBoxFill       = @"esp_box_fill";
NSString * const ESPSettingLine          = @"esp_line_enabled";
NSString * const ESPSettingLineOutline   = @"esp_line_outline";
NSString * const ESPSettingName          = @"esp_name_enabled";
NSString * const ESPSettingHeroIcon      = @"esp_icon_enabled";
NSString * const ESPSettingMiniMap       = @"esp_minimap_enabled";
NSString * const ESPSettingMiniMapPosX   = @"esp_minimap_pos_x";
NSString * const ESPSettingMiniMapPosY   = @"esp_minimap_pos_y";
NSString * const ESPSettingMiniMapSize   = @"esp_minimap_size";
NSString * const ESPSettingMiniMapIconSize = @"esp_minimap_icon_size";
NSString * const ESPSettingHealthText    = @"esp_health_enabled";
NSString * const ESPSettingHealthBar     = @"esp_health_bar_enabled";
NSString * const ESPSettingTeamCheck     = @"esp_team_check";
NSString * const ESPSettingScreenshotSafe = @"esp_screenshot_safe";
NSString * const ESPSettingCameraZoom    = @"esp_camera_zoom";

NSString * const ESPStatusMessage   = @"message";
NSString * const ESPStatusPlayers   = @"players";
NSString * const ESPStatusTone      = @"tone";
NSString * const ESPStatusUpdatedAt = @"updated_at";

static NSString *ESPSettingsPath(void) {
    return @"/var/mobile/Library/Caches/aov_esp_settings.plist";
}

static NSString *ESPStatusPath(void) {
    return @"/var/mobile/Library/Caches/aov_esp_status.plist";
}

static NSDictionary<NSString *, NSNumber *> *ESPDefaultSettings(void) {
    return @{
        ESPSettingBox: @YES,
        ESPSettingBoxOutline: @NO,
        ESPSettingBoxFill: @NO,
        ESPSettingLine: @NO,
        ESPSettingLineOutline: @NO,
        ESPSettingName: @NO,
        ESPSettingHeroIcon: @NO,
        ESPSettingMiniMap: @NO,
        ESPSettingMiniMapPosX: @10.0f,
        ESPSettingMiniMapPosY: @24.0f,
        ESPSettingMiniMapSize: @120.0f,
        ESPSettingMiniMapIconSize: @22.0f,
        ESPSettingHealthText: @NO,
        ESPSettingHealthBar: @NO,
        ESPSettingTeamCheck: @YES,
        ESPSettingScreenshotSafe: @NO,
    };
}

static NSMutableDictionary<NSString *, NSNumber *> *ESPReadSettings(void) {
    NSMutableDictionary *settings = [ESPDefaultSettings() mutableCopy];
    NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:ESPSettingsPath()];
    if ([saved isKindOfClass:[NSDictionary class]]) [settings addEntriesFromDictionary:saved];
    return settings;
}

static void ESPApplySettings(NSDictionary<NSString *, NSNumber *> *settings) {
    esp_box_enabled        = [settings[ESPSettingBox] boolValue];
    esp_box_outline        = [settings[ESPSettingBoxOutline] boolValue];
    esp_box_fill           = [settings[ESPSettingBoxFill] boolValue];
    esp_line_enabled       = [settings[ESPSettingLine] boolValue];
    esp_line_outline       = [settings[ESPSettingLineOutline] boolValue];
    esp_name_enabled       = [settings[ESPSettingName] boolValue];
    esp_icon_enabled       = [settings[ESPSettingHeroIcon] boolValue];
    esp_minimap_enabled    = [settings[ESPSettingMiniMap] boolValue];
    esp_minimap_pos_x      = [settings[ESPSettingMiniMapPosX] floatValue];
    esp_minimap_pos_y      = [settings[ESPSettingMiniMapPosY] floatValue];
    esp_minimap_size       = [settings[ESPSettingMiniMapSize] floatValue];
    esp_minimap_icon_size  = [settings[ESPSettingMiniMapIconSize] floatValue];
    esp_health_enabled     = [settings[ESPSettingHealthText] boolValue];
    esp_health_bar_enabled = [settings[ESPSettingHealthBar] boolValue];
    esp_team_check         = [settings[ESPSettingTeamCheck] boolValue];
    esp_screenshot_safe    = [settings[ESPSettingScreenshotSafe] boolValue];
}

void cfg_load_shared(void) {
    ESPApplySettings(ESPReadSettings());
}

BOOL cfg_get_bool(NSString *key) {
    NSNumber *value = ESPReadSettings()[key];
    return value ? value.boolValue : NO;
}

float cfg_get_float(NSString *key, float fallback) {
    NSNumber *value = ESPReadSettings()[key];
    return value ? value.floatValue : fallback;
}

void cfg_set_bool(NSString *key, BOOL value) {
    if (!key.length) return;
    @synchronized([NSFileManager class]) {
        NSMutableDictionary *settings = ESPReadSettings();
        settings[key] = @(value);
        [settings writeToFile:ESPSettingsPath() atomically:YES];
        ESPApplySettings(settings);
    }
    notify_post(ESP_SETTINGS_NOTIFICATION);
}

void cfg_set_float(NSString *key, float value) {
    if (!key.length) return;
    @synchronized([NSFileManager class]) {
        NSMutableDictionary *settings = ESPReadSettings();
        settings[key] = @(value);
        [settings writeToFile:ESPSettingsPath() atomically:YES];
        ESPApplySettings(settings);
    }
    notify_post(ESP_SETTINGS_NOTIFICATION);
}

NSDictionary<NSString *, id> *cfg_get_status(void) {
    NSDictionary *status = [NSDictionary dictionaryWithContentsOfFile:ESPStatusPath()];
    if (![status isKindOfClass:[NSDictionary class]]) {
        return @{
            ESPStatusMessage: @"Dang cho du lieu tu HUD",
            ESPStatusPlayers: @0,
            ESPStatusTone: @"idle",
            ESPStatusUpdatedAt: @0,
        };
    }
    return status;
}

void cfg_set_status(NSString *message, NSInteger players, NSString *tone) {
    if (!message.length) message = @"Dang cap nhat trang thai";
    if (!tone.length) tone = @"idle";

    @synchronized([NSFileManager class]) {
        NSDictionary *oldStatus = cfg_get_status();
        if ([oldStatus[ESPStatusMessage] isEqualToString:message] &&
            [oldStatus[ESPStatusTone] isEqualToString:tone] &&
            [oldStatus[ESPStatusPlayers] integerValue] == players) {
            return;
        }

        NSDictionary *status = @{
            ESPStatusMessage: message,
            ESPStatusPlayers: @(players),
            ESPStatusTone: tone,
            ESPStatusUpdatedAt: @([[NSDate date] timeIntervalSince1970]),
        };
        [status writeToFile:ESPStatusPath() atomically:YES];
    }
    notify_post(ESP_STATUS_NOTIFICATION);
}
