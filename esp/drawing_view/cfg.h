#import <Foundation/Foundation.h>

#define ESP_SETTINGS_NOTIFICATION "dev.metaware.external.esp.settings"
#define ESP_STATUS_NOTIFICATION "dev.metaware.external.esp.status"

FOUNDATION_EXPORT NSString * const ESPSettingBox;
FOUNDATION_EXPORT NSString * const ESPSettingBoxOutline;
FOUNDATION_EXPORT NSString * const ESPSettingBoxFill;
FOUNDATION_EXPORT NSString * const ESPSettingLine;
FOUNDATION_EXPORT NSString * const ESPSettingLineOutline;
FOUNDATION_EXPORT NSString * const ESPSettingName;
FOUNDATION_EXPORT NSString * const ESPSettingHeroIcon;
FOUNDATION_EXPORT NSString * const ESPSettingMiniMap;
FOUNDATION_EXPORT NSString * const ESPSettingMiniMapPosX;
FOUNDATION_EXPORT NSString * const ESPSettingMiniMapPosY;
FOUNDATION_EXPORT NSString * const ESPSettingMiniMapSize;
FOUNDATION_EXPORT NSString * const ESPSettingMiniMapIconSize;
FOUNDATION_EXPORT NSString * const ESPSettingHealthText;
FOUNDATION_EXPORT NSString * const ESPSettingHealthBar;
FOUNDATION_EXPORT NSString * const ESPSettingTeamCheck;
FOUNDATION_EXPORT NSString * const ESPSettingScreenshotSafe;
FOUNDATION_EXPORT NSString * const ESPSettingCameraZoom;

FOUNDATION_EXPORT NSString * const ESPStatusMessage;
FOUNDATION_EXPORT NSString * const ESPStatusPlayers;
FOUNDATION_EXPORT NSString * const ESPStatusTone;
FOUNDATION_EXPORT NSString * const ESPStatusUpdatedAt;

void cfg_load_shared(void);
BOOL cfg_get_bool(NSString *key);
float cfg_get_float(NSString *key, float fallback);
void cfg_set_bool(NSString *key, BOOL value);
void cfg_set_float(NSString *key, float value);
NSDictionary<NSString *, id> *cfg_get_status(void);
void cfg_set_status(NSString *message, NSInteger players, NSString *tone);
