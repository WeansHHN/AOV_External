#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../helpers/Vector3.h"
#import "../helpers/pid.h"
#import "../unity_api/unity.h"

struct ESPBox {
    Vector3 pos;
    CGFloat width;
    CGFloat height;
};

extern volatile bool esp_box_enabled;
extern volatile bool esp_box_outline;
extern volatile bool esp_box_fill;
extern volatile bool esp_line_enabled;
extern volatile bool esp_line_outline;
extern volatile bool esp_name_enabled;
extern volatile bool esp_icon_enabled;
extern volatile bool esp_minimap_enabled;
extern volatile float esp_minimap_pos_x;
extern volatile float esp_minimap_pos_y;
extern volatile float esp_minimap_size;
extern volatile float esp_minimap_icon_size;
extern volatile bool esp_health_enabled;
extern volatile bool esp_health_bar_enabled;
extern volatile bool esp_team_check;
extern volatile bool esp_screenshot_safe;

@interface ESP_View : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (void)update_data;
@end
