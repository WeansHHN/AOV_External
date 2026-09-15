#import <QuartzCore/QuartzCore.h>

#import "HUDHelper.h"
#import "RootViewController.h"
#import "../esp/drawing_view/cfg.h"
#import <notify.h>

static UIColor *AOVColor(CGFloat red, CGFloat green, CGFloat blue) {
    return [UIColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:1.0];
}

@interface RootViewController ()
- (void)reloadESPDetailStatus;
@end

@implementation RootViewController {
    UIButton *_mainButton;
    UILabel *_statusLabel;
    UILabel *_hudDetailLabel;
    UIView *_statusDot;
    CAGradientLayer *_backgroundGradient;
    NSMutableDictionary<NSString *, UISwitch *> *_settingSwitches;
    int _statusNotifyToken;
}

- (BOOL)isHUDEnabled {
    return IsHUDEnabled();
}

- (void)setHUDEnabled:(BOOL)enabled {
    SetHUDEnabled(enabled);
}

- (UILabel *)labelWithText:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.textColor = color;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.numberOfLines = 0;
    return label;
}

- (UIView *)switchRow:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [self labelWithText:title size:15 weight:UIFontWeightSemibold
                                        color:[UIColor whiteColor]];
    UILabel *subtitleLabel = [self labelWithText:subtitle size:11 weight:UIFontWeightRegular
                                           color:AOVColor(137, 160, 149)];
    UIStackView *labels = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 2;
    labels.translatesAutoresizingMaskIntoConstraints = NO;

    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = AOVColor(46, 213, 115);
    toggle.accessibilityIdentifier = key;
    toggle.on = cfg_get_bool(key);
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    [toggle addTarget:self action:@selector(settingChanged:) forControlEvents:UIControlEventValueChanged];
    _settingSwitches[key] = toggle;

    [row addSubview:labels];
    [row addSubview:toggle];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:54],
        [labels.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [labels.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [labels.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-16],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

- (UIView *)sliderRow:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key min:(float)min max:(float)max {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [self labelWithText:title size:15 weight:UIFontWeightSemibold
                                        color:[UIColor whiteColor]];
    UILabel *subtitleLabel = [self labelWithText:subtitle size:11 weight:UIFontWeightRegular
                                           color:AOVColor(137, 160, 149)];
    UIStackView *labels = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 2;
    labels.translatesAutoresizingMaskIntoConstraints = NO;

    UISlider *slider = [UISlider new];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.value = cfg_get_float(key, min);
    slider.accessibilityIdentifier = key;
    slider.minimumTrackTintColor = AOVColor(46, 213, 115);
    slider.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    slider.thumbTintColor = [UIColor whiteColor];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    [slider addTarget:self action:@selector(floatChanged:) forControlEvents:UIControlEventValueChanged];

    [row addSubview:labels];
    [row addSubview:slider];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:74],
        [labels.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [labels.topAnchor constraintEqualToAnchor:row.topAnchor],
        [labels.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [slider.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [slider.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [slider.topAnchor constraintEqualToAnchor:labels.bottomAnchor constant:10],
        [slider.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];
    return row;
}

- (UIView *)cardWithTitle:(NSString *)title rows:(NSArray<UIView *> *)rows {
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.065];
    card.layer.cornerRadius = 18;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;

    UILabel *heading = [self labelWithText:title.uppercaseString size:12 weight:UIFontWeightBold
                                      color:AOVColor(46, 213, 115)];
    NSMutableArray<UIView *> *items = [NSMutableArray arrayWithObject:heading];
    for (NSUInteger index = 0; index < rows.count; index++) {
        if (index > 0) {
            UIView *separator = [UIView new];
            separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.07];
            [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale].active = YES;
            [items addObject:separator];
        }
        [items addObject:rows[index]];
    }

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:items];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 4;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
    ]];
    return card;
}

- (void)loadView {
    cfg_load_shared();
    _settingSwitches = [NSMutableDictionary dictionary];
    _statusNotifyToken = -1;

    self.view = [UIView new];
    self.view.backgroundColor = AOVColor(5, 12, 9);

    self.backgroundView = [UIView new];
    self.backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.backgroundView];
    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    _backgroundGradient = [CAGradientLayer layer];
    _backgroundGradient.colors = @[
        (id)AOVColor(8, 25, 18).CGColor,
        (id)AOVColor(5, 12, 9).CGColor,
        (id)AOVColor(4, 8, 7).CGColor,
    ];
    _backgroundGradient.locations = @[@0.0, @0.48, @1.0];
    _backgroundGradient.startPoint = CGPointMake(0, 0);
    _backgroundGradient.endPoint = CGPointMake(1, 1);
    [self.backgroundView.layer addSublayer:_backgroundGradient];

    UIScrollView *scroll = [UIScrollView new];
    scroll.alwaysBounceVertical = YES;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backgroundView addSubview:scroll];

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];

    NSLayoutConstraint *responsiveWidth =
        [stack.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-40];
    responsiveWidth.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.backgroundView.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.backgroundView.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.backgroundView.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.backgroundView.bottomAnchor],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:20],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-28],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:620],
        [stack.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
    ]];
    responsiveWidth.active = YES;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon.png"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.layer.cornerRadius = 15;
    icon.clipsToBounds = YES;
    [icon.widthAnchor constraintEqualToConstant:62].active = YES;
    [icon.heightAnchor constraintEqualToConstant:62].active = YES;

    UILabel *title = [self labelWithText:@"AOV External" size:28 weight:UIFontWeightBold color:[UIColor whiteColor]];
    UILabel *subtitle = [self labelWithText:@"Điều khiển ESP trực tiếp trong ứng dụng" size:13
                                      weight:UIFontWeightRegular color:AOVColor(137, 160, 149)];
    UIStackView *titles = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    titles.axis = UILayoutConstraintAxisVertical;
    titles.spacing = 3;

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[icon, titles]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 14;
    [stack addArrangedSubview:header];

    UIView *controlCard = [UIView new];
    controlCard.backgroundColor = [UIColor colorWithWhite:1 alpha:0.075];
    controlCard.layer.cornerRadius = 20;
    controlCard.layer.borderWidth = 1;
    controlCard.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [controlCard.heightAnchor constraintEqualToConstant:152].active = YES;

    _statusDot = [UIView new];
    _statusDot.layer.cornerRadius = 5;
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel = [self labelWithText:@"Đang kiểm tra" size:13 weight:UIFontWeightSemibold
                                 color:AOVColor(160, 174, 168)];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _hudDetailLabel = [self labelWithText:@"Dang cho du lieu tu HUD" size:12 weight:UIFontWeightMedium
                                    color:AOVColor(137, 160, 149)];
    _hudDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _mainButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _mainButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _mainButton.layer.cornerRadius = 13;
    _mainButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_mainButton addTarget:self action:@selector(tapMainButton:) forControlEvents:UIControlEventTouchUpInside];

    [controlCard addSubview:_statusDot];
    [controlCard addSubview:_statusLabel];
    [controlCard addSubview:_hudDetailLabel];
    [controlCard addSubview:_mainButton];
    [NSLayoutConstraint activateConstraints:@[
        [_statusDot.leadingAnchor constraintEqualToAnchor:controlCard.leadingAnchor constant:20],
        [_statusDot.topAnchor constraintEqualToAnchor:controlCard.topAnchor constant:20],
        [_statusDot.widthAnchor constraintEqualToConstant:10],
        [_statusDot.heightAnchor constraintEqualToConstant:10],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:9],
        [_statusLabel.centerYAnchor constraintEqualToAnchor:_statusDot.centerYAnchor],
        [_hudDetailLabel.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:6],
        [_hudDetailLabel.leadingAnchor constraintEqualToAnchor:_statusLabel.leadingAnchor],
        [_hudDetailLabel.trailingAnchor constraintEqualToAnchor:controlCard.trailingAnchor constant:-20],
        [_mainButton.topAnchor constraintGreaterThanOrEqualToAnchor:_hudDetailLabel.bottomAnchor constant:12],
        [_mainButton.leadingAnchor constraintEqualToAnchor:controlCard.leadingAnchor constant:18],
        [_mainButton.trailingAnchor constraintEqualToAnchor:controlCard.trailingAnchor constant:-18],
        [_mainButton.bottomAnchor constraintEqualToAnchor:controlCard.bottomAnchor constant:-17],
        [_mainButton.heightAnchor constraintEqualToConstant:52],
    ]];
    [stack addArrangedSubview:controlCard];

    [stack addArrangedSubview:[self cardWithTitle:@"Khung hiển thị" rows:@[
        [self switchRow:@"Khung 2D" subtitle:@"Vẽ khung quanh mục tiêu" key:ESPSettingBox],
        [self switchRow:@"Viền khung" subtitle:@"Thêm viền đen để dễ quan sát" key:ESPSettingBoxOutline],
        [self switchRow:@"Nền khung" subtitle:@"Tô nền mờ bên trong khung" key:ESPSettingBoxFill],
    ]]];

    [stack addArrangedSubview:[self cardWithTitle:@"Đường chỉ mục tiêu" rows:@[
        [self switchRow:@"Đường line" subtitle:@"Nối từ màn hình đến mục tiêu" key:ESPSettingLine],
        [self switchRow:@"Viền line" subtitle:@"Tăng độ tương phản của đường line" key:ESPSettingLineOutline],
    ]]];

    [stack addArrangedSubview:[self cardWithTitle:@"Thông tin người chơi" rows:@[
        [self switchRow:@"Tên" subtitle:@"Hiển thị tên phía trên mục tiêu" key:ESPSettingName],
        [self switchRow:@"Icon tướng" subtitle:@"Hiển thị icon đi theo tên tướng" key:ESPSettingHeroIcon],
        [self switchRow:@"ESP minimap" subtitle:@"Hiển thị icon địch trên minimap" key:ESPSettingMiniMap],
        [self switchRow:@"Chỉ số HP" subtitle:@"Hiển thị máu dạng số" key:ESPSettingHealthText],
        [self switchRow:@"Thanh HP" subtitle:@"Thanh máu đổi màu theo lượng HP" key:ESPSettingHealthBar],
        [self switchRow:@"Lọc đồng đội" subtitle:@"Chỉ hiển thị mục tiêu phe địch" key:ESPSettingTeamCheck],
    ]]];

    [stack addArrangedSubview:[self cardWithTitle:@"Chỉnh Camera & Minimap" rows:@[
        [self sliderRow:@"Camera Zoom" subtitle:@"Điều chỉnh độ cao / xa góc nhìn" key:ESPSettingCameraZoom min:5.0f max:80.0f],
        [self sliderRow:@"Minimap trái/phải" subtitle:@"Kéo khung sang trái hoặc phải" key:ESPSettingMiniMapPosX min:0.0f max:400.0f],
        [self sliderRow:@"Minimap trên/dưới" subtitle:@"Kéo khung lên hoặc xuống" key:ESPSettingMiniMapPosY min:0.0f max:400.0f],
        [self sliderRow:@"Kích thước khung" subtitle:@"Tăng giảm khung vuông minimap" key:ESPSettingMiniMapSize min:50.0f max:260.0f],
        [self sliderRow:@"Kích thước icon" subtitle:@"Tăng giảm icon tướng trên minimap" key:ESPSettingMiniMapIconSize min:12.0f max:60.0f],
    ]]];

    [stack addArrangedSubview:[self cardWithTitle:@"Riêng tư" rows:@[
        [self switchRow:@"Ẩn khi chụp màn hình" subtitle:@"Không ghi lớp ESP vào ảnh và video" key:ESPSettingScreenshotSafe],
    ]]];

    UILabel *footer = [self labelWithText:@"Thiết lập được lưu tự động và áp dụng ngay cho HUD đang chạy."
                                      size:11 weight:UIFontWeightRegular color:AOVColor(104, 125, 114)];
    footer.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:footer];

    __weak RootViewController *weakSelf = self;
    int statusToken = -1;
    uint32_t statusResult = notify_register_dispatch(ESP_STATUS_NOTIFICATION, &statusToken,
                                                      dispatch_get_main_queue(), ^(int unused) {
        [weakSelf reloadESPDetailStatus];
    });
    if (statusResult == NOTIFY_STATUS_OK) _statusNotifyToken = statusToken;

    [self reloadMainButtonState];
}

- (void)dealloc {
    if (_statusNotifyToken >= 0) notify_cancel(_statusNotifyToken);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _backgroundGradient.frame = self.backgroundView.bounds;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reloadMainButtonState];
}

- (void)settingChanged:(UISwitch *)sender {
    cfg_set_bool(sender.accessibilityIdentifier, sender.isOn);
}

- (void)floatChanged:(UISlider *)sender {
    cfg_set_float(sender.accessibilityIdentifier, sender.value);
}

- (UIColor *)detailColorForTone:(NSString *)tone active:(BOOL)active {
    if (!active) return AOVColor(137, 160, 149);
    if ([tone isEqualToString:@"ok"]) return AOVColor(121, 241, 169);
    if ([tone isEqualToString:@"warn"]) return AOVColor(255, 190, 89);
    if ([tone isEqualToString:@"error"]) return AOVColor(255, 114, 126);
    return AOVColor(137, 160, 149);
}

- (void)reloadESPDetailStatus {
    BOOL active = [self isHUDEnabled];
    if (!active) {
        _hudDetailLabel.text = @"HUD stopped";
        _hudDetailLabel.textColor = [self detailColorForTone:@"idle" active:NO];
        return;
    }

    NSDictionary<NSString *, id> *status = cfg_get_status();
    NSString *message = status[ESPStatusMessage];
    NSString *tone = status[ESPStatusTone];
    if (![message isKindOfClass:[NSString class]] || !message.length) {
        message = @"Dang cho du lieu tu HUD";
    }
    if (![tone isKindOfClass:[NSString class]] || !tone.length) {
        tone = @"idle";
    }

    _hudDetailLabel.text = message;
    _hudDetailLabel.textColor = [self detailColorForTone:tone active:YES];
}

- (void)reloadMainButtonState {
    cfg_load_shared();
    [_settingSwitches enumerateKeysAndObjectsUsingBlock:^(NSString *key, UISwitch *toggle, BOOL *stop) {
        [toggle setOn:cfg_get_bool(key) animated:NO];
    }];

    BOOL active = [self isHUDEnabled];
    _statusDot.backgroundColor = active ? AOVColor(46, 213, 115) : AOVColor(113, 128, 120);
    _statusLabel.textColor = active ? AOVColor(121, 241, 169) : AOVColor(160, 174, 168);
    _statusLabel.text = active ? @"ESP đang hoạt động" : @"ESP đang tắt";
    _mainButton.backgroundColor = active ? AOVColor(72, 38, 43) : AOVColor(46, 213, 115);
    [_mainButton setTitleColor:active ? AOVColor(255, 133, 143) : AOVColor(3, 30, 16)
                         forState:UIControlStateNormal];
    [_mainButton setTitle:(active ? @"Dừng ESP" : @"Chạy ESP") forState:UIControlStateNormal];
    [self reloadESPDetailStatus];
}

- (void)tapMainButton:(UIButton *)sender {
    BOOL enable = ![self isHUDEnabled];
    self.backgroundView.userInteractionEnabled = NO;
    sender.alpha = 0.55;
    [self setHUDEnabled:enable];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.backgroundView.userInteractionEnabled = YES;
        sender.alpha = 1.0;
        [self reloadMainButtonState];
    });
}

@end
