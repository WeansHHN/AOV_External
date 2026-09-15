#import "../helpers/pid.h"
#import "../helpers/Vector3.h"

#import <cstddef>
#import <cstring>
#import <cstdlib>
#import <dlfcn.h>
#import <spawn.h>
#import <unistd.h>
#import <sys/sysctl.h>
#import <mach/mach.h>

#pragma once

#include <vector>
#include <functional>
#include <utility>
#include <cstdint>

struct Vector4
{
    float x, y, z, w;
};

struct TMatrix
{
    Vector4 position;
    Vector4 rotation;
    Vector4 scale;
};

struct c_matrix
{
    float m[4][4];
    float *operator[](int index) { return m[index]; }
};


Vector3 get_position_by_transform(mach_vm_address_t mach_transform_ptr, task_t task);
inline float Dot(const Vector3 &Vec1, const Vector3 &Vec2);
struct SO2_Matrix {
    float m11, m12, m13, m14;
    float m21, m22, m23, m24;
    float m31, m32, m33, m34;
    float m41, m42, m43, m44;
};

struct CameraTransformData {
    Vector3 position;
    Vector3 forward;
    Vector3 right;
    Vector3 up;
    bool    valid;
};

Vector3 WorldToScreen(Vector3 object, SO2_Matrix mat, CGFloat ScreenWidth, CGFloat ScreenHeight);
CameraTransformData get_camera_transform(mach_vm_address_t mach_transform_ptr, task_t task);
SO2_Matrix BuildVPMatrix(const CameraTransformData &cam, float fovDeg, float aspect,
                         float nearClip, float farClip);


template <typename T>
struct monoArray
{
    task_t   task;
    uintptr_t address;

    monoArray()
        : task(MACH_PORT_NULL)
        , address(0)
    {
    }

    monoArray(task_t t, uintptr_t addr)
        : task(t)
        , address(addr)
    {
    }

    int get_Length() const
    {
        if (!address || !task)
            return 0;

        struct Header
        {
            void* klass;
            void* monitor;
            void* bounds;
            int   max_length;
        };

        Header h = Read<Header>(address, task);
        return h.max_length;
    }

    T operator [] (int i) const
    {
        if (!address || !task)
            return T();

        struct Layout
        {
            void* klass;
            void* monitor;
            void* bounds;
            int   max_length;
            T     first;
        };

        uintptr_t elem_addr =
            address +
            static_cast<uintptr_t>(offsetof(Layout, first)) +
            static_cast<uintptr_t>(sizeof(T)) * static_cast<uintptr_t>(i);

        return Read<T>(elem_addr, task);
    }

    T operator [] (int i)
    {
        return static_cast<const monoArray&>(*this)[i];
    }

    bool Contains(T item) const
    {
        int len = get_Length();
        for (int i = 0; i < len; ++i)
        {
            T v = (*this)[i];
            if (v == item)
                return true;
        }
        return false;
    }
};

template<typename T>
using Array = monoArray<T>;


template<typename TKey, typename TValue>
struct Dictionary
{
    struct KeysCollection;
    struct ValueCollection;

    struct Entry
    {
        int   hashCode;
        int   next;
        TKey  key;
        TValue value;
    };

    struct RemoteLayout
    {
        void*          kass;
        void*          monitor;
        Array<int>*    buckets;
        Array<Entry>*  entries;
        int            count;
        int            version;
        int            freeList;
        int            freeCount;
        void*          comparer;
        void*          keys;
        void*          values;
        void*          _syncRoot;
    };

    task_t    task;
    uintptr_t address;

    Dictionary()
        : task(MACH_PORT_NULL)
        , address(0)
    {
    }

    Dictionary(task_t t, uintptr_t addr)
        : task(t)
        , address(addr)
    {
    }

    RemoteLayout get_Remote() const
    {
        if (!address || !task)
            return RemoteLayout{};
        return Read<RemoteLayout>(address, task);
    }

    void* get_Comparer() const
    {
        auto r = get_Remote();
        return r.comparer;
    }

    int get_Count() const
    {
        auto r = get_Remote();
        return r.count;
    }

    int FindEntry(TKey key) const
    {
        auto r = get_Remote();
        if (!r.entries || r.count <= 0)
            return -1;

        uintptr_t entries_addr = reinterpret_cast<uintptr_t>(r.entries);
        monoArray<Entry> entries_arr(task, entries_addr);

        for (int i = 0; i < r.count; ++i)
        {
            Entry e = entries_arr[i];
            if (e.key == key)
                return i;
        }
        return -1;
    }

    bool ContainsKey(TKey key) const
    {
        return FindEntry(key) >= 0;
    }

    bool ContainsValue(TValue value) const
    {
        auto r = get_Remote();
        if (!r.entries || r.count <= 0)
            return false;

        uintptr_t entries_addr = reinterpret_cast<uintptr_t>(r.entries);
        monoArray<Entry> entries_arr(task, entries_addr);

        for (int i = 0; i < r.count; ++i)
        {
            Entry e = entries_arr[i];
            if (e.hashCode >= 0 && e.value == value)
                return true;
        }
        return false;
    }

    bool TryGetValue(TKey key, TValue* value) const
    {
        int i = FindEntry(key);
        if (i >= 0)
        {
            auto r = get_Remote();
            if (!r.entries)
            {
                *value = TValue();
                return false;
            }

            uintptr_t entries_addr = reinterpret_cast<uintptr_t>(r.entries);
            monoArray<Entry> entries_arr(task, entries_addr);
            Entry e = entries_arr[i];
            *value = e.value;
            return true;
        }
        *value = TValue();
        return false;
    }

    TValue GetValueOrDefault(TKey key) const
    {
        TValue v = TValue();
        TryGetValue(key, &v);
        return v;
    }

    TValue operator [] (TKey key)
    {
        TValue v = TValue();
        TryGetValue(key, &v);
        return v;
    }

    const TValue operator [] (TKey key) const
    {
        TValue v = TValue();
        const_cast<Dictionary*>(this)->TryGetValue(key, &v);
        return v;
    }

    struct KeysCollection
    {
        Dictionary* dictionary;

        KeysCollection(Dictionary* dictionary)
            : dictionary(dictionary)
        {
        }

        TKey operator [] (int i)
        {
            auto r = dictionary->get_Remote();
            if (!r.entries)
                return TKey();

            uintptr_t entries_addr = reinterpret_cast<uintptr_t>(r.entries);
            monoArray<Entry> entries_arr(dictionary->task, entries_addr);
            Entry e = entries_arr[i];
            return e.key;
        }

        const TKey operator [] (int i) const
        {
            return const_cast<KeysCollection*>(this)->operator[](i);
        }

        int get_Count() const
        {
            return dictionary->get_Count();
        }
    };

    struct ValueCollection
    {
        Dictionary* dictionary;

        ValueCollection(Dictionary* dictionary)
            : dictionary(dictionary)
        {
        }

        TValue operator [] (int i)
        {
            auto r = dictionary->get_Remote();
            if (!r.entries)
                return TValue();

            uintptr_t entries_addr = reinterpret_cast<uintptr_t>(r.entries);
            monoArray<Entry> entries_arr(dictionary->task, entries_addr);
            Entry e = entries_arr[i];
            return e.value;
        }

        const TValue operator [] (int i) const
        {
            return const_cast<ValueCollection*>(this)->operator[](i);
        }

        int get_Count() const
        {
            return dictionary->get_Count();
        }
    };

    KeysCollection get_Keys()
    {
        return KeysCollection(this);
    }

    ValueCollection get_Values()
    {
        return ValueCollection(this);
    }
};
