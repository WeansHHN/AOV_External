#import "esp.h"
#import "cfg.h"
#include "../offset.h"
#import "../HeroIcon/iconHero.h"
#include "obfusheader.h"
#import "../../sources/UIView+SecureView.h"
#import <notify.h>
#include <cmath>

namespace Off = AOVOffset;

// ─── AoV memory helpers ───────────────────────────────────────────────────────

struct VInt3 {
    int x, y, z;
};

// ─── ESP toggles ─────────────────────────────────────────────────────────────

volatile bool esp_box_enabled        = true;
volatile bool esp_box_outline        = false;
volatile bool esp_box_fill           = false;
volatile bool esp_line_enabled       = false;
volatile bool esp_line_outline       = false;
volatile bool esp_name_enabled       = false;
volatile bool esp_icon_enabled       = false;
volatile bool esp_minimap_enabled    = false;
volatile float esp_minimap_pos_x     = 10.0f;
volatile float esp_minimap_pos_y     = 24.0f;
volatile float esp_minimap_size      = 120.0f;
volatile float esp_minimap_icon_size = 22.0f;
volatile bool esp_health_enabled     = false;
volatile bool esp_health_bar_enabled = false;
volatile bool esp_team_check         = true;
volatile bool esp_screenshot_safe    = false;

static UIColor *ESPHealthColor(float percent) {
    float pct = fmaxf(0.0f, fminf(percent, 1.0f));
    CGFloat red = pct >= 0.5f ? (CGFloat)((1.0f - pct) * 2.0f) : 1.0f;
    CGFloat green = pct >= 0.5f ? 1.0f : (CGFloat)(pct * 2.0f);
    return [UIColor colorWithRed:red green:green blue:0.05f alpha:0.95f];
}

static CGRect ESPMiniMapRect(CGFloat width, CGFloat height) {
    CGFloat side = fminf(fmaxf(40.0f, esp_minimap_size), fmaxf(40.0f, fminf(width, height) - 4.0f));
    CGFloat left = fminf(fmaxf(0.0f, esp_minimap_pos_x), fmaxf(0.0f, width - side - 2.0f));
    CGFloat top = fminf(fmaxf(0.0f, esp_minimap_pos_y), fmaxf(0.0f, height - side - 2.0f));
    return CGRectMake(left, top, side, side);
}

static CGPoint ESPMiniMapPointForLocation(VInt3 loc, int localTeam, CGRect mapRect) {
    float logicX = (float)loc.x / 1000.0f;
    float logicZ = (float)loc.z / 1000.0f;
    CGFloat centerX = CGRectGetMidX(mapRect);
    CGFloat centerY = CGRectGetMidY(mapRect);
    CGFloat x = centerX + logicX * mapRect.size.width / Off::MiniMap::WorldScaleX;
    CGFloat y = centerY - logicZ * mapRect.size.height / Off::MiniMap::WorldScaleY;

    if (localTeam == 2) {
        x = centerX - logicX * mapRect.size.width / Off::MiniMap::WorldScaleX;
        y = centerY + logicZ * mapRect.size.height / Off::MiniMap::WorldScaleY;
    }

    CGFloat minX = CGRectGetMinX(mapRect) + 3.0f;
    CGFloat maxX = CGRectGetMaxX(mapRect) - 3.0f;
    CGFloat minY = CGRectGetMinY(mapRect) + 3.0f;
    CGFloat maxY = CGRectGetMaxY(mapRect) - 3.0f;
    return CGPointMake(fminf(fmaxf(x, minX), maxX),
                       fminf(fmaxf(y, minY), maxY));
}

static BOOL IsGenericHeroName(NSString *name) {
    return !name || name.length == 0 || [name caseInsensitiveCompare:@"Hero"] == NSOrderedSame;
}

static NSString *HeroNameForConfigID(int configID) {
    static NSDictionary<NSNumber *, NSString *> *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @{
            @105:@"Toro", @106:@"Krixi", @107:@"Zephys", @108:@"Gildur", @109:@"Veera",
            @110:@"Kahlii", @111:@"Violet", @112:@"Yorn", @113:@"Chaugnar", @114:@"Omega",
            @115:@"Jinna", @116:@"Butterfly", @117:@"Ormarr", @118:@"Alice", @119:@"Mganga",
            @120:@"Mina", @121:@"Marja", @123:@"Maloch", @124:@"Ignis", @126:@"Arduin",
            @127:@"Azzen'Ka", @128:@"Lữ Bố", @129:@"Triệu Vân", @130:@"Airi", @131:@"Murad",
            @132:@"Hayate", @133:@"Valhein", @134:@"Skud", @135:@"Thane", @136:@"Ilumia",
            @137:@"Paine", @139:@"Kil'Groth", @140:@"Superman", @141:@"Lauriel", @142:@"Natalya",
            @144:@"Taara", @146:@"Zill", @148:@"Preyta", @149:@"Xeniel", @150:@"Nakroth",
            @152:@"Điêu Thuyền", @153:@"Kaine", @154:@"Yena", @156:@"Aleister", @157:@"Raz",
            @159:@"Dolia", @162:@"Kriknak", @163:@"Ryoma", @166:@"Arthur", @167:@"Ngộ Không",
            @168:@"Lumburr", @169:@"Slimz", @170:@"Moren", @171:@"Cresht", @173:@"Fennik",
            @174:@"Stuart", @175:@"Grakk", @177:@"Lindis", @180:@"Max", @184:@"Helen",
            @186:@"TeeMee", @187:@"Arum", @189:@"Krizzix", @190:@"Tulen", @191:@"Rouie",
            @192:@"Celica", @193:@"Amily", @194:@"Wiro", @195:@"Enzo", @196:@"Elsu",
            @199:@"Eland'orr", @206:@"Charlotte", @501:@"Tel'Annas", @502:@"Astrid", @503:@"Zuka",
            @504:@"Wonder Woman", @505:@"Baldum", @506:@"Omen", @507:@"The Flash", @508:@"Wisp",
            @509:@"Y'bneth", @510:@"Liliana", @511:@"Ata", @512:@"Rourke", @513:@"Zata",
            @514:@"Roxie", @515:@"Richter", @518:@"Quillen", @519:@"Annette", @520:@"Veres",
            @521:@"Florentino", @522:@"Errol", @523:@"D'Arcy", @524:@"Capheny", @525:@"Zip",
            @526:@"Ishar", @527:@"Sephera", @528:@"Qi", @529:@"Volkath", @530:@"Dirak",
            @531:@"Keera", @532:@"Thorne", @533:@"Laville", @534:@"Dextra", @535:@"Sinestrea",
            @536:@"Aoi", @537:@"Allain", @538:@"Iggy", @539:@"Lorion", @540:@"Bright",
            @541:@"Bonnie", @542:@"Tachi", @543:@"Aya", @544:@"Yan", @545:@"Yue",
            @546:@"Teeri", @548:@"Bijan", @563:@"Heino", @567:@"Erin", @568:@"Ming",
            @577:@"Dyadia", @584:@"Flowborn", @582:@"Flowborn", @593:@"Tamyn", @595:@"Edras", @596:@"Goverra",
            @597:@"Biron", @598:@"Bolt Baron", @599:@"Billow",
        };
    });
    return names[@(configID)];
}

static int ValidHeroConfigID(int configID) {
    return HeroNameForConfigID(configID) ? configID : 0;
}

static int ReadHeroConfigID(mach_port_t task, mach_vm_address_t root, mach_vm_address_t actor) {
    int configID = 0;
    if (root > 0x1000000) {
        configID = ValidHeroConfigID(Read<int>(root + Off::LActorRoot::ConfigID, task));
        if (configID) return configID;
    }
    if (actor > 0x1000000) {
        configID = ValidHeroConfigID(Read<int>(actor + Off::ActorLinker::MetaConfigID, task));
        if (configID) return configID;

        mach_vm_address_t objLinker = Read<mach_vm_address_t>(actor + Off::ActorLinker::ObjLinker, task);
        if (objLinker > 0x1000000) {
            configID = ValidHeroConfigID(Read<int>(objLinker + Off::ActorLinker::ConfigID, task));
            if (configID) return configID;
        }
    }
    return 0;
}

static NSString *HeroIconBase64ForConfigID(int configID) {
    switch (configID) {
        case 105: return Toro;          case 106: return Krixi;
        case 107: return Zephys;        case 108: return Gildur;
        case 109: return Veera;         case 110: return Kahlii;
        case 111: return Violet;        case 112: return Yorn;
        case 113: return Chaugnar;      case 114: return Omega;
        case 115: return Jinna;         case 116: return Butterfly;
        case 117: return Ormarr;        case 118: return Alice;
        case 119: return Mganga;        case 120: return Mina;
        case 121: return Marja;         case 123: return Maloch;
        case 124: return Ignis;         case 126: return Arduin;
        case 127: return AzzenKa;       case 128: return LuBu;
        case 129: return Zanis;         case 130: return Airi;
        case 131: return Murad;         case 132: return Hayate;
        case 133: return Valhein;       case 134: return Skud;
        case 135: return Thane;         case 136: return Ilumia;
        case 137: return Paine;         case 139: return KilGroth;
        case 140: return Superman;      case 141: return Lauriel;
        case 142: return Natalya;       case 144: return Taara;
        case 146: return Zill;          case 148: return Preyta;
        case 149: return Xeniel;        case 150: return Nakroth;
        case 152: return DiaoChan;      case 153: return Kaine;
        case 154: return Yena;          case 156: return Aleister;
        case 157: return Raz;           case 159: return Dolia;
        case 162: return Kriknak;       case 163: return Ryoma;
        case 166: return Arthur;        case 167: return Wukong;
        case 168: return Lumburr;       case 169: return Slimz;
        case 170: return Moren;         case 171: return Cresht;
        case 173: return Fennik;        case 174: return Stuart;
        case 175: return Grakk;         case 177: return Lindis;
        case 180: return _Max;          case 184: return Helen;
        case 186: return TeeMee;        case 187: return Arum;
        case 189: return Krizzix;       case 190: return Tulen;
        case 191: return Rouie;         case 192: return Celica;
        case 193: return Amily;         case 194: return Wiro;
        case 195: return Enzo;          case 196: return Elsu;
        case 199: return Elandorr;      case 206: return Charlotte;
        case 501: return TelAnnas;      case 502: return Astrid;
        case 503: return Zuka;          case 504: return WonderWoman;
        case 505: return Baldum;        case 506: return Omen;
        case 507: return TheFlash;      case 508: return Wisp;
        case 509: return Ybneth;        case 510: return Liliana;
        case 511: return Ata;           case 512: return Rourke;
        case 513: return Zata;          case 514: return Roxie;
        case 515: return Richter;       case 518: return Quillen;
        case 519: return Annette;       case 520: return Veres;
        case 521: return Florentino;    case 522: return Errol;
        case 523: return Darcy;         case 524: return Capheny;
        case 525: return Zip;           case 526: return Ishar;
        case 527: return Sephera;       case 528: return Qi;
        case 529: return Volkath;       case 530: return Dirak;
        case 531: return Keera;         case 532: return Thorne;
        case 533: return Laville;       case 534: return Dextra;
        case 535: return Sinestrea;     case 536: return Aoi;
        case 537: return Allain;        case 538: return Iggy;
        case 539: return Lorion;        case 540: return Bright;
        case 541: return Bonnie;        case 542: return Tachi;
        case 543: return Aya;           case 544: return Yan;
        case 545: return Yue;           case 546: return Teeri;
        case 548: return Bijan;         case 563: return Heino;
        case 567: return Erin;          case 568: return Ming;
        case 577: return ThieuTuDuyen;  case 584: return flowborn;
        case 593: return Tamyn;         case 595: return Edras;
        case 596: return Goverra;       case 597: return Biron;
        case 598: return BoltBaron;     case 599: return Billow;
        default: return nil;
    }
}

static UIImage *HeroIconForConfigID(int configID) {
    if (configID <= 0) return nil;

    static NSMutableDictionary<NSNumber *, UIImage *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });

    NSNumber *key = @(configID);
    UIImage *cached = cache[key];
    if (cached) return cached;

    NSString *base64 = HeroIconBase64ForConfigID(configID);
    if (!base64.length) return nil;

    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
    if (image) cache[key] = image;
    return image;
}

// ─── Forward declarations ─────────────────────────────────────────────────────

@interface UIWindow (Private)
- (void)_setSecure:(BOOL)secure;
- (unsigned int)_contextId;
@end

@interface SBSAccessibilityWindowHostingController : NSObject
- (void)registerWindowWithContextID:(unsigned int)contextID atLevel:(double)level;
@end

// ─── ESP_View private interface ───────────────────────────────────────────────

@interface ESP_View ()
@property (nonatomic, strong) CADisplayLink *displayLinkData;
@property (nonatomic, strong) UILabel       *playerCountLabel;
@property (nonatomic, assign) BOOL           hasAttemptedLaunch;
@property (nonatomic, strong) CAShapeLayer  *espBoxLayer;
@property (nonatomic, strong) CAShapeLayer  *espBoxFillLayer;
@property (nonatomic, strong) CAShapeLayer  *espBoxOutlineLayer;
@property (nonatomic, strong) CAShapeLayer  *espLineLayer;
@property (nonatomic, strong) CAShapeLayer  *espLineMidLayer;
@property (nonatomic, strong) CAShapeLayer  *espLineLowLayer;
@property (nonatomic, strong) CAShapeLayer  *espLineOutlineLayer;
@property (nonatomic, strong) CAShapeLayer  *espHealthBarLayer;
@property (nonatomic, strong) CAShapeLayer  *espHealthBarMidLayer;
@property (nonatomic, strong) CAShapeLayer  *espHealthBarLowLayer;
@property (nonatomic, strong) CAShapeLayer  *espHealthBarOutlineLayer;
@property (nonatomic, strong) UILabel       *watermarkLabel;
@property (nonatomic, strong) NSMutableArray<UILabel *> *nameLabelPool;
@property (nonatomic, strong) NSMutableArray<UILabel *> *healthLabelPool;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *heroIconViewPool;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *miniMapIconViewPool;
@property (nonatomic, strong) CAShapeLayer  *miniMapOutlineLayer;
@property (nonatomic, assign) int settingsNotifyToken;
@property (nonatomic, copy)   NSString      *lastStatusMessage;
@property (nonatomic, copy)   NSString      *lastStatusTone;
@property (nonatomic, assign) NSInteger      lastStatusPlayers;
@end

@implementation ESP_View

// ─── Init ─────────────────────────────────────────────────────────────────────

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor    = [UIColor clearColor];
    self.hasAttemptedLaunch = NO;
    self.userInteractionEnabled = NO;
    self.settingsNotifyToken = -1;
    self.lastStatusPlayers = -1;
    cfg_load_shared();

    self.espBoxFillLayer = [CAShapeLayer layer];
    self.espBoxFillLayer.fillColor   = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    self.espBoxFillLayer.strokeColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.espBoxFillLayer];

    self.espBoxOutlineLayer = [CAShapeLayer layer];
    self.espBoxOutlineLayer.strokeColor = [UIColor blackColor].CGColor;
    self.espBoxOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espBoxOutlineLayer.lineWidth   = 3.0;
    [self.layer addSublayer:self.espBoxOutlineLayer];

    self.espBoxLayer = [CAShapeLayer layer];
    self.espBoxLayer.strokeColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0].CGColor;
    self.espBoxLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espBoxLayer.lineWidth   = 1.5;
    [self.layer addSublayer:self.espBoxLayer];

    self.espHealthBarOutlineLayer = [CAShapeLayer layer];
    self.espHealthBarOutlineLayer.strokeColor = [UIColor blackColor].CGColor;
    self.espHealthBarOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espHealthBarOutlineLayer.lineWidth   = 3.0;
    [self.layer addSublayer:self.espHealthBarOutlineLayer];

    self.espHealthBarLayer = [CAShapeLayer layer];
    self.espHealthBarLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.3 alpha:0.9].CGColor;
    self.espHealthBarLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espHealthBarLayer.lineWidth   = 2.5;
    [self.layer addSublayer:self.espHealthBarLayer];

    self.espHealthBarMidLayer = [CAShapeLayer layer];
    self.espHealthBarMidLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.0 alpha:0.95].CGColor;
    self.espHealthBarMidLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espHealthBarMidLayer.lineWidth   = 2.5;
    [self.layer addSublayer:self.espHealthBarMidLayer];

    self.espHealthBarLowLayer = [CAShapeLayer layer];
    self.espHealthBarLowLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.05 alpha:0.95].CGColor;
    self.espHealthBarLowLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espHealthBarLowLayer.lineWidth   = 2.5;
    [self.layer addSublayer:self.espHealthBarLowLayer];

    self.espLineOutlineLayer = [CAShapeLayer layer];
    self.espLineOutlineLayer.strokeColor = [UIColor blackColor].CGColor;
    self.espLineOutlineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espLineOutlineLayer.lineWidth   = 3.0;
    [self.layer addSublayer:self.espLineOutlineLayer];

    self.espLineLayer = [CAShapeLayer layer];
    self.espLineLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.3 alpha:0.9].CGColor;
    self.espLineLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espLineLayer.lineWidth   = 1.0;
    [self.layer addSublayer:self.espLineLayer];

    self.espLineMidLayer = [CAShapeLayer layer];
    self.espLineMidLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.0 alpha:0.95].CGColor;
    self.espLineMidLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espLineMidLayer.lineWidth   = 1.0;
    [self.layer addSublayer:self.espLineMidLayer];

    self.espLineLowLayer = [CAShapeLayer layer];
    self.espLineLowLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.05 alpha:0.95].CGColor;
    self.espLineLowLayer.fillColor   = [UIColor clearColor].CGColor;
    self.espLineLowLayer.lineWidth   = 1.0;
    [self.layer addSublayer:self.espLineLowLayer];

    self.miniMapOutlineLayer = [CAShapeLayer layer];
    self.miniMapOutlineLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.92 blue:0.2 alpha:0.95].CGColor;
    self.miniMapOutlineLayer.fillColor   = [[UIColor colorWithWhite:0 alpha:0.04] CGColor];
    self.miniMapOutlineLayer.lineWidth   = 2.0f;
    [self.layer addSublayer:self.miniMapOutlineLayer];

    UILabel *wm = [[UILabel alloc] init];
    wm.text      = @(OBF("Telegram: @hhn_ios"));
    wm.textColor = [UIColor whiteColor];
    wm.font      = [UIFont boldSystemFontOfSize:14.0f];
    wm.userInteractionEnabled = NO;
    [self addSubview:wm];
    self.watermarkLabel = wm;

    UILabel *pcl = [UILabel new];
    pcl.textColor = [UIColor greenColor];
    pcl.font      = [UIFont boldSystemFontOfSize:13];
    pcl.textAlignment = NSTextAlignmentCenter;
    pcl.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    pcl.shadowOffset = CGSizeMake(0, 1);
    pcl.hidden    = YES;
    [self addSubview:pcl];
    self.playerCountLabel = pcl;

    self.nameLabelPool   = [NSMutableArray new];
    self.healthLabelPool = [NSMutableArray new];
    self.heroIconViewPool = [NSMutableArray new];
    self.miniMapIconViewPool = [NSMutableArray new];
    for (int i = 0; i < 20; i++) {
        UIImageView *mv = [UIImageView new];
        mv.contentMode = UIViewContentModeScaleAspectFill;
        mv.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.9f];
        mv.layer.borderWidth = 1.6f;
        mv.layer.borderColor = [UIColor redColor].CGColor;
        mv.clipsToBounds = YES;
        mv.hidden = YES;

        UIImageView *inner = [UIImageView new];
        inner.tag = 991;
        inner.contentMode = UIViewContentModeScaleAspectFit;
        inner.backgroundColor = [UIColor clearColor];
        inner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [mv addSubview:inner];

        [self addSubview:mv];
        [self.miniMapIconViewPool addObject:mv];

        UIImageView *iv = [UIImageView new];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.layer.cornerRadius = 9.0f;
        iv.layer.borderWidth = 1.0f;
        iv.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.8].CGColor;
        iv.clipsToBounds = YES;
        iv.hidden = YES;
        [self addSubview:iv];
        [self.heroIconViewPool addObject:iv];

        UILabel *nl = [UILabel new];
        nl.textColor = [UIColor whiteColor];
        nl.font      = [UIFont boldSystemFontOfSize:11];
        nl.hidden    = YES;
        [self addSubview:nl];
        [self.nameLabelPool addObject:nl];

        UILabel *hl = [UILabel new];
        hl.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.3 alpha:1.0];
        hl.font      = [UIFont systemFontOfSize:10];
        hl.hidden    = YES;
        [self addSubview:hl];
        [self.healthLabelPool addObject:hl];
    }

    self.displayLinkData = [CADisplayLink displayLinkWithTarget:self selector:@selector(update_data)];
    self.displayLinkData.preferredFramesPerSecond = 60;
    [self.displayLinkData addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    __weak ESP_View *weakSelf = self;
    int token = -1;
    uint32_t status = notify_register_dispatch(ESP_SETTINGS_NOTIFICATION, &token,
                                                dispatch_get_main_queue(), ^(int unused) {
        ESP_View *strongSelf = weakSelf;
        if (!strongSelf) return;
        cfg_load_shared();
        [strongSelf hideViewFromCapture:esp_screenshot_safe];
    });
    if (status == NOTIFY_STATUS_OK) self.settingsNotifyToken = token;
    [self hideViewFromCapture:esp_screenshot_safe];

    return self;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    [self hideViewFromCapture:esp_screenshot_safe];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;

    CGSize s = [self.watermarkLabel sizeThatFits:CGSizeMake(300, 30)];
    self.watermarkLabel.frame = CGRectMake(10, 8, s.width + 4, s.height);

    CGSize ps = [self.playerCountLabel sizeThatFits:CGSizeMake(200, 20)];
    self.playerCountLabel.frame = CGRectMake((CGRectGetWidth(self.bounds) - ps.width - 8) / 2.0,
                                             66,
                                             ps.width + 8,
                                             ps.height);
}

- (void)dealloc {
    if (self.settingsNotifyToken >= 0) notify_cancel(self.settingsNotifyToken);
    [self.displayLinkData invalidate];
    self.displayLinkData = nil;
}

- (void)clearAllBoxes {
    self.espBoxLayer.path              = nil;
    self.espBoxFillLayer.path          = nil;
    self.espBoxOutlineLayer.path       = nil;
    self.espLineLayer.path             = nil;
    self.espLineMidLayer.path          = nil;
    self.espLineLowLayer.path          = nil;
    self.espLineOutlineLayer.path      = nil;
    self.espHealthBarLayer.path        = nil;
    self.espHealthBarMidLayer.path     = nil;
    self.espHealthBarLowLayer.path     = nil;
    self.espHealthBarOutlineLayer.path = nil;
    self.miniMapOutlineLayer.path      = nil;
    for (UIImageView *v in self.heroIconViewPool) v.hidden = YES;
    for (UIImageView *v in self.miniMapIconViewPool) v.hidden = YES;
    for (UILabel *l in self.nameLabelPool)   l.hidden = YES;
    for (UILabel *l in self.healthLabelPool) l.hidden = YES;
    self.playerCountLabel.hidden = YES;
}

- (void)publishStatus:(NSString *)message players:(NSInteger)players tone:(NSString *)tone {
    if ([self.lastStatusMessage isEqualToString:message] &&
        [self.lastStatusTone isEqualToString:tone] &&
        self.lastStatusPlayers == players) {
        return;
    }

    self.lastStatusMessage = message;
    self.lastStatusTone = tone;
    self.lastStatusPlayers = players;
    cfg_set_status(message, players, tone);
}

- (void)showPlayerCount:(NSInteger)players width:(CGFloat)width {
    self.playerCountLabel.text = [NSString stringWithFormat:@"%ld", (long)players];
    self.playerCountLabel.textColor = ESPHealthColor(1.0f);
    [self.playerCountLabel sizeToFit];
    CGRect frame = self.playerCountLabel.frame;
    frame.size.width += 10;
    frame.size.height += 2;
    self.playerCountLabel.frame = frame;
    self.playerCountLabel.center = CGPointMake(width / 2.0f, 72.0f);
    self.playerCountLabel.hidden = NO;
}

// ─── Main update loop ─────────────────────────────────────────────────────────

- (void)update_data {
    if (!esp_box_enabled && !esp_line_enabled &&
        !esp_name_enabled && !esp_icon_enabled &&
        !esp_minimap_enabled &&
        !esp_health_enabled && !esp_health_bar_enabled) {
        [self clearAllBoxes];
        [self publishStatus:@"All ESP features are off" players:0 tone:@"idle"];
        return;
    }

    static pid_t   cached_pid   = 0;
    static task_t  cached_task  = 0;
    static mach_vm_address_t cached_base = 0;
    static mach_vm_address_t coreStaticFields = 0;
    static mach_vm_address_t csStaticFields = 0;
    static int cached_localTeam = 0;
    static int staticRefreshTimer = 0;
    // Cache KyriosFramework resolution chain to avoid ESP disappearing on temporary read failures
    static mach_vm_address_t cached_klass = 0;
    static mach_vm_address_t cached_staticFields = 0;
    static mach_vm_address_t cached_framework = 0;

    pid_t pid = get_pid_by_name(Off::Image::ProcessName);
    if (pid <= 0) {
        cached_pid  = 0;
        cached_task = 0;
        cached_base = 0;
        coreStaticFields = 0;
        csStaticFields = 0;
        cached_localTeam = 0;
        [self clearAllBoxes];
        [self publishStatus:@"Game not running" players:0 tone:@"error"];
        return;
    }

    if (pid != cached_pid || !cached_task || !cached_base) {
        cached_task = get_task_by_pid(pid);
        if (cached_task) {
            cached_base = 0;
            for (const char *image : Off::Image::Candidates) {
                mach_vm_address_t base = get_image_base_address(cached_task, image);
                if (base && Read<uint32_t>(base + Off::Image::SignatureRva, cached_task) == Off::Image::SignatureValue) {
                    cached_base = base;
                    break;
                }
            }
        }
        cached_pid = pid;
        coreStaticFields = 0;
        csStaticFields   = 0;
        cached_localTeam = 0;
        cached_klass        = 0;
        cached_staticFields = 0;
        cached_framework    = 0;
    }

    task_t task = cached_task;
    if (!task || cached_base == 0) {
        [self clearAllBoxes];
        [self publishStatus:@"Waiting for game initialization..." players:0 tone:@"warn"];
        return;
    }

    {
        // ── 1. Resolve MonoSingleton<KyriosFramework> Generic Class ──────────
        // Read fresh each frame but fall back to cached value if read fails.
        mach_vm_address_t methodInfo = Read<mach_vm_address_t>(cached_base + Off::Image::KyriosFrameworkClassGlobal, task);
        mach_vm_address_t klass      = Read<mach_vm_address_t>(methodInfo + Off::Runtime::MethodInfoKlass, task);
        if (klass > 0x1000000) {
            cached_klass = klass;
        } else {
            klass = cached_klass;
        }
        if (klass < 0x1000000) {
            [self clearAllBoxes];
            [self publishStatus:@"Waiting for generic class resolution..." players:0 tone:@"warn"];
            return;
        }

        // ── 2. Read static fields of MonoSingleton<KyriosFramework> ──────────
        mach_vm_address_t staticFields = Read<mach_vm_address_t>(klass + Off::Runtime::KlassStaticFields, task);
        if (staticFields > 0x1000000) {
            cached_staticFields = staticFields;
        } else {
            staticFields = cached_staticFields;
        }
        if (staticFields < 0x1000000) {
            [self clearAllBoxes];
            [self publishStatus:@"Waiting for static fields..." players:0 tone:@"warn"];
            return;
        }

        mach_vm_address_t framework = 0;
        for (uintptr_t sfOff = 0; sfOff <= Off::Framework::StaticScanEnd; sfOff += Off::Runtime::PointerStride) {
            mach_vm_address_t fw = Read<mach_vm_address_t>(staticFields + sfOff, task);
            if (fw > 0x1000000 && fw < 0x300000000) {
                mach_vm_address_t am = Read<mach_vm_address_t>(fw + Off::Framework::ActorManager, task);
                mach_vm_address_t hl = Read<mach_vm_address_t>(fw + Off::Framework::HostLogic, task);
                if (am > 0x1000000 && am < 0x300000000 && hl > 0x1000000 && hl < 0x300000000) {
                    framework = fw;
                    break;
                }
            }
        }
        if (framework > 0x1000000) {
            cached_framework = framework;
        } else {
            framework = cached_framework;
        }

        if (framework == 0) {
            [self clearAllBoxes];
            [self publishStatus:@"Waiting for match start..." players:0 tone:@"warn"];
            return;
        }

        // ── 3. ActorManager ───────────────────────────────────────────────────
        mach_vm_address_t actorMgr = Read<mach_vm_address_t>(framework + Off::Framework::ActorManager, task);
        int heroCount = 0;
        mach_vm_address_t itemsArr = 0;

        // ── 4. Retrieve HeroActors List ───────────────────────────────────────
        if (actorMgr > 0x1000000) {
            mach_vm_address_t heroList = Read<mach_vm_address_t>(actorMgr + Off::Framework::ActorManagerHeroes, task);
            if (heroList > 0x1000000) {
                int readHeroCount = Read<int>(heroList + Off::Runtime::ListSize, task);
                mach_vm_address_t readItemsArr = Read<mach_vm_address_t>(heroList + Off::Runtime::ListItems, task);
                if (readItemsArr > 0x1000000 && readHeroCount >= 0 && readHeroCount <= 20) {
                    heroCount = readHeroCount;
                    itemsArr = readItemsArr;
                }
            }
        }

        // ── 5. Local Player ID (HostLogic) ────────────────────────────────────
        uint32_t localPlayerId = 0;
        mach_vm_address_t hostLogic = Read<mach_vm_address_t>(framework + Off::Framework::HostLogic, task);
        if (hostLogic > 0x1000000) {
            localPlayerId = Read<uint32_t>(hostLogic + Off::Framework::HostPlayerId, task);
        }

        // ── 6. Resolve Active Camera from CameraSystem ──────────────────────
        // Auto-refresh csStaticFields every 300 frames (~5s) so ESP recovers
        // if the game restarts or the pointer chain becomes stale mid-match.
        staticRefreshTimer++;
        if (staticRefreshTimer >= 300) {
            staticRefreshTimer = 0;
            csStaticFields = 0; // force re-read next iteration
        }

        mach_vm_address_t csInstance = 0;
        mach_vm_address_t mobaCam = 0;

        if (!csStaticFields) {
            mach_vm_address_t csMethodInfo = Read<mach_vm_address_t>(cached_base + Off::Image::CameraSystemClassGlobal, task);
            if (csMethodInfo > 0x1000000) {
                mach_vm_address_t csKlass = Read<mach_vm_address_t>(csMethodInfo + Off::Runtime::MethodInfoKlass, task);
                if (csKlass > 0x1000000) {
                    mach_vm_address_t tryFields = Read<mach_vm_address_t>(csKlass + Off::Runtime::KlassStaticFields, task);
                    if (tryFields > 0x1000000) {
                        csStaticFields = tryFields;
                    }
                }
            }
        }

        if (csStaticFields > 0x1000000) {
            csInstance = Read<mach_vm_address_t>(csStaticFields + Off::Camera::StaticInstance, task);
            if (csInstance > 0x1000000) {
                mobaCam = Read<mach_vm_address_t>(csInstance + Off::Camera::MobaCamera, task);
            } else {
                // csInstance not yet created (pre-match) — invalidate so we retry
                csStaticFields = 0;
            }
        }

        mach_vm_address_t camObj = 0;
        mach_vm_address_t cameraReqs = 0;
        static task_t cachedCameraChainTask = MACH_PORT_NULL;
        static mach_vm_address_t cachedCameraObj = 0;
        static mach_vm_address_t cachedCameraReqs = 0;
        static mach_vm_address_t cachedCameraTransform = 0;
        static mach_vm_address_t cachedCameraPivot = 0;
        if (csInstance > 0x1000000) {
            camObj = Read<mach_vm_address_t>(csInstance + Off::Camera::MainCamera, task);
        }
        if (mobaCam > 0x1000000) {
            float camZoom = cfg_get_float(ESPSettingCameraZoom, 15.0f);
            if (camZoom > 5.0f) {
                Write<float>(mobaCam + 0x90, camZoom, task); // currentZoomAmount
                
                // Override maxZoom to allow zooming beyond game's default limit
                mach_vm_address_t settings = Read<mach_vm_address_t>(mobaCam + 0x78, task);
                if (settings > 0x1000000) {
                    mach_vm_address_t zoomObj = Read<mach_vm_address_t>(settings + 0x38, task);
                    if (zoomObj > 0x1000000) {
                        Write<float>(zoomObj + 0x14, 100.0f, task); // maxZoom
                    }
                }
            }

            cameraReqs = Read<mach_vm_address_t>(mobaCam + Off::Camera::Requirements, task);
            if ((camObj < 0x1000000) && (cameraReqs > 0x1000000)) {
                camObj = Read<mach_vm_address_t>(cameraReqs + Off::Camera::RequirementsCamera, task);
            }
        }

        // CameraSystem.MobaCamera can temporarily become null while the player
        // drags/releases the map.  The managed Camera/Transform objects remain
        // alive, so retain that pointer chain and continue reading the current
        // Transform instead of freezing the old VP matrix.
        if (cachedCameraChainTask != task) {
            cachedCameraChainTask = task;
            cachedCameraObj = 0;
            cachedCameraReqs = 0;
            cachedCameraTransform = 0;
            cachedCameraPivot = 0;
        }
        if (camObj > 0x1000000) {
            if (cachedCameraObj > 0x1000000 && cachedCameraObj != camObj) {
                cachedCameraReqs = 0;
                cachedCameraTransform = 0;
                cachedCameraPivot = 0;
            }
            cachedCameraObj = camObj;
        } else {
            camObj = cachedCameraObj;
        }
        if (cameraReqs > 0x1000000) {
            cachedCameraReqs = cameraReqs;
        } else {
            cameraReqs = cachedCameraReqs;
        }

        // Build VP from the live camera Transform and AoV's 30-degree FOV.
        static SO2_Matrix cachedViewMatrix = {};
        static bool cachedViewMatrixValid = false;
        static task_t cachedViewMatrixTask = MACH_PORT_NULL;
        static mach_vm_address_t cachedViewMatrixCamera = 0;
        static int cachedViewMatrixAge = 0;
        SO2_Matrix viewMatrix = {};
        bool viewMatrixValid = false;
        CameraTransformData cameraData = {};
        CameraTransformData pivotData = {};
        mach_vm_address_t camTransform = 0;
        mach_vm_address_t camPivot = 0;

        // Never reuse a matrix belonging to an earlier game task or camera.
        if (cachedViewMatrixTask != task ||
            (cachedViewMatrixCamera > 0x1000000 && camObj > 0x1000000 &&
             cachedViewMatrixCamera != camObj)) {
            cachedViewMatrix = {};
            cachedViewMatrixValid = false;
            cachedViewMatrixCamera = 0;
            cachedViewMatrixAge = 0;
            cachedViewMatrixTask = task;
        }

        if (camObj > 0x1000000) {
            if (cameraReqs > 0x1000000) {
                camPivot = Read<mach_vm_address_t>(cameraReqs + Off::Camera::RequirementsPivot, task);
                camTransform = Read<mach_vm_address_t>(cameraReqs + Off::Camera::RequirementsTransform, task);
            }
            if (camPivot > 0x1000000) cachedCameraPivot = camPivot;
            else camPivot = cachedCameraPivot;
            if (camTransform > 0x1000000) cachedCameraTransform = camTransform;
            else camTransform = cachedCameraTransform;

            if (camPivot > 0x1000000) {
                pivotData = get_camera_transform(camPivot, task);
            }

            if (camTransform > 0x1000000) {
                cameraData = get_camera_transform(camTransform, task);

                if (cameraData.valid) {
                    float cameraAspect = (float)self.bounds.size.width / (float)self.bounds.size.height;
                    if (cameraAspect > 0.1f && cameraAspect < 10.0f) {
                        viewMatrix = BuildVPMatrix(cameraData, Off::Camera::FieldOfView, cameraAspect, 0.3f, 1200.0f);
                        viewMatrixValid = std::isfinite(viewMatrix.m11) &&
                                          std::isfinite(viewMatrix.m22) &&
                                          std::isfinite(viewMatrix.m34) &&
                                          std::isfinite(viewMatrix.m44);
                    }
                }
            }
        }

        // Keep last good matrix — ESP stays valid between frames even if cam briefly fails
        if (viewMatrixValid) {
            cachedViewMatrix = viewMatrix;
            cachedViewMatrixValid = true;
            cachedViewMatrixCamera = camObj;
            cachedViewMatrixAge = 0;
        } else if (cachedViewMatrixValid && ++cachedViewMatrixAge <= 8) {
            viewMatrix = cachedViewMatrix;
            viewMatrixValid = true;
        } else if (cachedViewMatrixAge > 8) {
            cachedViewMatrixValid = false;
        }




        int localTeam = 0;
        if (cached_localTeam == 0) {
            for (int i = 0; i < heroCount; i++) {
                mach_vm_address_t actor = Read<mach_vm_address_t>(itemsArr + Off::Runtime::HandleArrayObject + i * Off::Runtime::HandleStride, task);
                if (!actor || actor < 0x1000000) continue;
                uint32_t pid2 = Read<uint32_t>(actor + Off::ActorLinker::PlayerId, task);
                if (pid2 == localPlayerId && localPlayerId != 0) {
                    cached_localTeam = Read<int>(actor + Off::ActorLinker::Camp, task);
                    break;
                }
            }
        }
        localTeam = cached_localTeam;

        // Logic actors use VInt3 coordinates, while the rendered Unity scene
        // may be mirrored 180 degrees for the current side. Learn the X/Z
        // mapping from any live ActorLinker Transform; fall back to the
        // CameraSystem mirror flag until a visual sample is available.
        static task_t logicMapTask = MACH_PORT_NULL;
        static bool logicMapCalibrated = false;
        static float logicToWorldXZSign = 1.0f;
        if (logicMapTask != task) {
            logicMapTask = task;
            logicMapCalibrated = false;
            logicToWorldXZSign = 1.0f;
        }
        if (!logicMapCalibrated) {
            logicToWorldXZSign = csInstance > 0x1000000 && Read<uint8_t>(csInstance + Off::Camera::Mirror, task) ? -1.0f : 1.0f;

            // Primary calibration: the camera pivot follows the host hero.
            // This compares both possible X/Z mappings in the exact coordinate
            // space used by the view matrix and still works when actor meshes
            // or their visual Transforms have not been created yet.
            if (pivotData.valid && localPlayerId != 0) {
                for (int i = 0; i < heroCount; i++) {
                    mach_vm_address_t actor = Read<mach_vm_address_t>(itemsArr + Off::Runtime::HandleArrayObject + i * Off::Runtime::HandleStride, task);
                    if (actor <= 0x1000000) continue;
                    uint32_t actorPlayerId = Read<uint32_t>(actor + Off::ActorLinker::PlayerId, task);
                    if (actorPlayerId != localPlayerId) continue;

                    VInt3 hostLoc = Read<VInt3>(actor + Off::ActorLinker::Location, task);
                    if (hostLoc.x == 0 && hostLoc.z == 0) break;
                    float logicX = (float)hostLoc.x / 1000.0f;
                    float logicZ = (float)hostLoc.z / 1000.0f;
                    float directError = (pivotData.position.x - logicX) * (pivotData.position.x - logicX) +
                                        (pivotData.position.z - logicZ) * (pivotData.position.z - logicZ);
                    float mirrorError = (pivotData.position.x + logicX) * (pivotData.position.x + logicX) +
                                        (pivotData.position.z + logicZ) * (pivotData.position.z + logicZ);
                    if (fminf(directError, mirrorError) < 2500.0f &&
                        fabsf(directError - mirrorError) > 400.0f) {
                        logicToWorldXZSign = mirrorError < directError ? -1.0f : 1.0f;
                        logicMapCalibrated = true;
                    }
                    break;
                }
            }

            // Secondary calibration for cases where the host entry is absent.
            // It is intentionally only used if pivot calibration did not run.
            for (int i = 0; i < heroCount; i++) {
                if (logicMapCalibrated) break;
                mach_vm_address_t actor = Read<mach_vm_address_t>(itemsArr + Off::Runtime::HandleArrayObject + i * Off::Runtime::HandleStride, task);
                if (actor <= 0x1000000) continue;

                VInt3 linkLoc = Read<VInt3>(actor + Off::ActorLinker::Location, task);
                mach_vm_address_t visualTransform = Read<mach_vm_address_t>(actor + Off::ActorLinker::MyTransform, task);
                if ((linkLoc.x == 0 && linkLoc.z == 0) || visualTransform <= 0x1000000) continue;

                Vector3 visualPos = get_position_by_transform(visualTransform, task);
                if (!std::isfinite(visualPos.x) || !std::isfinite(visualPos.z) ||
                    (fabsf(visualPos.x) < 0.001f && fabsf(visualPos.z) < 0.001f) ||
                    fabsf(visualPos.x) > 500.0f || fabsf(visualPos.z) > 500.0f) continue;

                float logicX = (float)linkLoc.x / 1000.0f;
                float logicZ = (float)linkLoc.z / 1000.0f;
                float directError = (visualPos.x - logicX) * (visualPos.x - logicX) +
                                    (visualPos.z - logicZ) * (visualPos.z - logicZ);
                float mirrorError = (visualPos.x + logicX) * (visualPos.x + logicX) +
                                    (visualPos.z + logicZ) * (visualPos.z + logicZ);

                // Require a decisive sample so interpolation noise cannot flip
                // the mapping during play.
                if (fminf(directError, mirrorError) < 100.0f &&
                    fabsf(directError - mirrorError) > 25.0f) {
                    logicToWorldXZSign = mirrorError < directError ? -1.0f : 1.0f;
                    logicMapCalibrated = true;
                    break;
                }
            }
        }

        // ── 7. Traverse Logic LActorRoot objects from GamePlayerCenter ───────
        static mach_vm_address_t cached_enemyRoots[40] = {0};
        static uint16_t cached_enemyRootMisses[40] = {0};
        static int cached_enemyRootCount = 0;
        static int rootCacheTimer = 0;
        static task_t cachedEnemyRootsTask = MACH_PORT_NULL;

        if (cachedEnemyRootsTask != task) {
            cachedEnemyRootsTask = task;
            cached_enemyRootCount = 0;
            memset(cached_enemyRoots, 0, sizeof(cached_enemyRoots));
            memset(cached_enemyRootMisses, 0, sizeof(cached_enemyRootMisses));
            rootCacheTimer = 0;
        }
 
        mach_vm_address_t logicBattleLogic = 0;
        // Also refresh coreStaticFields on the same timer as csStaticFields
        if (staticRefreshTimer == 1) {
            coreStaticFields = 0;
        }
        if (!coreStaticFields) {
            mach_vm_address_t methodInfo = Read<mach_vm_address_t>(cached_base + Off::Image::LogicCoreClassGlobal, task);
            if (methodInfo > 0x1000000) {
                mach_vm_address_t klass = Read<mach_vm_address_t>(methodInfo + Off::Runtime::MethodInfoKlass, task);
                if (klass > 0x1000000) {
                    mach_vm_address_t tryCore = Read<mach_vm_address_t>(klass + Off::Runtime::KlassStaticFields, task);
                    if (tryCore > 0x1000000) coreStaticFields = tryCore;
                }
            }
        }
        if (coreStaticFields > 0x1000000) {
            mach_vm_address_t logicCore = Read<mach_vm_address_t>(coreStaticFields + Off::Logic::StaticInstance, task);
            if (logicCore > 0x1000000) {
                mach_vm_address_t curDesk = Read<mach_vm_address_t>(logicCore + Off::Logic::CurDesk, task);
                if (curDesk > 0x1000000) {
                    logicBattleLogic = Read<mach_vm_address_t>(curDesk + Off::Logic::DeskBattleLogic, task);
                }
            }
        }
        // A missing logic chain is common during visibility/camera transitions.
        // Do not wipe every cached root just because that chain is unavailable.
        rootCacheTimer++;
        if (logicBattleLogic > 0x1000000 && (rootCacheTimer > 10 || cached_enemyRootCount == 0)) {
            rootCacheTimer = 0;

            // Prune only after many consecutive invalid reads. A single failed
            // mach read must not remove a hidden actor from the cache.
            int compactedRootCount = 0;
            for (int e = 0; e < cached_enemyRootCount; e++) {
                mach_vm_address_t cachedRoot = cached_enemyRoots[e];
                if (cachedRoot <= 0x1000000) continue;
                int cachedCamp = Read<int>(cachedRoot + Off::LActorRoot::Camp, task);
                uint32_t cachedPlayerId = Read<uint32_t>(cachedRoot + Off::LActorRoot::PlayerId, task);
                bool cachedRootValid = (cachedCamp == 1 || cachedCamp == 2) && cachedPlayerId != 0;
                if (cachedRootValid) {
                    cached_enemyRootMisses[e] = 0;
                } else if (cached_enemyRootMisses[e] < 0xFFFFu) {
                    cached_enemyRootMisses[e]++;
                }
                if (cachedRootValid || cached_enemyRootMisses[e] <= 120) {
                    int duplicateIndex = -1;
                    if (cachedRootValid) {
                        for (int c = 0; c < compactedRootCount; c++) {
                            uint32_t compactedPlayerId = Read<uint32_t>(cached_enemyRoots[c] + Off::LActorRoot::PlayerId, task);
                            if (compactedPlayerId == cachedPlayerId) {
                                duplicateIndex = c;
                                break;
                            }
                        }
                    }
                    if (duplicateIndex >= 0) {
                        // Prefer the most recently discovered object for this
                        // player when IL2CPP replaces an LActorRoot instance.
                        cached_enemyRoots[duplicateIndex] = cachedRoot;
                        cached_enemyRootMisses[duplicateIndex] = 0;
                        continue;
                    }
                    cached_enemyRoots[compactedRootCount++] = cachedRoot;
                    cached_enemyRootMisses[compactedRootCount - 1] = cached_enemyRootMisses[e];
                }
            }
            for (int e = compactedRootCount; e < cached_enemyRootCount; e++) {
                cached_enemyRoots[e] = 0;
                cached_enemyRootMisses[e] = 0;
            }
            cached_enemyRootCount = compactedRootCount;

            auto cacheOrReplaceRoot = [&](mach_vm_address_t newRoot) {
                if (newRoot <= 0x1000000) return;
                uint32_t newPlayerId = Read<uint32_t>(newRoot + Off::LActorRoot::PlayerId, task);
                for (int e = 0; e < cached_enemyRootCount; e++) {
                    if (cached_enemyRoots[e] == newRoot) {
                        cached_enemyRootMisses[e] = 0;
                        return;
                    }
                    uint32_t oldPlayerId = Read<uint32_t>(cached_enemyRoots[e] + Off::LActorRoot::PlayerId, task);
                    if (newPlayerId != 0 && oldPlayerId == newPlayerId) {
                        cached_enemyRoots[e] = newRoot;
                        cached_enemyRootMisses[e] = 0;
                        return;
                    }
                }
                if (cached_enemyRootCount < 40) {
                    cached_enemyRoots[cached_enemyRootCount] = newRoot;
                    cached_enemyRootMisses[cached_enemyRootCount] = 0;
                    cached_enemyRootCount++;
                }
            };

            mach_vm_address_t logicPlayerCenter = Read<mach_vm_address_t>(logicBattleLogic + Off::Logic::PlayerCenter, task);
            if (logicPlayerCenter > 0x1000000) {
                mach_vm_address_t playersListView = Read<mach_vm_address_t>(logicPlayerCenter + Off::Logic::PlayersListView, task);
                if (playersListView > 0x1000000) {
                    mach_vm_address_t playersList = Read<mach_vm_address_t>(playersListView + Off::Runtime::ListItems, task);
                    if (playersList > 0x1000000) {
                        int playersCount = Read<int>(playersList + Off::Runtime::ListSize, task);
                        mach_vm_address_t playersArr = Read<mach_vm_address_t>(playersList + Off::Runtime::ListItems, task);
                        if (playersArr > 0x1000000 && playersCount > 0 && playersCount <= 20) {
                            for (int j = 0; j < playersCount; j++) {
                                mach_vm_address_t player = Read<mach_vm_address_t>(playersArr + Off::Runtime::ArrayData + j * Off::Runtime::PointerStride, task);
                                if (!player || player < 0x1000000) continue;
                                
                                mach_vm_address_t captainRoot = Read<mach_vm_address_t>(player + Off::Logic::PlayerCaptain, task);
                                cacheOrReplaceRoot(captainRoot);
                                
                                mach_vm_address_t heroesList = Read<mach_vm_address_t>(player + Off::Logic::PlayerHeroes, task);
                                if (heroesList > 0x1000000) {
                                    int heroesCount = Read<int>(heroesList + Off::Runtime::ListSize, task);
                                    mach_vm_address_t heroesArr = Read<mach_vm_address_t>(heroesList + Off::Runtime::ListItems, task);
                                    if (heroesArr > 0x1000000 && heroesCount > 0 && heroesCount <= 20) {
                                        for (int k = 0; k < heroesCount; k++) {
                                            mach_vm_address_t actorRoot = Read<mach_vm_address_t>(heroesArr + Off::Runtime::HandleArrayObject + k * Off::Runtime::HandleStride, task);
                                            cacheOrReplaceRoot(actorRoot);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
 
        int enemyRootCount = 0;
        mach_vm_address_t enemyRoots[40] = {0};
        for (int e = 0; e < cached_enemyRootCount; e++) {
            mach_vm_address_t root = cached_enemyRoots[e];
            if (root <= 0x1000000) continue;
            int camp = Read<int>(root + Off::LActorRoot::Camp, task);
            uint32_t playerId = Read<uint32_t>(root + Off::LActorRoot::PlayerId, task);
            if ((camp != 1 && camp != 2) || playerId == 0) continue;

            int duplicateIndex = -1;
            for (int n = 0; n < enemyRootCount; n++) {
                uint32_t existingPlayerId = Read<uint32_t>(enemyRoots[n] + Off::LActorRoot::PlayerId, task);
                if (existingPlayerId == playerId) {
                    duplicateIndex = n;
                    break;
                }
            }
            if (duplicateIndex >= 0) enemyRoots[duplicateIndex] = root;
            else if (enemyRootCount < 40) enemyRoots[enemyRootCount++] = root;
        }

        if (cached_localTeam == 0 && localPlayerId != 0) {
            for (int e = 0; e < enemyRootCount; e++) {
                mach_vm_address_t root = enemyRoots[e];
                if (Read<uint32_t>(root + Off::LActorRoot::PlayerId, task) != localPlayerId) continue;
                int rootTeam = Read<int>(root + Off::LActorRoot::Camp, task);
                if (rootTeam == 1 || rootTeam == 2) {
                    cached_localTeam = rootTeam;
                    localTeam = rootTeam;
                }
                break;
            }
        }

        // ActorManager frequently reports heroCount=0 while the logic roots
        // remain valid. Use the local LActorRoot as a late calibration source
        // so the mapping cannot stay on the +1 fallback seen in the video.
        if (!logicMapCalibrated && pivotData.valid && localPlayerId != 0) {
            for (int e = 0; e < enemyRootCount; e++) {
                mach_vm_address_t root = enemyRoots[e];
                uint32_t rootPlayerId = Read<uint32_t>(root + Off::LActorRoot::PlayerId, task);
                if (rootPlayerId != localPlayerId) continue;
                if (cached_localTeam == 0) {
                    int rootTeam = Read<int>(root + Off::LActorRoot::Camp, task);
                    if (rootTeam == 1 || rootTeam == 2) {
                        cached_localTeam = rootTeam;
                        localTeam = rootTeam;
                    }
                }
                VInt3 hostLoc = Read<VInt3>(root + Off::LActorRoot::Location, task);
                if (hostLoc.x == 0 && hostLoc.z == 0) break;

                float logicX = (float)hostLoc.x / 1000.0f;
                float logicZ = (float)hostLoc.z / 1000.0f;
                float directError = (pivotData.position.x - logicX) * (pivotData.position.x - logicX) +
                                    (pivotData.position.z - logicZ) * (pivotData.position.z - logicZ);
                float mirrorError = (pivotData.position.x + logicX) * (pivotData.position.x + logicX) +
                                    (pivotData.position.z + logicZ) * (pivotData.position.z + logicZ);
                if (fminf(directError, mirrorError) < 2500.0f &&
                    fabsf(directError - mirrorError) > 400.0f) {
                    logicToWorldXZSign = mirrorError < directError ? -1.0f : 1.0f;
                    logicMapCalibrated = true;
                }
                break;
            }
        }

        // Final fallback when HostPlayerId is temporarily unavailable: choose
        // the mapping that puts the camera pivot nearest to the current hero
        // roots. This is still a comparison in camera world space, not a hard
        // coded team-side assumption.
        if (!logicMapCalibrated && pivotData.valid && enemyRootCount > 0) {
            float bestDirectError = INFINITY;
            float bestMirrorError = INFINITY;
            VInt3 bestDirectLoc = {};
            VInt3 bestMirrorLoc = {};
            for (int e = 0; e < enemyRootCount; e++) {
                VInt3 candidate = Read<VInt3>(enemyRoots[e] + Off::LActorRoot::Location, task);
                if (candidate.x == 0 && candidate.z == 0) continue;
                float logicX = (float)candidate.x / 1000.0f;
                float logicZ = (float)candidate.z / 1000.0f;
                float directError = (pivotData.position.x - logicX) * (pivotData.position.x - logicX) +
                                    (pivotData.position.z - logicZ) * (pivotData.position.z - logicZ);
                float mirrorError = (pivotData.position.x + logicX) * (pivotData.position.x + logicX) +
                                    (pivotData.position.z + logicZ) * (pivotData.position.z + logicZ);
                if (directError < bestDirectError) {
                    bestDirectError = directError;
                    bestDirectLoc = candidate;
                }
                if (mirrorError < bestMirrorError) {
                    bestMirrorError = mirrorError;
                    bestMirrorLoc = candidate;
                }
            }
            if (fminf(bestDirectError, bestMirrorError) < 2500.0f &&
                fabsf(bestDirectError - bestMirrorError) > 400.0f) {
                bool mirrored = bestMirrorError < bestDirectError;
                logicToWorldXZSign = mirrored ? -1.0f : 1.0f;
                logicMapCalibrated = true;
            }
        }
 
        // ── 8. Draw paths setup ───────────────────────────────────────────────
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
 
        NSUInteger nameIdx = 0, iconIdx = 0, miniMapIconIdx = 0, hpIdx = 0;
        CGRect miniMapRect = ESPMiniMapRect(w, h);
        UIBezierPath *miniMapOutlinePath = [UIBezierPath bezierPathWithRect:miniMapRect];
 
        UIBezierPath *boxPath          = [UIBezierPath bezierPath];
        UIBezierPath *boxFillPath      = [UIBezierPath bezierPath];
        UIBezierPath *boxOutlinePath   = [UIBezierPath bezierPath];
        UIBezierPath *linesPath        = [UIBezierPath bezierPath];
        UIBezierPath *linesMidPath     = [UIBezierPath bezierPath];
        UIBezierPath *linesLowPath     = [UIBezierPath bezierPath];
        UIBezierPath *lineOutlinePath  = [UIBezierPath bezierPath];
        UIBezierPath *healthBarPath    = [UIBezierPath bezierPath];
        UIBezierPath *healthBarMidPath = [UIBezierPath bezierPath];
        UIBezierPath *healthBarLowPath = [UIBezierPath bezierPath];
        UIBezierPath *healthBarOutPath = [UIBezierPath bezierPath];
 
        int validPlayers = 0;
        int trackedPlayers = 0;
        
        static struct EnemyCache {
            uint32_t playerId;
            Vector3 lastPos;
            int lastHp;
            int lastMaxHp;
            int missingFrames;
            char cachedName[64];
        } enemyCache[40] = {};
 
        for (int r = 0; r < enemyRootCount; r++) {
            mach_vm_address_t root = enemyRoots[r];
            if (!root || root < 0x1000000) continue;
            
            int camp = Read<int>(root + Off::LActorRoot::Camp, task);
            if (camp != 1 && camp != 2) continue; // Only process player heroes
            if (esp_team_check && localTeam != 0 && camp == localTeam) continue;
            
            uint32_t playerId = Read<uint32_t>(root + Off::LActorRoot::PlayerId, task);
            if (playerId == localPlayerId && localPlayerId != 0) continue;
            trackedPlayers++;

            // Resolve the matching visual ActorLinker once. Besides its render
            // Transform it exposes ValueComponent.actorHpTotal directly, which
            // is the same total HP used by the in-game health UI.
            mach_vm_address_t matchedActor = 0;
            for (int i = 0; i < heroCount; i++) {
                mach_vm_address_t actor = Read<mach_vm_address_t>(itemsArr + Off::Runtime::HandleArrayObject + i * Off::Runtime::HandleStride, task);
                if (actor <= 0x1000000) continue;
                if (Read<uint32_t>(actor + Off::ActorLinker::PlayerId, task) == playerId) {
                    matchedActor = actor;
                    break;
                }
            }
            
            int cacheIdx = -1;
            for (int c = 0; c < 40; c++) {
                if (enemyCache[c].playerId == playerId) {
                    cacheIdx = c;
                    break;
                }
            }
            if (cacheIdx == -1) {
                for (int c = 0; c < 40; c++) {
                    if (enemyCache[c].playerId == 0) {
                        cacheIdx = c;
                        enemyCache[c].playerId = playerId;
                        break;
                    }
                }
            }
            
            int hp = -1;
            int maxHp = -1;
            int linkerHp = -1;
            int linkerMaxHp = -1;
            bool hpFromLinker = false;
            if (matchedActor > 0x1000000) {
                mach_vm_address_t valueComponent = Read<mach_vm_address_t>(matchedActor + Off::ActorLinker::ValueComponent, task);
                if (valueComponent > 0x1000000) {
                    linkerHp = Read<int>(valueComponent + Off::Value::LinkerHp, task);
                    linkerMaxHp = Read<int>(valueComponent + Off::Value::LinkerHpTotal, task);
                    bool linkerHpValid = linkerHp >= 0 && linkerHp <= 100000;
                    bool linkerMaxValid = linkerMaxHp > 0 && linkerMaxHp <= 100000 && linkerMaxHp >= linkerHp;
                    if (linkerHpValid) {
                        hp = linkerHp;
                        hpFromLinker = true;
                    }
                    if (linkerHpValid && linkerMaxValid) {
                        maxHp = linkerMaxHp;
                    }
                }
            }

            mach_vm_address_t valPropComp = Read<mach_vm_address_t>(root + Off::LActorRoot::ValuePropertyComponent, task);
            if (hp < 0 && valPropComp > 0x1000000) {
                int decryptVal = Read<int>(valPropComp + Off::Value::CurrentHpValue, task);
                int crypticVal = Read<int>(valPropComp + Off::Value::CurrentHpKey, task);
                hp = decryptVal ^ crypticVal;
            }
            
            if (hp < 0 || hp > 100000) {
                if (cacheIdx != -1 && enemyCache[cacheIdx].lastHp > 0) {
                    hp = enemyCache[cacheIdx].lastHp;
                } else {
                    hp = 100;
                }
            } else if (hp == 0) {
                if (hpFromLinker) {
                    // ActorLinker HP is authoritative when available; this is a dead hero.
                    continue;
                }
                if (cacheIdx != -1 && enemyCache[cacheIdx].lastHp > 0) {
                    hp = enemyCache[cacheIdx].lastHp;
                } else {
                    // At match start hidden LActorRoot HP may still be zero.
                    // Keep drawing its position and let ActorLinker correct HP when visible.
                    hp = 100;
                }
            }
            
            if (cacheIdx != -1) {
                enemyCache[cacheIdx].lastHp = hp;
            }
            
            // Hidden/not-yet-linked actors may not have ValueComponent. Keep
            // the encrypted property calculation only as a fallback.
            if (maxHp <= 0 && valPropComp > 0x1000000) {
                mach_vm_address_t mActorValue = Read<mach_vm_address_t>(valPropComp + Off::Value::ActorValue, task);
                if (mActorValue > 0x1000000) {
                    mach_vm_address_t valDataArr = Read<mach_vm_address_t>(mActorValue + Off::Value::PropertyArray, task);
                    if (valDataArr > 0x1000000) {
                        mach_vm_address_t maxHpValData = Read<mach_vm_address_t>(valDataArr + Off::Value::MaxHpArrayEntry, task);
                        if (maxHpValData > 0x1000000) {
                            int decryptBase = Read<int>(maxHpValData + Off::Value::BaseValue, task);
                            int crypticBase = Read<int>(maxHpValData + Off::Value::BaseValueKey, task);
                            int baseValue = decryptBase ^ crypticBase;

                            int decryptGrow = Read<int>(maxHpValData + Off::Value::GrowValue, task);
                            int crypticGrow = Read<int>(maxHpValData + Off::Value::GrowValueKey, task);
                            int growValue = decryptGrow ^ crypticGrow;

                            int decryptAdd = Read<int>(maxHpValData + Off::Value::AddValue, task);
                            int crypticAdd = Read<int>(maxHpValData + Off::Value::AddValueKey, task);
                            int addValue = decryptAdd ^ crypticAdd;

                            int decryptDec = Read<int>(maxHpValData + Off::Value::DecValue, task);
                            int crypticDec = Read<int>(maxHpValData + Off::Value::DecValueKey, task);
                            int decValue = decryptDec ^ crypticDec;

                            int decryptAddRatio = Read<int>(maxHpValData + Off::Value::AddRatio, task);
                            int crypticAddRatio = Read<int>(maxHpValData + Off::Value::AddRatioKey, task);
                            int addRatio = decryptAddRatio ^ crypticAddRatio;

                            int decryptDecRatio = Read<int>(maxHpValData + Off::Value::DecRatio, task);
                            int crypticDecRatio = Read<int>(maxHpValData + Off::Value::DecRatioKey, task);
                            int decRatio = decryptDecRatio ^ crypticDecRatio;

                            int decryptAddOff = Read<int>(maxHpValData + Off::Value::AddOffRatio, task);
                            int crypticAddOff = Read<int>(maxHpValData + Off::Value::AddOffRatioKey, task);
                            int addValueOffRatio = decryptAddOff ^ crypticAddOff;

                            int coreVal = baseValue + growValue + addValue - decValue;
                            int ratio = 10000 + addRatio - decRatio;
                            if (ratio < 0) ratio = 0;
                            maxHp = (coreVal * ratio) / 10000 + addValueOffRatio;
                        }
                    }
                }
            }
            if (maxHp < hp || maxHp > 100000) {
                if (cacheIdx != -1 && enemyCache[cacheIdx].lastMaxHp >= hp) {
                    maxHp = enemyCache[cacheIdx].lastMaxHp;
                } else {
                    maxHp = hp;
                }
            }
            if (maxHp < 100) maxHp = 100;
            if (cacheIdx != -1) enemyCache[cacheIdx].lastMaxHp = maxHp;
            float healthPct = maxHp > 0 ? (float)hp / (float)maxHp : 1.0f;
            healthPct = fmaxf(0.0f, fminf(healthPct, 1.0f));
            
            VInt3 loc = Read<VInt3>(root + Off::LActorRoot::Location, task);
            Vector3 pos;
            int positionSource = 1;
            mach_vm_address_t visualTransform = 0;
            bool validPos = (loc.x != 0 || loc.z != 0);
            int heroConfigID = 0;
            NSString *heroName = nil;

            CGPoint miniPoint = CGPointZero;
            BOOL hasMiniPos = NO;
            if (validPos) {
                miniPoint = ESPMiniMapPointForLocation(loc, localTeam, miniMapRect);
                hasMiniPos = YES;
            } else if (cacheIdx != -1 && (enemyCache[cacheIdx].lastPos.x != 0 || enemyCache[cacheIdx].lastPos.z != 0)) {
                Vector3 cachedPos = enemyCache[cacheIdx].lastPos;
                VInt3 cachedLoc = {(int)(cachedPos.x * 1000.0f), 0, (int)(cachedPos.z * 1000.0f)};
                miniPoint = ESPMiniMapPointForLocation(cachedLoc, localTeam, miniMapRect);
                hasMiniPos = YES;
            }
            if (!hasMiniPos && matchedActor > 0x1000000) {
                mach_vm_address_t miniTransform = Read<mach_vm_address_t>(matchedActor + Off::ActorLinker::MyTransform, task);
                if (miniTransform > 0x1000000) {
                    Vector3 miniWorld = get_position_by_transform(miniTransform, task);
                    if (std::isfinite(miniWorld.x) && std::isfinite(miniWorld.z) &&
                        fabsf(miniWorld.x) < 500.0f && fabsf(miniWorld.z) < 500.0f) {
                        VInt3 miniLoc = {(int)(miniWorld.x * 1000.0f), 0, (int)(miniWorld.z * 1000.0f)};
                        miniPoint = ESPMiniMapPointForLocation(miniLoc, localTeam, miniMapRect);
                        hasMiniPos = YES;
                    }
                }
            }

            if (esp_minimap_enabled && hasMiniPos && miniMapIconIdx < self.miniMapIconViewPool.count) {
                heroConfigID = ReadHeroConfigID(task, root, matchedActor);
                UIImage *iconImage = HeroIconForConfigID(heroConfigID);
                UIImageView *miniIcon = self.miniMapIconViewPool[miniMapIconIdx++];
                CGFloat miniSize = fminf(fmaxf(esp_minimap_icon_size, 12.0f), 60.0f);
                UIImageView *innerIcon = (UIImageView *)[miniIcon viewWithTag:991];

                miniIcon.image = nil;
                miniIcon.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.9f];
                miniIcon.layer.cornerRadius = miniSize / 2.0f;
                miniIcon.layer.borderColor = [UIColor redColor].CGColor;
                miniIcon.layer.borderWidth = 1.4f;
                miniIcon.frame = CGRectMake(miniPoint.x - miniSize / 2.0f,
                                            miniPoint.y - miniSize / 2.0f,
                                            miniSize,
                                            miniSize);
                if (innerIcon) {
                    CGFloat inset = fmaxf(2.0f, miniSize * 0.14f);
                    innerIcon.frame = CGRectInset(miniIcon.bounds, inset, inset);
                    innerIcon.image = iconImage;
                    innerIcon.hidden = (iconImage == nil);
                }
                miniIcon.hidden = NO;
            }
            if (validPos) {
                pos.x = logicToWorldXZSign * (float)loc.x / 1000.0f;
                pos.y = (float)loc.y / 1000.0f;
                pos.z = logicToWorldXZSign * (float)loc.z / 1000.0f;

                // The logic Y coordinate is not the rendered terrain/model Y
                // (the v4 log shows local logic Y=0.2 while its Transform Y=1.4).
                // For a currently visible hero, anchor ESP to the exact render
                // Transform. Hidden heroes keep using the continuously updated
                // LActorRoot position so the external ESP still tracks them.
                if (matchedActor > 0x1000000) {
                    bool actorVisible = Read<uint8_t>(matchedActor + Off::ActorLinker::Visible, task) != 0;
                    visualTransform = Read<mach_vm_address_t>(matchedActor + Off::ActorLinker::MyTransform, task);
                    if (actorVisible && visualTransform > 0x1000000) {
                        Vector3 visualPos = get_position_by_transform(visualTransform, task);
                        float logicX = logicToWorldXZSign * (float)loc.x / 1000.0f;
                        float logicZ = logicToWorldXZSign * (float)loc.z / 1000.0f;
                        bool visualFinite = std::isfinite(visualPos.x) &&
                                            std::isfinite(visualPos.y) &&
                                            std::isfinite(visualPos.z);
                        bool visualNearLogic = fabsf(visualPos.x - logicX) < 15.0f &&
                                               fabsf(visualPos.z - logicZ) < 15.0f;
                        if (visualFinite && visualNearLogic &&
                            fabsf(visualPos.x) < 500.0f && fabsf(visualPos.y) < 500.0f &&
                            fabsf(visualPos.z) < 500.0f) {
                            pos = visualPos;
                            positionSource = 2;
                        }
                    }
                }

                if (cacheIdx != -1) {
                    // Unity has already interpolated a visible Transform. Do
                    // not smooth it again, otherwise the box trails the model
                    // whenever either the hero or the camera is moving.
                    if (positionSource == 1 && enemyCache[cacheIdx].lastPos.x != 0) {
                        pos.x = enemyCache[cacheIdx].lastPos.x * 0.15f + pos.x * 0.85f;
                        pos.y = enemyCache[cacheIdx].lastPos.y * 0.15f + pos.y * 0.85f;
                        pos.z = enemyCache[cacheIdx].lastPos.z * 0.15f + pos.z * 0.85f;
                    }
                    enemyCache[cacheIdx].lastPos = pos;
                    enemyCache[cacheIdx].missingFrames = 0;
                }
            } else {
                if (cacheIdx != -1 && enemyCache[cacheIdx].missingFrames < 10 && enemyCache[cacheIdx].lastPos.x != 0) {
                    pos = enemyCache[cacheIdx].lastPos;
                    enemyCache[cacheIdx].missingFrames++;
                } else {
                    continue;
                }
            }
            
            Vector3 screen;
            Vector3 headScreen = {0.0f, 0.0f, -1.0f};
            if (viewMatrixValid) {
                if (positionSource == 1 && !logicMapCalibrated && validPos) {
                    Vector3 directPos = pos;
                    directPos.x = (float)loc.x / 1000.0f;
                    directPos.z = (float)loc.z / 1000.0f;

                    Vector3 mirrorPos = directPos;
                    mirrorPos.x = -mirrorPos.x;
                    mirrorPos.z = -mirrorPos.z;

                    Vector3 directHead = directPos;
                    directHead.y += 2.0f;
                    Vector3 mirrorHead = mirrorPos;
                    mirrorHead.y += 2.0f;

                    Vector3 directScreen = WorldToScreen(directPos, viewMatrix, w, h);
                    Vector3 directHeadScreen = WorldToScreen(directHead, viewMatrix, w, h);
                    Vector3 mirrorScreen = WorldToScreen(mirrorPos, viewMatrix, w, h);
                    Vector3 mirrorHeadScreen = WorldToScreen(mirrorHead, viewMatrix, w, h);

                    bool directOnScreen = directScreen.z > 0.01f && directHeadScreen.z > 0.01f &&
                                          directScreen.x > -w * 0.35f && directScreen.x < w * 1.35f &&
                                          directScreen.y > -h * 0.35f && directScreen.y < h * 1.35f;
                    bool mirrorOnScreen = mirrorScreen.z > 0.01f && mirrorHeadScreen.z > 0.01f &&
                                          mirrorScreen.x > -w * 0.35f && mirrorScreen.x < w * 1.35f &&
                                          mirrorScreen.y > -h * 0.35f && mirrorScreen.y < h * 1.35f;

                    if (directOnScreen != mirrorOnScreen) {
                        pos = directOnScreen ? directPos : mirrorPos;
                    } else if (directOnScreen && pivotData.valid) {
                        float directError = (pivotData.position.x - directPos.x) * (pivotData.position.x - directPos.x) +
                                            (pivotData.position.z - directPos.z) * (pivotData.position.z - directPos.z);
                        float mirrorError = (pivotData.position.x - mirrorPos.x) * (pivotData.position.x - mirrorPos.x) +
                                            (pivotData.position.z - mirrorPos.z) * (pivotData.position.z - mirrorPos.z);
                        pos = directError <= mirrorError ? directPos : mirrorPos;
                    }
                }

                screen = WorldToScreen(pos, viewMatrix, w, h);
                Vector3 headPos = pos;
                headPos.y += 2.0f; // same render-space hero height used by AOVNoHookate
                headScreen = WorldToScreen(headPos, viewMatrix, w, h);
            } else {
                // No fake top-down fallback: it placed boxes at arbitrary
                // screen coordinates unrelated to the active camera.
                continue;
            }
            if (screen.z <= 0.01f || headScreen.z <= 0.01f) continue;
 
            validPlayers++;
            // Build the rectangle from projected feet/head. The old fixed
            // 40x60 rectangle was centered on the feet, putting half of it
            // below the ground and making it slide/scale incorrectly while
            // panning. This mirrors the working injected implementation.
            CGFloat footX = screen.x;
            CGFloat footY = screen.y;
            CGFloat headY = headScreen.y;
            float bh = fabsf((float)(footY - headY));
            if (!std::isfinite(bh) || bh < 2.0f || bh > h * 1.5f) continue;
            float bw = bh * 0.75f;
            CGFloat topY = fminf((float)headY, (float)footY);
            CGFloat bottomY = fmaxf((float)headY, (float)footY);
            CGFloat sx = footX;

            if (esp_box_enabled) {
                CGRect rect = CGRectMake(sx - bw/2, topY, bw, bh);
                [boxPath appendPath:[UIBezierPath bezierPathWithRect:rect]];
                [boxOutlinePath appendPath:[UIBezierPath bezierPathWithRect:CGRectInset(rect,-1.2f,-1.2f)]];
                if (esp_box_fill)
                    [boxFillPath appendPath:[UIBezierPath bezierPathWithRect:rect]];
            }
 
            if (esp_line_enabled) {
                // Line anchors to the top edge of the box so it does not cross the HP/text area below.
                CGPoint lineStart = CGPointMake(w / 2.0f, 55.0f);
                CGPoint lineEnd = CGPointMake(sx, topY);
                UIBezierPath *healthLinePath = healthPct > 0.60f ? linesPath :
                                               (healthPct > 0.30f ? linesMidPath : linesLowPath);
                [healthLinePath moveToPoint:lineStart];
                [healthLinePath addLineToPoint:lineEnd];
                [lineOutlinePath moveToPoint:lineStart];
                [lineOutlinePath addLineToPoint:lineEnd];
            }
 
            CGFloat nameY = topY - 10.0f;

            if (esp_name_enabled && nameIdx < self.nameLabelPool.count) {
                if (cacheIdx != -1 && strlen(enemyCache[cacheIdx].cachedName) > 0) {
                    NSString *cachedHeroName = [NSString stringWithUTF8String:enemyCache[cacheIdx].cachedName];
                    if (!IsGenericHeroName(cachedHeroName)) heroName = cachedHeroName;
                } else {
                    mach_vm_address_t charInfo = Read<mach_vm_address_t>(root + Off::LActorRoot::CharInfo, task);
                    if (charInfo > 0x1000000) {
                        mach_vm_address_t namePtr = Read<mach_vm_address_t>(charInfo + Off::Name::ActorName, task);
                        int len = Read<int>(namePtr + Off::Runtime::StringLength, task);
                        if (len > 0 && len <= 100) {
                            unichar buffer[100] = {0};
                            mach_vm_size_t out_size = 0;
                            kern_return_t kr = mach_vm_read_overwrite(task, namePtr + Off::Runtime::StringChars, len * 2,
                                                                       (mach_vm_address_t)buffer, &out_size);
                            if (kr == KERN_SUCCESS) {
                                heroName = [NSString stringWithCharacters:buffer length:len];
                                if (!IsGenericHeroName(heroName) && cacheIdx != -1) {
                                    strncpy(enemyCache[cacheIdx].cachedName, [heroName UTF8String], 63);
                                    enemyCache[cacheIdx].cachedName[63] = '\0';
                                }
                            }
                        }
                    }
                }
                if (IsGenericHeroName(heroName)) {
                    heroConfigID = ReadHeroConfigID(task, root, matchedActor);
                    heroName = HeroNameForConfigID(heroConfigID);
                    if (heroName && cacheIdx != -1) {
                        strncpy(enemyCache[cacheIdx].cachedName, [heroName UTF8String], 63);
                        enemyCache[cacheIdx].cachedName[63] = '\0';
                    }
                }
                if (IsGenericHeroName(heroName)) heroName = @"Hero";
                UILabel *lbl = self.nameLabelPool[nameIdx++];
                lbl.text = heroName;
                [lbl sizeToFit];
                lbl.center = CGPointMake(sx, nameY);
                lbl.hidden = NO;
            }

            if (esp_icon_enabled && iconIdx < self.heroIconViewPool.count) {
                if (!heroConfigID) heroConfigID = ReadHeroConfigID(task, root, matchedActor);
                UIImage *iconImage = HeroIconForConfigID(heroConfigID);
                if (iconImage) {
                    UIImageView *iconView = self.heroIconViewPool[iconIdx++];
                    CGFloat iconSize = 28.0f;
                    CGFloat iconCenterY = topY + bh / 2.0f;
                    CGFloat iconCenterX = sx;

                    iconView.image = iconImage;
                    iconView.frame = CGRectMake(iconCenterX - iconSize / 2.0f,
                                                iconCenterY - iconSize / 2.0f,
                                                iconSize,
                                                iconSize);
                    iconView.hidden = NO;
                }
            }
 
            if (esp_health_enabled && hpIdx < self.healthLabelPool.count) {
                UILabel *lbl = self.healthLabelPool[hpIdx++];
                lbl.text = [NSString stringWithFormat:@"%d HP", hp];
                lbl.textColor = ESPHealthColor(healthPct);
                [lbl sizeToFit];
                lbl.center = CGPointMake(sx, bottomY + 10);
                lbl.hidden = NO;
            }
 
            if (esp_health_bar_enabled) {
                float barX = sx + bw/2 + 3;
                [healthBarOutPath moveToPoint:CGPointMake(barX, topY)];
                [healthBarOutPath addLineToPoint:CGPointMake(barX, bottomY)];
                UIBezierPath *coloredBarPath = healthPct > 0.60f ? healthBarPath :
                                               (healthPct > 0.30f ? healthBarMidPath : healthBarLowPath);
                [coloredBarPath moveToPoint:CGPointMake(barX, bottomY - bh*healthPct)];
                [coloredBarPath addLineToPoint:CGPointMake(barX, bottomY)];
            }
        }
 
        for (int c = 0; c < 40; c++) {
            if (enemyCache[c].playerId != 0) {
                bool exists = false;
                for (int r = 0; r < enemyRootCount; r++) {
                    mach_vm_address_t root = enemyRoots[r];
                    if (root > 0x1000000) {
                        uint32_t pId = Read<uint32_t>(root + Off::LActorRoot::PlayerId, task);
                        if (pId == enemyCache[c].playerId) {
                            exists = true;
                            break;
                        }
                    }
                }
                if (!exists) {
                    memset(&enemyCache[c], 0, sizeof(struct EnemyCache));
                }
            }
        }
 
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
 
        // Hide/show labels inside CATransaction to sync with shape layers redraw and prevent out-of-sync flickering
        for (NSUInteger idx = nameIdx; idx < self.nameLabelPool.count; idx++) {
            self.nameLabelPool[idx].hidden = YES;
        }
        for (NSUInteger idx = iconIdx; idx < self.heroIconViewPool.count; idx++) {
            self.heroIconViewPool[idx].hidden = YES;
        }
        for (NSUInteger idx = miniMapIconIdx; idx < self.miniMapIconViewPool.count; idx++) {
            self.miniMapIconViewPool[idx].hidden = YES;
        }
        for (NSUInteger idx = hpIdx; idx < self.healthLabelPool.count; idx++) {
            self.healthLabelPool[idx].hidden = YES;
        }
 


        self.espBoxLayer.path              = boxPath.CGPath;
        self.espBoxFillLayer.path          = boxFillPath.CGPath;
        self.espBoxOutlineLayer.path       = esp_box_outline ? boxOutlinePath.CGPath : nil;
        self.espLineLayer.path             = linesPath.CGPath;
        self.espLineMidLayer.path          = linesMidPath.CGPath;
        self.espLineLowLayer.path          = linesLowPath.CGPath;
        self.espLineOutlineLayer.path      = esp_line_outline ? lineOutlinePath.CGPath : nil;
        self.espHealthBarLayer.path        = healthBarPath.CGPath;
        self.espHealthBarMidLayer.path     = healthBarMidPath.CGPath;
        self.espHealthBarLowLayer.path     = healthBarLowPath.CGPath;
        self.espHealthBarOutlineLayer.path = healthBarOutPath.CGPath;
        self.miniMapOutlineLayer.path      = esp_minimap_enabled ? miniMapOutlinePath.CGPath : nil;

        if (viewMatrixValid || esp_minimap_enabled) {
            int shownPlayers = validPlayers > 0 ? validPlayers : trackedPlayers;
            [self publishStatus:[NSString stringWithFormat:@"PLAYERS:%d", shownPlayers]
                         players:shownPlayers
                            tone:@"ok"];
            [self showPlayerCount:shownPlayers width:w];
        } else {
            [self publishStatus:@"NO CAMERA" players:0 tone:@"warn"];
            self.playerCountLabel.hidden = YES;
        }

        [CATransaction commit];
        [CATransaction flush];
    }
    return;
}

@end
