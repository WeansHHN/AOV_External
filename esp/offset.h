#pragma once

#include <stdint.h>

// AoV external offset profile - chỉ cần sửa file này khi đổi phiên bản game.
//
// CÁCH UPDATE CHO GAME MỚI:
// 1. Dump đúng binary + global-metadata.dat của bản game mới để có dump.cs và
//    script.json (Il2CppDumper/Il2CppInspector).
// 2. Sửa nhóm Image trước: SignatureRva, SignatureValue và ba ClassGlobal.
// 3. Với field trực tiếp: chép số "// 0x..." trong dump.cs. Với hằng số có
//    công thức ở comment (struct/handle/array lồng nhau), tính công thức một lần
//    rồi nhập kết quả cuối vào đây; esp.mm sẽ không cộng thêm byte cố định.
// 4. Runtime và UnityTransform thường không đổi. Chỉ sửa khi game nâng Unity,
//    hoặc mọi List/String/Transform cùng hỏng dù field game đã đúng.
// 5. Test theo thứ tự: nhận base -> player count -> camera -> position -> HP/name.
//
// NHÓM CẦN KIỂM TRA KHI UPDATE:
//   - Mỗi binary mới: toàn bộ Image.
//   - Mỗi dump.cs mới: Framework, Camera, ActorLinker/ActorMeta, LActorRoot,
//     Value, Logic và Name.
//   - Chỉ khi đổi Unity/IL2CPP: Runtime và UnityTransform.
//   - FieldOfView là cấu hình chiếu hình, không phải field offset trong dump.cs.
//
// VÍ DỤ TÌM FIELD:
//   Tìm "public sealed class ActorLinker", sau đó tìm dòng
//   "public Transform myTransform; // 0x440".
//   Kết quả: ActorLinker::MyTransform = 0x440.
//
// QUY ƯỚC OFFSET TRONG FILE NÀY:
//   Mọi hằng số dùng để Read đều là offset CUỐI CÙNG tính từ object đang đọc.
//   Các byte của Array, PoolObjHandle, struct lồng nhau và index đã được cộng
//   sẵn. Không cộng lại lần nữa trong esp.mm.
//
// NGOẠI LỆ VALUE TYPE KHI TÍNH OFFSET CUỐI:
//   Il2CppDumper có thể in các field đầu của struct thành 0xFFFFFFF8/-8 và
//   0xFFFFFFFC/-4 vì trừ header 8 byte của object boxed. Khi struct nằm inline
//   trong class, quy đổi về offset thật từ đầu struct bằng cách cộng 8.
//   Ví dụ ActorMeta.PlayerId: -4 + 8 = 0x4; ActorCamp: 0xC + 8 = 0x14.
//
// CÁCH TÌM CLASS GLOBAL/RVA:
//   Ba *ClassGlobal không phải field offset. Chúng là địa chỉ tương đối của ô
//   global chứa MethodInfo*. Trong IDA/Ghidra đã apply script.json, tìm singleton
//   của KyriosFramework/CameraSystem/LogicCore, theo cặp ARM64 ADRP + LDR tới ô
//   MethodInfo, rồi lấy: globalVA - imageBase. Không lấy RVA của thân hàm.
//   Profile hiện tại dùng RVA của KyriosFramework.get_actorManager làm
//   SignatureRva (dump.cs có dòng RVA). Đọc 4 byte lệnh ARM64 đầu hàm đó trong
//   binary làm SignatureValue. Nếu ESP chỉ hiện "Waiting for game
//   initialization", kiểm tra hai giá trị signature này trước.

namespace AOVOffset {

namespace Image {
    static constexpr const char *ProcessName = "kgvn";
    static constexpr const char *Candidates[] = {"UnityFramework", "sgameGlobal", "kgvn"};

    // Changes on almost every binary update.
    static constexpr uintptr_t SignatureRva             = 0x6A49C40;
    static constexpr uint32_t  SignatureValue           = 0xA9BE4FF4;
    static constexpr uintptr_t KyriosFrameworkClassGlobal = 0xCBE1E50;
    static constexpr uintptr_t CameraSystemClassGlobal    = 0xCBE1D00;
    static constexpr uintptr_t LogicCoreClassGlobal       = 0xCBE83B8;
}

// IL2CPP object/container layout. Usually stable until the Unity version or
// IL2CPP object layout changes.
namespace Runtime {
    static constexpr uintptr_t MethodInfoKlass   = 0x20;
    static constexpr uintptr_t KlassStaticFields = 0xB8;
    static constexpr uintptr_t ListItems         = 0x8;
    static constexpr uintptr_t ListSize          = 0x10;
    static constexpr uintptr_t ArrayData         = 0x18;
    static constexpr uintptr_t StringLength      = 0x10;
    static constexpr uintptr_t StringChars       = 0x14;
    static constexpr uintptr_t PointerStride     = 0x8;
    static constexpr uintptr_t HandleStride      = 0x10;
    // 0x18 ArrayData + 0x8 PoolObjHandle.object.
    static constexpr uintptr_t HandleArrayObject = 0x20;
}

// MonoSingleton<KyriosFramework>, ActorManager, HostLogic
namespace Framework {
    static constexpr uintptr_t ActorManager       = 0x28; // private ActorManager _actorManager;
    static constexpr uintptr_t HostLogic          = 0x50; // private VHostLogic _hostLogic;
    static constexpr uintptr_t ActorManagerHeroes = 0x20; // public List<PoolObjHandle<ActorLinker>> HeroActors;
    static constexpr uintptr_t HostPlayerId       = 0x10; // VHostLogic.<HostPlayerId>k__BackingField
    static constexpr uintptr_t StaticScanEnd      = 0x18;
}

// CameraSystem, Moba_Camera and Moba_Camera_Requirements
namespace Camera {
    static constexpr uintptr_t StaticInstance        = 0x0;
    static constexpr uintptr_t MobaCamera            = 0x18;  // public Moba_Camera MobaCamera;
    static constexpr uintptr_t MainCamera            = 0x108; // private Camera m_mainCamera;
    static constexpr uintptr_t Mirror                = 0xB9;  // private bool m_bCameraMirror;

    static constexpr uintptr_t Requirements          = 0x68;  // Moba_Camera.requirements
    static constexpr uintptr_t RequirementsPivot     = 0x8;   // Moba_Camera_Requirements.pivot
    static constexpr uintptr_t RequirementsTransform = 0x10;  // Moba_Camera_Requirements.offset
    static constexpr uintptr_t RequirementsCamera    = 0x18;  // Moba_Camera_Requirements.camera
    static constexpr float     FieldOfView            = 30.0f;
}

// External minimap overlay calibration. These are screen/layout constants,
// not memory offsets. Adjust them if the game minimap position changes on a
// device profile.
namespace MiniMap {
    static constexpr float WorldScaleX     = 109.0f; // AOVNoHookate scalemapX
    static constexpr float WorldScaleY     = 109.0f; // AOVNoHookate scalemapY
    static constexpr float SizeHeightRatio = 0.31f;
    static constexpr float MinSize         = 96.0f;
    static constexpr float MaxSize         = 146.0f;
    static constexpr float LeftRatio       = 0.012f;
    static constexpr float TopRatio        = 0.065f;
    static constexpr float MinLeft         = 10.0f;
    static constexpr float MinTop          = 24.0f;
}

// Native Unity Transform hierarchy. Reverse these from the matching Unity
// player when camera/position fails after a Unity engine upgrade.
namespace UnityTransform {
    static constexpr uintptr_t CachedPtr        = 0x8;
    static constexpr uintptr_t Hierarchy        = 0x38;
    static constexpr uintptr_t HierarchyIndex   = 0x40;
    static constexpr uintptr_t MatrixList       = 0x18;
    static constexpr uintptr_t MatrixIndices    = 0x20;
}

// Kyrios.Actor.ActorLinker. Nested ActorMeta bytes are already included.
namespace ActorLinker {
    static constexpr uintptr_t ObjLinker      = 0x118; // ActorConfig ObjLinker
    static constexpr uintptr_t ConfigID       = 0x1C;  // ActorConfig.ConfigID
    static constexpr uintptr_t MetaConfigID   = 0x1F8; // public ActorMeta TheActorMeta;
    static constexpr uintptr_t ValueComponent = 0x28;  // ValueComponent
    static constexpr uintptr_t Location       = 0x16C; // public VInt3 _location;
    static constexpr uintptr_t Visible        = 0x1BD; // <bVisible>k__BackingField
    static constexpr uintptr_t PlayerId       = 0x204; // TheActorMeta 0x1F8 + PlayerId 0x4
    static constexpr uintptr_t Camp           = 0x214; // TheActorMeta 0x1F8 + ActorCamp 0x14
    static constexpr uintptr_t MyTransform    = 0x440; // public Transform myTransform;
}

// NucleusDrive.Logic.LActorRoot. Nested ActorMeta bytes are already included.
namespace LActorRoot {
    static constexpr uintptr_t ConfigID               = 0x60;  // public ActorMeta TheActorMeta;
    static constexpr uintptr_t PlayerId               = 0x6C;  // TheActorMeta 0x58 + PlayerId 0x4
    static constexpr uintptr_t Camp                   = 0x7C;  // TheActorMeta 0x58 + ActorCamp 0x14
    static constexpr uintptr_t Location               = 0xD8;  // private VInt3 _location;
    static constexpr uintptr_t CharInfo               = 0x2D8; // CharInfo
    static constexpr uintptr_t ValuePropertyComponent = 0x320; // public ValuePropertyComponent ValueComponent;
}

// ValuePropertyComponent, ValueLinkerComponent, PropertySetBase, ValueDataBase
namespace Value {
    // ValuePropertyComponent._nObjCurHp (CrypticInt32: _Decrypt rồi _Cryptic).
    static constexpr uintptr_t CurrentHpValue  = 0x58; // private CrypticInt32 _nObjCurHp;
    static constexpr uintptr_t CurrentHpKey    = 0x5C;
    static constexpr uintptr_t ActorValue      = 0x68; // public LPropertySet mActorValue;
    static constexpr uintptr_t LinkerHp        = 0x40; // private int <actorHp>k__BackingField;
    static constexpr uintptr_t LinkerHpTotal   = 0x44; // private int <actorHpTotal>k__BackingField;
    static constexpr uintptr_t PropertyArray   = 0x8;  // PropertySetBase.mActorValue
    // ArrayData 0x18 + RES_FUNCEFT_MAXHP index 5 * pointer 0x8.
    static constexpr uintptr_t MaxHpArrayEntry = 0x40;

    // ValueDataBase: từng giá trị mã hóa nằm liền trước key tương ứng.
    static constexpr uintptr_t BaseValue        = 0xC;
    static constexpr uintptr_t BaseValueKey     = 0x10;
    static constexpr uintptr_t GrowValue        = 0x14;
    static constexpr uintptr_t GrowValueKey     = 0x18;
    static constexpr uintptr_t AddValue         = 0x1C;
    static constexpr uintptr_t AddValueKey      = 0x20;
    static constexpr uintptr_t DecValue         = 0x24;
    static constexpr uintptr_t DecValueKey      = 0x28;
    static constexpr uintptr_t AddRatio         = 0x2C;
    static constexpr uintptr_t AddRatioKey      = 0x30;
    static constexpr uintptr_t DecRatio         = 0x34;
    static constexpr uintptr_t DecRatioKey      = 0x38;
    static constexpr uintptr_t AddOffRatio      = 0x3C;
    static constexpr uintptr_t AddOffRatioKey   = 0x40;
}

// LogicCore -> CurDesk -> LBattleLogic -> GamePlayerCenter -> LogicPlayer
namespace Logic {
    static constexpr uintptr_t StaticInstance  = 0x0;
    static constexpr uintptr_t CurDesk         = 0x40;  // LLogicCore.<curUpdatingDesk>k__BackingField
    static constexpr uintptr_t DeskBattleLogic = 0x38;  // LDeskBase.<DeskBattleLogic>k__BackingField
    static constexpr uintptr_t PlayerCenter    = 0x108; // private GamePlayerCenter <lGamePlayerCenter>k__BackingField;
    static constexpr uintptr_t PlayersListView = 0x20;  // private ListView<PlayerBase> _players;
    // LPlayer.Captain 0x198 + PoolObjHandle.object 0x8.
    static constexpr uintptr_t PlayerCaptain   = 0x1A0;
    static constexpr uintptr_t PlayerHeroes    = 0x1A8; // LPlayer._heroes
}

// NucleusDrive.Logic.LActorInfo / managed System.String
namespace Name {
    static constexpr uintptr_t ActorName = 0x10; // LActorInfo.fields.ActorName
}

} // namespace AOVOffset
