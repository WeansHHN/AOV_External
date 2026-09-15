#import "unity.h"
#include "../offset.h"
#include <cmath>

namespace Off = AOVOffset;

struct c_matrix_new {
    float m[4][4];
};

template <typename T>
static bool camera_read_checked(mach_vm_address_t address, task_t task, T &value)
{
    value = T();
    if (!task || address <= 0x1000000 || address > 0x7FFFFFFFFFFF)
        return false;

    mach_vm_size_t outSize = 0;
    kern_return_t kr = mach_vm_read_overwrite(task, address, sizeof(T),
                                               (mach_vm_address_t)&value, &outSize);
    return kr == KERN_SUCCESS && outSize == sizeof(T);
}


Vector3 get_position_by_transform(mach_vm_address_t mach_transform_ptr, task_t task)
{
    mach_vm_address_t transObj = Read<mach_vm_address_t>(mach_transform_ptr + Off::UnityTransform::CachedPtr, task);
    if (!transObj) return Vector3{0,0,0};

    mach_vm_address_t matrix = Read<mach_vm_address_t>(transObj + Off::UnityTransform::Hierarchy, task);
    if (!matrix) return Vector3{0,0,0};

    int index = Read<int>(transObj + Off::UnityTransform::HierarchyIndex, task);

    mach_vm_address_t matrix_list = Read<mach_vm_address_t>(matrix + Off::UnityTransform::MatrixList, task);
    mach_vm_address_t matrix_indices = Read<mach_vm_address_t>(matrix + Off::UnityTransform::MatrixIndices, task);
    if (!matrix_list || !matrix_indices) return Vector3{0,0,0};

    Vector3 result = Read<Vector3>(matrix_list + (size_t)sizeof(TMatrix) * (size_t)index, task);
    int transformIndex = Read<int>(matrix_indices + (size_t)sizeof(int) * (size_t)index, task);

    if (transformIndex < 0) return result;

    int max_safety = 50;
    while (transformIndex >= 0 && max_safety-- > 0)
    {
        TMatrix tMatrix = Read<TMatrix>(matrix_list + (size_t)sizeof(TMatrix) * (size_t)transformIndex, task);

        float rotX = tMatrix.rotation.x;
        float rotY = tMatrix.rotation.y;
        float rotZ = tMatrix.rotation.z;
        float rotW = tMatrix.rotation.w;

        float scaleX = result.x * tMatrix.scale.x;
        float scaleY = result.y * tMatrix.scale.y;
        float scaleZ = result.z * tMatrix.scale.z;

        result.x = tMatrix.position.x + scaleX +
            (scaleX * ((rotY * rotY * -2.0f) - (rotZ * rotZ * 2.0f))) +
            (scaleY * ((rotW * rotZ * -2.0f) - (rotY * rotX * -2.0f))) +
            (scaleZ * ((rotZ * rotX * 2.0f) - (rotW * rotY * -2.0f)));
        result.y = tMatrix.position.y + scaleY +
            (scaleX * ((rotX * rotY * 2.0f) - (rotW * rotZ * -2.0f))) +
            (scaleY * ((rotZ * rotZ * -2.0f) - (rotX * rotX * 2.0f))) +
            (scaleZ * ((rotW * rotX * -2.0f) - (rotZ * rotY * -2.0f)));
        result.z = tMatrix.position.z + scaleZ +
            (scaleX * ((rotW * rotY * -2.0f) - (rotX * rotZ * -2.0f))) +
            (scaleY * ((rotY * rotZ * 2.0f) - (rotW * rotX * -2.0f))) +
            (scaleZ * ((rotX * rotX * -2.0f) - (rotY * rotY * 2.0f)));

        transformIndex = Read<int>(matrix_indices + (size_t)sizeof(int) * (size_t)transformIndex, task);
    }

    return result;
}

// ── Read camera full transform: world position + rotation axes ───────────────
// Uses the same TMatrix chain but also extracts the final quaternion to derive
// forward/right/up vectors (needed for building a correct view matrix).
CameraTransformData get_camera_transform(mach_vm_address_t mach_transform_ptr, task_t task)
{
    CameraTransformData out = {};

    if (mach_transform_ptr <= 0x1000000) return out;

    mach_vm_address_t transObj = 0;
    if (!camera_read_checked(mach_transform_ptr + Off::UnityTransform::CachedPtr, task, transObj) ||
        transObj <= 0x1000000) return out;

    mach_vm_address_t matrix = 0;
    if (!camera_read_checked(transObj + Off::UnityTransform::Hierarchy, task, matrix) ||
        matrix <= 0x1000000) return out;

    int index = -1;
    if (!camera_read_checked(transObj + Off::UnityTransform::HierarchyIndex, task, index) ||
        index < 0 || index > 200000) return out;

    mach_vm_address_t matrix_list = 0;
    mach_vm_address_t matrix_indices = 0;
    if (!camera_read_checked(matrix + Off::UnityTransform::MatrixList, task, matrix_list) ||
        !camera_read_checked(matrix + Off::UnityTransform::MatrixIndices, task, matrix_indices) ||
        matrix_list <= 0x1000000 || matrix_indices <= 0x1000000) return out;

    // Read the leaf TMatrix (contains local position + world quaternion at leaf level)
    TMatrix leafMat = {};
    int transformIndex = -2;
    if (!camera_read_checked(matrix_list + (size_t)sizeof(TMatrix) * (size_t)index,
                             task, leafMat) ||
        !camera_read_checked(matrix_indices + (size_t)sizeof(int) * (size_t)index,
                             task, transformIndex)) return out;

    Vector3 pos = { leafMat.position.x, leafMat.position.y, leafMat.position.z };

    // Accumulate parent transforms for position (same as get_position_by_transform)
    int max_safety = 50;
    // Track world quaternion, beginning at the leaf rotation.
    float wqx = leafMat.rotation.x, wqy = leafMat.rotation.y;
    float wqz = leafMat.rotation.z, wqw = leafMat.rotation.w;

    while (transformIndex >= 0 && max_safety-- > 0)
    {
        if (transformIndex > 200000) return out;

        TMatrix tMatrix = {};
        if (!camera_read_checked(matrix_list + (size_t)sizeof(TMatrix) * (size_t)transformIndex,
                                 task, tMatrix)) return out;

        float rotX = tMatrix.rotation.x;
        float rotY = tMatrix.rotation.y;
        float rotZ = tMatrix.rotation.z;
        float rotW = tMatrix.rotation.w;

        float scaleX = pos.x * tMatrix.scale.x;
        float scaleY = pos.y * tMatrix.scale.y;
        float scaleZ = pos.z * tMatrix.scale.z;

        pos.x = tMatrix.position.x + scaleX +
            (scaleX * ((rotY * rotY * -2.0f) - (rotZ * rotZ * 2.0f))) +
            (scaleY * ((rotW * rotZ * -2.0f) - (rotY * rotX * -2.0f))) +
            (scaleZ * ((rotZ * rotX * 2.0f) - (rotW * rotY * -2.0f)));
        pos.y = tMatrix.position.y + scaleY +
            (scaleX * ((rotX * rotY * 2.0f) - (rotW * rotZ * -2.0f))) +
            (scaleY * ((rotZ * rotZ * -2.0f) - (rotX * rotX * 2.0f))) +
            (scaleZ * ((rotW * rotX * -2.0f) - (rotZ * rotY * -2.0f)));
        pos.z = tMatrix.position.z + scaleZ +
            (scaleX * ((rotW * rotY * -2.0f) - (rotX * rotZ * -2.0f))) +
            (scaleY * ((rotY * rotZ * 2.0f) - (rotW * rotX * -2.0f))) +
            (scaleZ * ((rotX * rotX * -2.0f) - (rotY * rotY * 2.0f)));

        // Combine parent quaternion (parent * child = world quaternion)
        // q_world = q_parent * q_current
        float nx = rotW*wqx + rotX*wqw + rotY*wqz - rotZ*wqy;
        float ny = rotW*wqy - rotX*wqz + rotY*wqw + rotZ*wqx;
        float nz = rotW*wqz + rotX*wqy - rotY*wqx + rotZ*wqw;
        float nw = rotW*wqw - rotX*wqx - rotY*wqy - rotZ*wqz;
        wqx = nx; wqy = ny; wqz = nz; wqw = nw;

        int nextIndex = -2;
        if (!camera_read_checked(matrix_indices + (size_t)sizeof(int) * (size_t)transformIndex,
                                 task, nextIndex)) return out;
        transformIndex = nextIndex;
    }

    if (transformIndex >= 0) return out;

    float qNorm = sqrtf(wqx*wqx + wqy*wqy + wqz*wqz + wqw*wqw);
    if (!std::isfinite(qNorm) || qNorm < 0.1f || qNorm > 10.0f ||
        !std::isfinite(pos.x) || !std::isfinite(pos.y) || !std::isfinite(pos.z))
        return out;

    // Normalize before deriving axes.  Parent multiplication can introduce a
    // small amount of drift, which otherwise becomes visible as ESP offset.
    wqx /= qNorm;
    wqy /= qNorm;
    wqz /= qNorm;
    wqw /= qNorm;

    out.position = pos;

    // Derive world axes from world quaternion
    // forward = (0,0,1) rotated by quaternion (Unity uses left-handed z-forward)
    out.forward.x = 2.0f*(wqx*wqz + wqw*wqy);
    out.forward.y = 2.0f*(wqy*wqz - wqw*wqx);
    out.forward.z = 1.0f - 2.0f*(wqx*wqx + wqy*wqy);

    // right = (1,0,0) rotated
    out.right.x = 1.0f - 2.0f*(wqy*wqy + wqz*wqz);
    out.right.y = 2.0f*(wqx*wqy + wqw*wqz);
    out.right.z = 2.0f*(wqx*wqz - wqw*wqy);

    // up = (0,1,0) rotated
    out.up.x = 2.0f*(wqx*wqy - wqw*wqz);
    out.up.y = 1.0f - 2.0f*(wqx*wqx + wqz*wqz);
    out.up.z = 2.0f*(wqy*wqz + wqw*wqx);

    out.valid = std::isfinite(out.forward.x) && std::isfinite(out.forward.y) &&
                std::isfinite(out.forward.z) && std::isfinite(out.right.x) &&
                 std::isfinite(out.right.y) && std::isfinite(out.right.z) &&
                 std::isfinite(out.up.x) && std::isfinite(out.up.y) &&
                 std::isfinite(out.up.z);
    return out;
}

// ── Build a full ViewProjection matrix from camera transform + FOV ───────────
// This replicates what WorldToViewportPoint does internally in Unity.
// fovDeg  = camera field of view in degrees (vertical)
// aspect  = screenWidth / screenHeight
SO2_Matrix BuildVPMatrix(const CameraTransformData &cam, float fovDeg, float aspect,
                         float nearClip = 0.3f, float farClip = 1000.0f)
{
    // --- Build View matrix (world-to-camera) ---
    // Unity uses left-handed coordinate system.
    // View matrix = inverse of camera TRS = transpose of rotation part + translated origin
    // Row vectors: right, up, forward (in camera space)
    Vector3 r = cam.right;
    Vector3 u = cam.up;
    Vector3 f = cam.forward;  // camera looks down +Z in Unity
    Vector3 p = cam.position;

    // Dot products for translation row
    float tx = -(r.x*p.x + r.y*p.y + r.z*p.z);
    float ty = -(u.x*p.x + u.y*p.y + u.z*p.z);
    float tz = -(f.x*p.x + f.y*p.y + f.z*p.z);

    SO2_Matrix V = {};
    V.m11 = r.x;  V.m12 = u.x;  V.m13 = f.x;  V.m14 = 0;
    V.m21 = r.y;  V.m22 = u.y;  V.m23 = f.y;  V.m24 = 0;
    V.m31 = r.z;  V.m32 = u.z;  V.m33 = f.z;  V.m34 = 0;
    V.m41 = tx;   V.m42 = ty;   V.m43 = tz;   V.m44 = 1;

    // --- Build Projection matrix (left-handed, +Z forward) ---
    // WorldToScreen() below multiplies a row vector by the matrix, so clip.w
    // must be camera-space +Z.  The previous OpenGL/-Z projection made every
    // visible point produce a negative W and therefore get rejected.
    float fovRad = fovDeg * (3.14159265f / 180.0f);
    float f_val  = 1.0f / tanf(fovRad * 0.5f);
    float range  = farClip - nearClip;

    SO2_Matrix P = {};
    P.m11 = f_val / aspect;
    P.m22 = f_val;
    P.m33 = farClip / range;
    P.m34 = 1.0f;
    P.m43 = -(nearClip * farClip) / range;
    P.m44 = 0.0f;

    // --- Multiply VP = V * P ---
    // WorldToScreen() evaluates [x y z 1] * VP, hence view must be applied
    // before projection.  The old P * V order dropped/misplaced translation.
    SO2_Matrix VP = {};
    // Row 1
    VP.m11 = V.m11*P.m11 + V.m12*P.m21 + V.m13*P.m31 + V.m14*P.m41;
    VP.m12 = V.m11*P.m12 + V.m12*P.m22 + V.m13*P.m32 + V.m14*P.m42;
    VP.m13 = V.m11*P.m13 + V.m12*P.m23 + V.m13*P.m33 + V.m14*P.m43;
    VP.m14 = V.m11*P.m14 + V.m12*P.m24 + V.m13*P.m34 + V.m14*P.m44;
    // Row 2
    VP.m21 = V.m21*P.m11 + V.m22*P.m21 + V.m23*P.m31 + V.m24*P.m41;
    VP.m22 = V.m21*P.m12 + V.m22*P.m22 + V.m23*P.m32 + V.m24*P.m42;
    VP.m23 = V.m21*P.m13 + V.m22*P.m23 + V.m23*P.m33 + V.m24*P.m43;
    VP.m24 = V.m21*P.m14 + V.m22*P.m24 + V.m23*P.m34 + V.m24*P.m44;
    // Row 3
    VP.m31 = V.m31*P.m11 + V.m32*P.m21 + V.m33*P.m31 + V.m34*P.m41;
    VP.m32 = V.m31*P.m12 + V.m32*P.m22 + V.m33*P.m32 + V.m34*P.m42;
    VP.m33 = V.m31*P.m13 + V.m32*P.m23 + V.m33*P.m33 + V.m34*P.m43;
    VP.m34 = V.m31*P.m14 + V.m32*P.m24 + V.m33*P.m34 + V.m34*P.m44;
    // Row 4
    VP.m41 = V.m41*P.m11 + V.m42*P.m21 + V.m43*P.m31 + V.m44*P.m41;
    VP.m42 = V.m41*P.m12 + V.m42*P.m22 + V.m43*P.m32 + V.m44*P.m42;
    VP.m43 = V.m41*P.m13 + V.m42*P.m23 + V.m43*P.m33 + V.m44*P.m43;
    VP.m44 = V.m41*P.m14 + V.m42*P.m24 + V.m43*P.m34 + V.m44*P.m44;

    return VP;
}

Vector3 WorldToScreen(Vector3 object, SO2_Matrix mat, CGFloat ScreenWidth, CGFloat ScreenHeight)
{
    float screenX = (mat.m11 * object.x) + (mat.m21 * object.y) + (mat.m31 * object.z) + mat.m41;
    float screenY = (mat.m12 * object.x) + (mat.m22 * object.y) + (mat.m32 * object.z) + mat.m42;
    float screenW = (mat.m14 * object.x) + (mat.m24 * object.y) + (mat.m34 * object.z) + mat.m44;

    Vector3 result = {0.0f, 0.0f, -1.0f};
    if(screenW < 0.0001f) {
        return result;
    }

    float camX = ScreenWidth / 2.0f;
    float camY = ScreenHeight / 2.0f;
    result.x = camX + (camX * screenX / screenW);
    result.y = camY - (camY * screenY / screenW);
    result.z = screenW;
    return result;
}
