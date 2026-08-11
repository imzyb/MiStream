/**
 * QuickJS wrapper DLL for Dart FFI compatibility.
 *
 * This wrapper dynamically loads the MinGW-compiled libquickjs.dll and
 * provides simplified functions that avoid struct return ABI issues.
 * Compiled with MSVC to ensure correct ABI compatibility with Dart FFI.
 */

#include <windows.h>
#include <stdint.h>

/* Forward declarations for QuickJS types */
typedef struct JSRuntime JSRuntime;
typedef struct JSContext JSContext;

/* JSValue layout matching the MinGW-compiled DLL */
typedef union {
    uint64_t uint64;
    double float64;
    void* ptr;
    int64_t short_big_int;
} JSValueUnion;

typedef struct {
    JSValueUnion u;
    int64_t tag;
} JSValue;

/* Function pointer types for QuickJS functions */
typedef JSRuntime* (*PFN_JS_NewRuntime)(void);
typedef void (*PFN_JS_FreeRuntime)(JSRuntime*);
typedef JSContext* (*PFN_JS_NewContext)(JSRuntime*);
typedef void (*PFN_JS_FreeContext)(JSContext*);
typedef JSValue (*PFN_JS_Eval)(JSContext*, const char*, size_t, const char*, int);
typedef const char* (*PFN_JS_ToCStringLen2)(JSContext*, size_t*, JSValue, int);
typedef void (*PFN_JS_FreeCString)(JSContext*, const char*);
typedef void (*PFN_JS_FreeValue)(JSContext*, JSValue);

/* Global function pointers */
static PFN_JS_NewRuntime pJS_NewRuntime = NULL;
static PFN_JS_FreeRuntime pJS_FreeRuntime = NULL;
static PFN_JS_NewContext pJS_NewContext = NULL;
static PFN_JS_FreeContext pJS_FreeContext = NULL;
static PFN_JS_Eval pJS_Eval = NULL;
static PFN_JS_ToCStringLen2 pJS_ToCStringLen2 = NULL;
static PFN_JS_FreeCString pJS_FreeCString = NULL;
static PFN_JS_FreeValue pJS_FreeValue = NULL;

static HMODULE hQuickJS = NULL;

/* Exported functions using stdcall-compatible ABI with output parameters */

__declspec(dllexport) int qs_init(const char* dll_path) {
    if (hQuickJS) return 1;

    hQuickJS = LoadLibraryA(dll_path);
    if (!hQuickJS) return 0;

    pJS_NewRuntime = (PFN_JS_NewRuntime)GetProcAddress(hQuickJS, "JS_NewRuntime");
    pJS_FreeRuntime = (PFN_JS_FreeRuntime)GetProcAddress(hQuickJS, "JS_FreeRuntime");
    pJS_NewContext = (PFN_JS_NewContext)GetProcAddress(hQuickJS, "JS_NewContext");
    pJS_FreeContext = (PFN_JS_FreeContext)GetProcAddress(hQuickJS, "JS_FreeContext");
    pJS_Eval = (PFN_JS_Eval)GetProcAddress(hQuickJS, "JS_Eval");
    pJS_ToCStringLen2 = (PFN_JS_ToCStringLen2)GetProcAddress(hQuickJS, "JS_ToCStringLen2");
    pJS_FreeCString = (PFN_JS_FreeCString)GetProcAddress(hQuickJS, "JS_FreeCString");
    pJS_FreeValue = (PFN_JS_FreeValue)GetProcAddress(hQuickJS, "__JS_FreeValue");

    if (!pJS_NewRuntime || !pJS_FreeRuntime || !pJS_NewContext ||
        !pJS_FreeContext || !pJS_Eval || !pJS_ToCStringLen2 ||
        !pJS_FreeCString || !pJS_FreeValue) {
        FreeLibrary(hQuickJS);
        hQuickJS = NULL;
        return 0;
    }

    return 1;
}

__declspec(dllexport) void* qs_new_runtime(void) {
    if (!pJS_NewRuntime) return NULL;
    return (void*)pJS_NewRuntime();
}

__declspec(dllexport) void qs_free_runtime(void* rt) {
    if (pJS_FreeRuntime && rt) pJS_FreeRuntime((JSRuntime*)rt);
}

__declspec(dllexport) void* qs_new_context(void* rt) {
    if (!pJS_NewContext || !rt) return NULL;
    return (void*)pJS_NewContext((JSRuntime*)rt);
}

__declspec(dllexport) void qs_free_context(void* ctx) {
    if (pJS_FreeContext && ctx) pJS_FreeContext((JSContext*)ctx);
}

/**
 * Evaluate JS code. Returns 0 on success, -1 on exception.
 * On success, result_tag and result_u are filled with the JSValue.
 */
__declspec(dllexport) int qs_eval(
    void* ctx,
    const char* input,
    int input_len,
    const char* filename,
    int flags,
    int64_t* result_tag,
    uint64_t* result_u
) {
    if (!pJS_Eval || !ctx) return -1;

    JSValue result = pJS_Eval(
        (JSContext*)ctx,
        input,
        (size_t)input_len,
        filename,
        flags
    );

    *result_tag = result.tag;
    *result_u = result.u.uint64;

    /* JS_TAG_EXCEPTION = 6 */
    if (result.tag == 6) return -1;
    return 0;
}

/**
 * Convert JSValue to C string. Returns pointer to string or NULL.
 * Caller must call qs_free_cstring to release.
 */
__declspec(dllexport) const char* qs_to_cstring(
    void* ctx,
    int64_t val_tag,
    uint64_t val_u
) {
    if (!pJS_ToCStringLen2 || !ctx) return NULL;

    JSValue val;
    val.tag = val_tag;
    val.u.uint64 = val_u;

    return pJS_ToCStringLen2((JSContext*)ctx, NULL, val, 0);
}

__declspec(dllexport) void qs_free_cstring(void* ctx, const char* str) {
    if (pJS_FreeCString && ctx && str) pJS_FreeCString((JSContext*)ctx, str);
}

/**
 * Free a JSValue. The JSValue is reconstructed from tag and u components.
 *
 * ABI note: __JS_FreeValue takes JSValue by value. When called across the
 * MSVC wrapper → MinGW QuickJS boundary, this can cause hangs due to
 * struct-passing ABI differences. We mitigate by inlining the fast path:
 * tag >= 0 (INT=0, BOOL=1, NULL=2, UNDEFINED=3, ...) are non-heap values
 * that don't need reference counting, so we skip the call entirely.
 * Only tag < 0 (STRING=-7, OBJECT=-1, etc.) actually need the call.
 */
__declspec(dllexport) void qs_free_value(void* ctx, int64_t val_tag, uint64_t val_u) {
    if (!ctx) return;

    /* Non-ref-counted values (tag >= 0): INT, BOOL, NULL, UNDEFINED, etc.
     * These don't hold heap references — nothing to free. */
    if (val_tag >= 0) return;

    if (!pJS_FreeValue) return;

    JSValue val;
    val.tag = val_tag;
    val.u.uint64 = val_u;

    pJS_FreeValue((JSContext*)ctx, val);
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    switch (fdwReason) {
        case DLL_PROCESS_DETACH:
            if (hQuickJS) {
                FreeLibrary(hQuickJS);
                hQuickJS = NULL;
            }
            break;
    }
    return TRUE;
}
