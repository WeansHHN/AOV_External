#pragma once

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/sysctl.h>

#if defined(_MSC_VER)
#define ALWAYS_INLINE __forceinline
#else 
#define ALWAYS_INLINE __attribute__((always_inline))
#endif
 
// Usage examples:
void setup()    __attribute__((noinline));
void startAuthentication()  __attribute__((noinline));

#ifndef seed
    constexpr int seedToInt(char c) { return c - '0'; }
    const int seed = seedToInt(__TIME__[7]) +
                     seedToInt(__TIME__[6]) * 10 +
                     seedToInt(__TIME__[4]) * 60 +
                     seedToInt(__TIME__[3]) * 600 +
                     seedToInt(__TIME__[1]) * 3600 +
                     seedToInt(__TIME__[0]) * 36000;
#endif

// Thêm nhiều nguồn entropy để tạo khóa đa dạng hơn
#ifndef extra_seed
    constexpr int dateToInt(char c) { return c - '0'; }
    const int extra_seed = dateToInt(__DATE__[4]) * 1000 +
                         dateToInt(__DATE__[5]) * 100 +
                         dateToInt(__DATE__[0]) * 10 +
                         dateToInt(__DATE__[1]);
#endif

// The constantify template is used to make sure that the result of constexpr
// function will be computed at compile-time instead of run-time
template <uintptr_t Const> struct 
vxCplConstantify { enum { Value = Const }; };

// Compile-time mod of a linear congruential pseudorandom number generator,
// the actual algorithm was taken from "Numerical Recipes" book
constexpr uintptr_t vxCplRandom(uintptr_t Id)
{ return (1013904223 + 1664525 * ((Id > 0) ? (vxCplRandom(Id - 1)) : (seed))) & 0xFFFFFFFF; }

// Thêm trình tạo số ngẫu nhiên thứ hai với tham số khác
constexpr uintptr_t vxCplRandom2(uintptr_t Id)
{ return (2531011 + 214013 * ((Id > 0) ? (vxCplRandom2(Id - 1)) : (extra_seed))) & 0xFFFFFFFF; }

// Compile-time random macros, can be used to randomize execution  
// path for separate builds, or compile-time trash code generation
#define vxRANDOM(Min, Max) (Min + (vxRAND() % (Max - Min + 1)))
#define vxRAND()           (vxCplConstantify<vxCplRandom(__COUNTER__ + 1)>::Value)
#define vxRAND2()          (vxCplConstantify<vxCplRandom2(__COUNTER__ + 1)>::Value)

// Compile-time recursive mod of string hashing algorithm,
// the actual algorithm was taken from Qt library (this
// function isn't case sensitive due to vxCplTolower)
constexpr char   vxCplTolower(char Ch)                { return (Ch >= 'A' && Ch <= 'Z') ? (Ch - 'A' + 'a') : (Ch); }
constexpr uintptr_t vxCplHashPart3(char Ch, uintptr_t Hash) { return ((Hash << 4) + vxCplTolower(Ch)); }
constexpr uintptr_t vxCplHashPart2(char Ch, uintptr_t Hash) { return (vxCplHashPart3(Ch, Hash) ^ ((vxCplHashPart3(Ch, Hash) & 0xF0000000) >> 23)); }
constexpr uintptr_t vxCplHashPart1(char Ch, uintptr_t Hash) { return (vxCplHashPart2(Ch, Hash) & 0x0FFFFFFF); }
constexpr uintptr_t vxCplHash(const char* Str)           { return (*Str) ? (vxCplHashPart1(*Str, vxCplHash(Str + 1))) : (0); }

// Tăng cường thuật toán băm với hàm phức tạp hơn
constexpr uintptr_t vxEnhancedHash(const char* Str, uintptr_t Idx = 0)
{ 
    return (*Str) ? 
        ((vxCplHashPart1(*Str, vxEnhancedHash(Str + 1, Idx + 1)) ^ 
         ((Idx & 1) ? vxRANDOM(0, 0xFF) : vxRANDOM(0, 0xFF00)))) : 
        (0x5A2D1B73 ^ vxRAND()); 
}

// Compile-time hashing macro, hash values changes using the first pseudorandom number in sequence
#define HASH(Str) (uintptr_t)(vxCplConstantify<vxCplHash(Str)>::Value ^ vxCplConstantify<vxCplRandom(1)>::Value)
#define ENHANCED_HASH(Str) (uintptr_t)(vxCplConstantify<vxEnhancedHash(Str)>::Value ^ vxCplConstantify<vxCplRandom2(1)>::Value)

// Compile-time generator for list of indexes (0, 1, 2, ...)
template <uintptr_t...> struct vxCplIndexList {};
template <typename  IndexList, uintptr_t Right> struct vxCplAppend;
template <uintptr_t... Left, uintptr_t Right> struct vxCplAppend<vxCplIndexList<Left...>, Right> { typedef vxCplIndexList<Left..., Right> Result; };
template <uintptr_t N> struct vxCplIndexes { typedef typename vxCplAppend<typename vxCplIndexes<N - 1>::Result, N - 1>::Result Result; };
template <> struct vxCplIndexes<0> { typedef vxCplIndexList<> Result; };

// Các khóa mã hóa cơ bản và nâng cao
const char vxCplEncryptCharKey = (const char)vxRANDOM(0, 0xFF);
const char vxCplEncryptCharKey1 = (const char)vxRANDOM(0, 0xFF);
const char vxCplEncryptCharKey2 = (const char)vxRANDOM(0, 0xFF);
const char vxCplEncryptCharKey3 = (const char)vxRANDOM(0, 0xFF);

// Mã hóa cơ bản 1 lớp (giữ cho tương thích ngược)
constexpr char ALWAYS_INLINE vxCplEncryptChar(const char Ch, uintptr_t Idx) { return Ch ^ (vxCplEncryptCharKey + Idx); }

// Mã hóa nâng cao 4 lớp
constexpr char ALWAYS_INLINE vxCplEncryptCharAdvanced(const char Ch, uintptr_t Idx) {
    // Layer 1: XOR với khóa chính + index
    char result = Ch ^ (vxCplEncryptCharKey + Idx);
    
    // Layer 2: Rotation + XOR với khóa thứ hai
    result = ((result << 3) | (result >> 5)) ^ vxCplEncryptCharKey1;
    
    // Layer 3: Substitution based on index
    result = result ^ ((vxCplEncryptCharKey2 + Idx) % 256);
    
    // Layer 4: Final transformation
    return (result ^ vxCplEncryptCharKey3);
}

// Biến đổi ký tự phức tạp hơn nữa
constexpr char ALWAYS_INLINE vxCplAdvancedTransform(const char Ch, uintptr_t Idx) {
    // Sử dụng các phép biến đổi phức tạp hơn với nhiều lớp
    char temp = Ch;
    
    // Lớp 1: Shift right và XOR với entropy
    temp = ((temp >> 1) | (temp << 7)) ^ (vxCplEncryptCharKey2 + Idx);
    
    // Lớp 2: Add with index modifier
    temp = temp + (char)((Idx * 7) % 256);
    
    // Lớp 3: Table substitution (đơn giản hóa)
    temp = (temp * 13 + 7) % 256;
    
    // Lớp 4: Thêm XOR với key khác
    temp ^= vxCplEncryptCharKey ^ vxCplEncryptCharKey3;
    
    return temp;
}

// Compile-time string encryption class (cơ bản - giữ tương thích ngược)
template <typename IndexList> struct vxCplEncryptedString;
template <uintptr_t... Idx> struct vxCplEncryptedString<vxCplIndexList<Idx...>>
{
    char Value[sizeof...(Idx) + 1]; // Buffer for a string

    // Compile-time constructor
    constexpr ALWAYS_INLINE vxCplEncryptedString(const char* const Str)  
    : Value{ vxCplEncryptChar(Str[Idx], Idx)... } {}

    // Run-time decryption
    inline const char* decrypt()
    {
        for(uintptr_t t = 0; t < sizeof...(Idx); t++)
        { this->Value[t] = this->Value[t] ^ (vxCplEncryptCharKey + t); }
        this->Value[sizeof...(Idx)] = '\0'; return this->Value;
    }
};

// Lớp mã hóa chuỗi nâng cao với nhiều tính năng bảo mật
template <typename IndexList> struct vxCplAdvancedEncryptedString;
template <uintptr_t... Idx> struct vxCplAdvancedEncryptedString<vxCplIndexList<Idx...>>
{
    char Value[sizeof...(Idx) + 1]; // Buffer cho chuỗi
    uint8_t Checksum; // Checksum để kiểm tra tính toàn vẹn
    bool Decrypted; // Flag để theo dõi trạng thái giải mã
    uint8_t VerificationMarker; // Marker thêm để kiểm tra
    
    // Constructor thời gian biên dịch
    constexpr ALWAYS_INLINE vxCplAdvancedEncryptedString(const char* const Str)
    : Value{ vxCplEncryptCharAdvanced(Str[Idx], Idx)... }, Checksum(0), Decrypted(false), VerificationMarker(0xAA) {}

    // Tính checksum cho chuỗi
    inline uint8_t calculateChecksum(const char* str, size_t len) {
        uint8_t sum = 0x55; // Giá trị khởi tạo không phải 0
        for (size_t i = 0; i < len; i++) {
            sum = ((sum << 3) | (sum >> 5)) + str[i]; // Sử dụng phép quay thay vì cộng đơn giản
        }
        return sum ^ vxCplEncryptCharKey2;
    }

    // Hàm kiểm tra xem có đang bị debug không
    inline bool isBeingDebugged() {
        #ifdef __APPLE__
        // Các kỹ thuật phát hiện debug trên iOS/macOS
        int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
        struct kinfo_proc info;
        size_t size = sizeof(info);
        int result = sysctl(mib, 4, &info, &size, NULL, 0);
        if (result == -1) return true; // Xem như có vấn đề
        return ((info.kp_proc.p_flag & P_TRACED) != 0);
        #else
        return false; // Thực hiện phát hiện debug cho nền tảng khác nếu cần
        #endif
    }

    // Giải mã thời gian chạy với anti-debugging
    inline const char* decrypt()
    {
        // Kiểm tra marker đã bị thay đổi chưa
        if (this->VerificationMarker != 0xAA) {
            memset(this->Value, 0, sizeof...(Idx));
            return this->Value;
        }
        
        // Nếu đã giải mã rồi, trả về chuỗi
        if (Decrypted) return this->Value;
        
        // Thêm kiểm tra anti-debugging cơ bản
        if (isBeingDebugged()) {
            // Trả về chuỗi giả khi bị debug
            memset(this->Value, '*', sizeof...(Idx));
            this->Value[sizeof...(Idx)] = '\0';
            return this->Value;
        }
        
        // Lưu bản sao trước khi giải mã để kiểm tra
        char original[sizeof...(Idx)];
        memcpy(original, this->Value, sizeof...(Idx));
        
        // Giải mã theo thứ tự ngược lại của mã hóa
        for(uintptr_t t = 0; t < sizeof...(Idx); t++) {
            // Đảo ngược layer 4
            this->Value[t] = this->Value[t] ^ vxCplEncryptCharKey3;
            
            // Đảo ngược layer 3
            this->Value[t] = this->Value[t] ^ ((vxCplEncryptCharKey2 + t) % 256);
            
            // Đảo ngược layer 2
            this->Value[t] = ((this->Value[t] ^ vxCplEncryptCharKey1) >> 3) | 
                          ((this->Value[t] ^ vxCplEncryptCharKey1) << 5);
            
            // Đảo ngược layer 1
            this->Value[t] = this->Value[t] ^ (vxCplEncryptCharKey + t);
        }
        
        this->Value[sizeof...(Idx)] = '\0';
        
        // Tính và lưu checksum
        this->Checksum = calculateChecksum(this->Value, sizeof...(Idx));
        this->Decrypted = true;
        
        return this->Value;
    }
    
    // Hàm kiểm tra tính toàn vẹn
    inline bool verifyIntegrity() {
        if (!Decrypted) return false;
        return (this->Checksum == calculateChecksum(this->Value, sizeof...(Idx)));
    }
};

// Lớp mã hóa chuỗi siêu nâng cao với nhiều lớp bảo vệ
template <typename IndexList> struct vxCplUltraEncryptedString;
template <uintptr_t... Idx> struct vxCplUltraEncryptedString<vxCplIndexList<Idx...>>
{
    char Value[sizeof...(Idx) + 1]; // Buffer cho chuỗi
    char VerifyBuffer[sizeof...(Idx) + 1]; // Buffer thứ hai để kiểm tra
    uint32_t Checksum; // Checksum 32-bit để kiểm tra toàn vẹn
    uint32_t AccessCount; // Đếm số lần truy cập
    volatile uint8_t Canary; // Canary để phát hiện stack overflow
    
    // Constructor thời gian biên dịch
    constexpr ALWAYS_INLINE vxCplUltraEncryptedString(const char* const Str)
    : Value{ vxCplAdvancedTransform(Str[Idx], Idx)... }, 
      VerifyBuffer{ vxCplEncryptCharAdvanced(Str[Idx], Idx)... },
      Checksum(0), AccessCount(0), Canary(0x42) {}

    // Tính toán checksum phức tạp
    inline uint32_t calculateStrongChecksum(const char* str, size_t len) {
        uint32_t hash = 0x811C9DC5; // FNV-1a hash basis
        for (size_t i = 0; i < len; i++) {
            hash ^= str[i];
            hash *= 0x01000193; // FNV-1a prime
            hash ^= (i & 0xFF);
        }
        return hash ^ (vxCplEncryptCharKey1 << 24 | vxCplEncryptCharKey2 << 16 | 
                      vxCplEncryptCharKey3 << 8 | vxCplEncryptCharKey);
    }

    // Kiểm tra debug và các kỹ thuật phân tích
    inline bool isTampering() {
        if (this->Canary != 0x42) return true;
        
        #ifdef __APPLE__
        int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
        struct kinfo_proc info;
        size_t size = sizeof(info);
        if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return true;
        if ((info.kp_proc.p_flag & P_TRACED) != 0) return true;
        #endif
        
        if (this->AccessCount > 10) return true; // Phát hiện nếu có quá nhiều lần truy cập
        
        return false;
    }

    // Giải mã với nhiều biện pháp bảo vệ
    inline const char* decrypt()
    {
        this->AccessCount++; // Tăng bộ đếm truy cập
        
        // Kiểm tra các dấu hiệu giả mạo hoặc phân tích
        if (isTampering()) {
            memset(this->Value, 0, sizeof...(Idx));
            this->Value[0] = 'E';
            this->Value[1] = 'R';
            this->Value[2] = 'R';
            this->Value[sizeof...(Idx)] = '\0';
            return this->Value;
        }
        
        // Thêm độ trễ ngẫu nhiên để chống timing attacks
        usleep(this->AccessCount % 3);
        
        // Giải mã với nhiều bước phức tạp
        char tempBuffer[sizeof...(Idx) + 1];
        memcpy(tempBuffer, this->Value, sizeof...(Idx));
        
        // Giải mã phức tạp
        for(uintptr_t t = 0; t < sizeof...(Idx); t++) {
            char temp = tempBuffer[t];
            
            // Đảo ngược các lớp biến đổi
            temp ^= vxCplEncryptCharKey ^ vxCplEncryptCharKey3;
            temp = (temp * 197) % 256; // Đảo ngược phép nhân với 13
            temp = temp - (char)((t * 7) % 256);
            temp = ((temp << 1) | (temp >> 7)) ^ (vxCplEncryptCharKey2 + t);
            
            this->Value[t] = temp;
        }
        
        this->Value[sizeof...(Idx)] = '\0';
        
        // Tính và lưu checksum
        this->Checksum = calculateStrongChecksum(this->Value, sizeof...(Idx));
        
        return this->Value;
    }
    
    // Kiểm tra toàn vẹn mạnh mẽ
    inline bool verifyIntegrity() {
        if (this->Canary != 0x42) return false;
        if (this->Checksum == 0) return false;
        
        uint32_t currentChecksum = calculateStrongChecksum(this->Value, sizeof...(Idx));
        if (currentChecksum != this->Checksum) return false;
        
        // Giải mã buffer xác minh để so sánh
        char verifyTemp[sizeof...(Idx) + 1];
        memcpy(verifyTemp, this->VerifyBuffer, sizeof...(Idx));
        
        for(uintptr_t t = 0; t < sizeof...(Idx); t++) {
            verifyTemp[t] = verifyTemp[t] ^ vxCplEncryptCharKey3;
            verifyTemp[t] = verifyTemp[t] ^ ((vxCplEncryptCharKey2 + t) % 256);
            verifyTemp[t] = ((verifyTemp[t] ^ vxCplEncryptCharKey1) >> 3) | 
                         ((verifyTemp[t] ^ vxCplEncryptCharKey1) << 5);
            verifyTemp[t] = verifyTemp[t] ^ (vxCplEncryptCharKey + t);
        }
        verifyTemp[sizeof...(Idx)] = '\0';
        
        // So sánh cả hai kết quả
        return (memcmp(this->Value, verifyTemp, sizeof...(Idx)) == 0);
    }
};

// Macro mã hóa cơ bản - giữ tương thích ngược
#define ENCRYPT(Str) (vxCplEncryptedString<vxCplIndexes<sizeof(Str) - 1>::Result>(Str).decrypt())

// Macro mã hóa nâng cao với kiểm tra tính toàn vẹn
#define ENCRYPT_SECURE(Str) ([]() -> const char* { \
    static auto encStr = vxCplAdvancedEncryptedString<vxCplIndexes<sizeof(Str) - 1>::Result>(Str); \
    const char* decrypted = encStr.decrypt(); \
    if (!encStr.verifyIntegrity()) { \
        return "INTEGRITY_ERROR"; \
    } \
    return decrypted; \
})()

// Macro mã hóa siêu nâng cao với nhiều lớp bảo vệ
#define ENCRYPT_ULTRA(Str) ([]() -> const char* { \
    static auto encStr = vxCplUltraEncryptedString<vxCplIndexes<sizeof(Str) - 1>::Result>(Str); \
    const char* decrypted = encStr.decrypt(); \
    if (!encStr.verifyIntegrity()) { \
        return "SECURITY_VIOLATION"; \
    } \
    return decrypted; \
})()

#ifdef __APPLE__
// Compile-time Objective-c string encryption macros
#define NSSENCRYPT(Str) @(ENCRYPT(Str))
#define NSSENCRYPT_SECURE(Str) @(ENCRYPT_SECURE(Str))
#define NSSENCRYPT_ULTRA(Str) @(ENCRYPT_ULTRA(Str))
#endif

// Compile-time offset string encryption macro, converts back to uint64_t
#define ENCRYPTOFFSET(Str) strtoull(ENCRYPT(Str), NULL, 0)
#define ENCRYPTOFFSET_SECURE(Str) strtoull(ENCRYPT_SECURE(Str), NULL, 0)

// Compile-time hex string encryption macro
#define ENCRYPTHEX(Str) ENCRYPT(Str)
#define ENCRYPTHEX_SECURE(Str) ENCRYPT_SECURE(Str)