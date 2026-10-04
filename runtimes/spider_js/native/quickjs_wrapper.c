/**
 * QuickJS wrapper DLL for Dart FFI compatibility.
 *
 * This wrapper dynamically loads the MinGW-compiled libquickjs.dll and
 * provides simplified functions that avoid struct return ABI issues.
 * Compiled with MSVC to ensure correct ABI compatibility with Dart FFI.
 */

#include <windows.h>
#include <stdint.h>
#include <string.h>

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
typedef JSValue (*PFN_JS_GetException)(JSContext*);
typedef JSValue (*PFN_JS_GetPropertyStr)(JSContext*, JSValue, const char*);
typedef JSValue (*PFN_JS_GetGlobalObject)(JSContext*);
typedef int (*PFN_JS_SetPropertyStr)(JSContext*, JSValue, const char*, JSValue);
typedef JSValue (*PFN_JS_NewStringLen)(JSContext*, const char*, size_t);

/* JSCFunction: JSValue f(ctx, this_val, argc, argv) */
typedef JSValue (*PFN_JSCFunction)(JSContext*, JSValue, int, JSValue*);
typedef JSValue (*PFN_JS_NewCFunction2)(
    JSContext*, PFN_JSCFunction, const char*, int, int, int);

/* Microtask queue pump. JS_ExecutePendingJob returns 0 when the queue is
 * empty, 1 when it ran a job, -1 when that job raised. */
typedef int (*PFN_JS_ExecutePendingJob)(JSRuntime*, JSContext**);

/* Full collection. */
typedef void (*PFN_JS_RunGC)(JSRuntime*);

/* Resource limits. JSInterruptHandler returns non-zero to abort execution. */
typedef int (*PFN_JSInterruptHandler)(JSRuntime*, void*);
typedef void (*PFN_JS_SetInterruptHandler)(
    JSRuntime*, PFN_JSInterruptHandler, void*);
typedef void (*PFN_JS_SetMemoryLimit)(JSRuntime*, size_t);
typedef void (*PFN_JS_SetMaxStackSize)(JSRuntime*, size_t);

/* Global function pointers */
static PFN_JS_NewRuntime pJS_NewRuntime = NULL;
static PFN_JS_FreeRuntime pJS_FreeRuntime = NULL;
static PFN_JS_NewContext pJS_NewContext = NULL;
static PFN_JS_FreeContext pJS_FreeContext = NULL;
static PFN_JS_Eval pJS_Eval = NULL;
static PFN_JS_ToCStringLen2 pJS_ToCStringLen2 = NULL;
static PFN_JS_FreeCString pJS_FreeCString = NULL;
static PFN_JS_FreeValue pJS_FreeValue = NULL;
static PFN_JS_GetException pJS_GetException = NULL;
static PFN_JS_GetPropertyStr pJS_GetPropertyStr = NULL;
static PFN_JS_GetGlobalObject pJS_GetGlobalObject = NULL;
static PFN_JS_SetPropertyStr pJS_SetPropertyStr = NULL;
static PFN_JS_NewStringLen pJS_NewStringLen = NULL;
static PFN_JS_NewCFunction2 pJS_NewCFunction2 = NULL;
static PFN_JS_ExecutePendingJob pJS_ExecutePendingJob = NULL;
static PFN_JS_RunGC pJS_RunGC = NULL;
static PFN_JS_SetInterruptHandler pJS_SetInterruptHandler = NULL;
static PFN_JS_SetMemoryLimit pJS_SetMemoryLimit = NULL;
static PFN_JS_SetMaxStackSize pJS_SetMaxStackSize = NULL;

static HMODULE hQuickJS = NULL;

/* Defined with the host bridge below; needed by qs_free_context. */
static void qs_host_forget(JSContext* ctx);

/* Defined with the resource limits below; needed by qs_free_runtime. */
static void qs_limit_forget(JSRuntime* rt);

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

    /* Optional: only used for exception diagnostics. A libquickjs build that
     * lacks them degrades to "exception without text" rather than failing
     * init outright, so they stay out of the mandatory check below. */
    pJS_GetException = (PFN_JS_GetException)GetProcAddress(hQuickJS, "JS_GetException");
    pJS_GetPropertyStr = (PFN_JS_GetPropertyStr)GetProcAddress(hQuickJS, "JS_GetPropertyStr");
    pJS_GetGlobalObject = (PFN_JS_GetGlobalObject)GetProcAddress(hQuickJS, "JS_GetGlobalObject");
    pJS_SetPropertyStr = (PFN_JS_SetPropertyStr)GetProcAddress(hQuickJS, "JS_SetPropertyStr");
    pJS_NewStringLen = (PFN_JS_NewStringLen)GetProcAddress(hQuickJS, "JS_NewStringLen");
    pJS_NewCFunction2 = (PFN_JS_NewCFunction2)GetProcAddress(hQuickJS, "JS_NewCFunction2");

    /* Optional: microtask pump. Without it a Promise never settles, so any
     * script whose entry points are `async` returns an unresolved Promise and
     * the caller sees an empty object. A build lacking it still evaluates
     * synchronous scripts, so this stays out of the mandatory check; Dart asks
     * qs_drain_jobs and reports the limitation instead of pretending. */
    pJS_ExecutePendingJob =
        (PFN_JS_ExecutePendingJob)GetProcAddress(hQuickJS, "JS_ExecutePendingJob");

    /* Optional: full collection before teardown. See qs_free_runtime. */
    pJS_RunGC = (PFN_JS_RunGC)GetProcAddress(hQuickJS, "JS_RunGC");

    /* Optional: resource limits. A build without them still runs scripts, it
     * just cannot bound them -- qs_set_* report failure so Dart can say so
     * instead of silently pretending a runaway script will be stopped. */
    pJS_SetInterruptHandler =
        (PFN_JS_SetInterruptHandler)GetProcAddress(hQuickJS, "JS_SetInterruptHandler");
    pJS_SetMemoryLimit =
        (PFN_JS_SetMemoryLimit)GetProcAddress(hQuickJS, "JS_SetMemoryLimit");
    pJS_SetMaxStackSize =
        (PFN_JS_SetMaxStackSize)GetProcAddress(hQuickJS, "JS_SetMaxStackSize");

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
    if (!rt) return;
    /* Drop the limit entry first, for the same reason qs_free_context drops the
     * host entry: the allocator will hand this address back out. */
    qs_limit_forget((JSRuntime*)rt);

    /* Collect before tearing down. Measured: this does NOT prevent the
     * JS_FreeRuntime assertion described in qs_run_gc -- it is here because it
     * is the right order anyway (let QuickJS release what it can while it still
     * knows its own layout) and it is cheap at teardown. */
    if (pJS_RunGC) pJS_RunGC((JSRuntime*)rt);

    if (pJS_FreeRuntime) pJS_FreeRuntime((JSRuntime*)rt);
}

/**
 * Run a full collection. Safe at any point; unlike qs_free_runtime it does not
 * tear anything down.
 *
 * Exists so a caller can release a finished instance's memory **without**
 * calling JS_FreeRuntime, which on the vendored libquickjs aborts the process
 * roughly half the time after a real drpy2 session (assert-enabled custom
 * build; see runtimes/spider_js/README.md). Freeing the context is reliable --
 * only the runtime teardown is not -- so the child frees the context, collects
 * here, and parks the runtime until the process exits.
 *
 * Returns 1 when a collection actually ran.
 */
__declspec(dllexport) int qs_run_gc(void* rt) {
    if (!rt || !pJS_RunGC) return 0;
    pJS_RunGC((JSRuntime*)rt);
    return 1;
}

__declspec(dllexport) void* qs_new_context(void* rt) {
    if (!pJS_NewContext || !rt) return NULL;
    return (void*)pJS_NewContext((JSRuntime*)rt);
}

__declspec(dllexport) void qs_free_context(void* ctx) {
    if (!ctx) return;
    /* Drop the host entry first: once the context is gone its slot must not
     * be matched again, and the slot has to be reusable by the next context
     * (the allocator happily hands back the same address). */
    qs_host_forget((JSContext*)ctx);
    if (pJS_FreeContext) pJS_FreeContext((JSContext*)ctx);
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

/* qs_drain_jobs return codes. A non-negative value is the number of jobs run. */
#define QS_DRAIN_FAILED (-1)      /* a job raised; exception left on ctx */
#define QS_DRAIN_UNAVAILABLE (-2) /* this libquickjs exports no job API */

/* Backstop only. A script can enqueue jobs forever (Promise.resolve().then(f)
 * where f re-enqueues), and the real guard for that is the wall-clock deadline
 * armed via qs_arm_deadline -- JS_ExecutePendingJob runs bytecode, so the
 * interrupt handler fires inside a runaway job and turns it into a normal
 * exception. The cap exists so a build without JS_SetInterruptHandler still
 * terminates instead of spinning forever. */
#define QS_DRAIN_MAX_JOBS 100000

/**
 * Run queued microtasks until the queue is empty.
 *
 * JS_Eval only runs the synchronous part of a script: a Promise callback is a
 * *job* that sits on the runtime's queue until something pumps it, and nothing
 * in the plain C API does that on its own. Without this pump `p.then(cb)`
 * never calls cb and `async function f(){ return 1 }` never resolves, so
 * `JSON.stringify(f())` yields "{}" and the caller silently sees no data.
 *
 * Returns the number of jobs executed, QS_DRAIN_FAILED when a job raised (the
 * exception is left on ctx for the caller to claim, exactly like qs_eval), or
 * QS_DRAIN_UNAVAILABLE when this libquickjs has no JS_ExecutePendingJob.
 */
__declspec(dllexport) int qs_drain_jobs(void* rt, void* ctx, int max_jobs) {
    if (!rt || !ctx) return QS_DRAIN_UNAVAILABLE;
    if (!pJS_ExecutePendingJob) return QS_DRAIN_UNAVAILABLE;
    if (max_jobs <= 0) max_jobs = QS_DRAIN_MAX_JOBS;

    JSRuntime* r = (JSRuntime*)rt;
    int ran = 0;

    while (ran < max_jobs) {
        JSContext* job_ctx = NULL;
        int rc = pJS_ExecutePendingJob(r, &job_ctx);
        if (rc == 0) break;        /* queue drained */
        if (rc < 0) return QS_DRAIN_FAILED;
        ran++;
    }

    return ran;
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
 * Claim the pending exception. Returns 1 if one was retrieved.
 *
 * qs_eval can only hand back the JS_EXCEPTION sentinel, which carries no
 * information at all — the actual Error object lives on the context and has
 * to be claimed with JS_GetException. Without this, a failing script is
 * indistinguishable from one returning undefined.
 *
 * Caller owns the returned value and must release it with qs_free_value.
 */
__declspec(dllexport) int qs_get_exception(
    void* ctx,
    int64_t* out_tag,
    uint64_t* out_u
) {
    if (!pJS_GetException || !ctx) return 0;

    JSValue exc = pJS_GetException((JSContext*)ctx);
    *out_tag = exc.tag;
    *out_u = exc.u.uint64;
    return 1;
}

/**
 * Read property [prop] off a JSValue. Returns 1 on success.
 *
 * Used to reach Error.stack for the stack-carrying SCRIPT_RUNTIME_ERROR that
 * docs/05-Spider引擎.md requires. Caller must release the result.
 */
__declspec(dllexport) int qs_get_prop_str(
    void* ctx,
    int64_t val_tag,
    uint64_t val_u,
    const char* prop,
    int64_t* out_tag,
    uint64_t* out_u
) {
    if (!pJS_GetPropertyStr || !ctx) return 0;

    JSValue val;
    val.tag = val_tag;
    val.u.uint64 = val_u;

    JSValue res = pJS_GetPropertyStr((JSContext*)ctx, val, prop);
    *out_tag = res.tag;
    *out_u = res.u.uint64;
    return 1;
}

/**
 * Free a JSValue, reconstructed from tag and u.
 *
 * The only symbol libquickjs exports is __JS_FreeValue — the *finalizer*,
 * which asserts ref_count == 0 on entry. The public JS_FreeValue is a static
 * inline (no symbol to bind), so its body has to be reproduced here:
 *
 *     if (has_ref_count(v) && --p->ref_count <= 0) __JS_FreeValue(ctx, v);
 *
 * Doing that needs to know where ref_count sits, and this DLL does not match
 * mainline QuickJS on that point. Measured against the shipped libquickjs.dll:
 *
 *   - strings (tag -7): first int32 IS the refcount ('a'+'b' -> 2, an
 *     interned literal -> 0x80000003, i.e. 3 with a flag bit set)
 *   - objects (tag -1): first 8 bytes are a LIST POINTER, not ref_count —
 *     three objects allocated in a row read back 0x…fc9db40 / …fc9db88 /
 *     …fc9dbd0, i.e. neighbouring gc_obj_list nodes
 *
 * So neither hand-rolled strategy works for objects against this DLL:
 *   - decrementing writes into what is actually a list pointer (corruption)
 *   - calling the finalizer directly access-violates
 *
 * The way out is to never do the arithmetic ourselves for objects and instead
 * hand the reference back to QuickJS, which knows its own layout.
 * JS_SetPropertyStr *consumes* the value it stores, so stashing the object in
 * a scratch slot and then overwriting that slot with undefined makes QuickJS
 * run its own JS_FreeValue on it. See qs_release_object.
 *
 * If those symbols are missing we fall back to leaking the object: on an
 * assert-enabled libquickjs the leak trips `list_empty(&rt->gc_obj_list)` at
 * JS_FreeRuntime, which is still better than corruption or an access
 * violation. Callers should keep values that reach Dart to strings and
 * primitives regardless — see JsRuntime._wrap.
 *
 * tag >= 0 (INT, BOOL, NULL, UNDEFINED, EXCEPTION) hold no heap reference.
 */
typedef struct JSRefCountHeader {
    int ref_count;
} JSRefCountHeader;

#define QS_TAG_OBJECT (-1)
#define QS_TAG_UNDEFINED (3)
#define QS_SINK_PROP "__qs_sink"

static JSValue qs_undefined(void) {
    JSValue v;
    v.u.uint64 = 0;
    v.tag = QS_TAG_UNDEFINED;
    return v;
}

static int qs_can_sink(void) {
    return pJS_GetGlobalObject && pJS_SetPropertyStr;
}

/**
 * Give an owned object reference back to QuickJS without touching ref_count.
 *
 * JS_SetPropertyStr consumes its value argument, so storing `val` in a scratch
 * property transfers our reference to the property slot; overwriting the slot
 * with undefined then makes QuickJS release it through its own JS_FreeValue.
 * The same two-step returns the reference JS_GetGlobalObject handed us —
 * passing the global as `this_obj` is a borrow, and the context keeps it alive
 * throughout.
 */
static void qs_release_object(JSContext* ctx, JSValue val) {
    if (!qs_can_sink()) return; /* leak; see comment above */

    JSValue g = pJS_GetGlobalObject(ctx);

    pJS_SetPropertyStr(ctx, g, QS_SINK_PROP, val);
    pJS_SetPropertyStr(ctx, g, QS_SINK_PROP, qs_undefined());

    /* now return our reference to the global object itself */
    pJS_SetPropertyStr(ctx, g, QS_SINK_PROP, g);
    pJS_SetPropertyStr(ctx, g, QS_SINK_PROP, qs_undefined());
}

__declspec(dllexport) void qs_free_value(void* ctx, int64_t val_tag, uint64_t val_u) {
    if (!ctx) return;
    if (val_tag >= 0) return;
    if (!pJS_FreeValue) return;

    JSValue val;
    val.tag = val_tag;
    val.u.uint64 = val_u;
    if (!val.u.ptr) return;

    if (val_tag == QS_TAG_OBJECT) {
        qs_release_object((JSContext*)ctx, val);
        return;
    }

    JSRefCountHeader* p = (JSRefCountHeader*)val.u.ptr;
    if (--p->ref_count <= 0) {
        pJS_FreeValue((JSContext*)ctx, val);
    }
}

/* ---- Host bridge ------------------------------------------------------- */

/**
 * Dart-side dispatcher: takes a method name and a JSON argument array, returns
 * a freshly allocated JSON result string (or NULL). qs_host_release hands that
 * allocation back to Dart once it has been copied into a JS string.
 */
typedef const char* (*PFN_HOST_DISPATCH)(const char* name, const char* args_json);
typedef void (*PFN_HOST_RELEASE)(const char* ptr);

/**
 * Dispatch targets are per-context, NOT process-global.
 *
 * Each JsRuntime owns its own context and its own Dart NativeCallable, and
 * NativeCallable.isolateLocal may only be invoked from the isolate that
 * created it. A single global slot gets clobbered as soon as a second runtime
 * registers -- the first context then calls into the second isolate's callback
 * and the process dies with an access violation. `dart test` reproduces this
 * immediately because it runs suites in parallel isolates; in production the
 * same thing happens with one context per source.
 */
#define QS_MAX_HOSTS 64

typedef struct {
    JSContext* ctx;
    PFN_HOST_DISPATCH dispatch;
    PFN_HOST_RELEASE release;
} QsHostEntry;

static QsHostEntry g_hosts[QS_MAX_HOSTS];
static CRITICAL_SECTION g_hosts_lock;

static QsHostEntry* qs_host_find(JSContext* ctx) {
    for (int i = 0; i < QS_MAX_HOSTS; i++) {
        if (g_hosts[i].ctx == ctx) return &g_hosts[i];
    }
    return NULL;
}

static void qs_host_forget(JSContext* ctx) {
    EnterCriticalSection(&g_hosts_lock);
    QsHostEntry* e = qs_host_find(ctx);
    if (e) {
        e->ctx = NULL;
        e->dispatch = NULL;
        e->release = NULL;
    }
    LeaveCriticalSection(&g_hosts_lock);
}

/**
 * The single JS-visible entry point: __qs_host(name, argsJson) -> string.
 *
 * Everything crosses as strings, which keeps this consistent with the JSValue
 * boundary rule documented on qs_free_value: no JS object ever reaches Dart.
 * The friendly drpy surface (pdfh/pdfa/md5/...) is layered on top of this in
 * JS by the prelude in JsRuntime._prelude.
 */
static JSValue qs_host_trampoline(
    JSContext* ctx,
    JSValue this_val,
    int argc,
    JSValue* argv
) {
    (void)this_val;

    if (!pJS_ToCStringLen2 || !pJS_NewStringLen || argc < 2) {
        return qs_undefined();
    }

    EnterCriticalSection(&g_hosts_lock);
    QsHostEntry* entry = qs_host_find(ctx);
    PFN_HOST_DISPATCH dispatch = entry ? entry->dispatch : NULL;
    PFN_HOST_RELEASE release = entry ? entry->release : NULL;
    LeaveCriticalSection(&g_hosts_lock);

    if (!dispatch) return qs_undefined();

    const char* name = pJS_ToCStringLen2(ctx, NULL, argv[0], 0);
    if (!name) return qs_undefined();

    const char* args = pJS_ToCStringLen2(ctx, NULL, argv[1], 0);
    if (!args) {
        pJS_FreeCString(ctx, name);
        return qs_undefined();
    }

    const char* out = dispatch(name, args);

    JSValue result;
    if (out) {
        result = pJS_NewStringLen(ctx, out, strlen(out));
        if (release) release(out);
    } else {
        result = qs_undefined();
    }

    pJS_FreeCString(ctx, name);
    pJS_FreeCString(ctx, args);
    return result;
}

/**
 * Install __qs_host on the global object. Returns 1 on success.
 *
 * Registering requires JS_NewCFunction2 / JS_GetGlobalObject /
 * JS_SetPropertyStr / JS_NewStringLen; a libquickjs build missing any of them
 * simply gets no host bridge (Dart reports it and the drpy surface stays
 * unavailable) rather than a half-installed global.
 */
__declspec(dllexport) int qs_register_host(
    void* ctx,
    PFN_HOST_DISPATCH dispatch,
    PFN_HOST_RELEASE release
) {
    if (!ctx || !dispatch) return 0;
    if (!pJS_NewCFunction2 || !pJS_GetGlobalObject || !pJS_SetPropertyStr ||
        !pJS_NewStringLen) {
        return 0;
    }

    JSContext* c = (JSContext*)ctx;

    EnterCriticalSection(&g_hosts_lock);
    QsHostEntry* entry = qs_host_find(c);
    if (!entry) entry = qs_host_find(NULL); /* first free slot */
    if (entry) {
        entry->ctx = c;
        entry->dispatch = dispatch;
        entry->release = release;
    }
    LeaveCriticalSection(&g_hosts_lock);

    if (!entry) return 0; /* table full */

    /* JS_CFUNC_generic == 0 */
    JSValue fn = pJS_NewCFunction2(c, qs_host_trampoline, "__qs_host", 2, 0, 0);
    if (fn.tag == 6) { /* JS_TAG_EXCEPTION */
        qs_host_forget(c);
        return 0;
    }

    JSValue g = pJS_GetGlobalObject(c);
    pJS_SetPropertyStr(c, g, "__qs_host", fn); /* consumes fn */
    qs_release_object(c, g);
    return 1;
}

/* ---- Resource limits ---------------------------------------------------- */

/**
 * Deadlines are per-runtime, for the same reason host dispatch is per-context:
 * one process hosts many sources. A process-global deadline would let one
 * source's runaway loop abort a different source's healthy script, which is
 * exactly what the "does not affect other sources in the same process" exit
 * criterion forbids.
 *
 * Memory limits need no table -- JS_SetMemoryLimit already stores them on the
 * runtime -- but the interrupt handler gets no useful opaque pointer here (it
 * is installed once per runtime, before Dart has anything to hand it), so the
 * deadline has to be looked up by JSRuntime*.
 */
#define QS_MAX_RUNTIMES 64

typedef struct {
    JSRuntime* rt;
    ULONGLONG deadline; /* GetTickCount64 value; 0 = disarmed */
    int tripped;        /* 1 once the handler actually aborted a script */
} QsLimitEntry;

static QsLimitEntry g_limits[QS_MAX_RUNTIMES];
static CRITICAL_SECTION g_limits_lock;

static QsLimitEntry* qs_limit_find(JSRuntime* rt) {
    for (int i = 0; i < QS_MAX_RUNTIMES; i++) {
        if (g_limits[i].rt == rt) return &g_limits[i];
    }
    return NULL;
}

static void qs_limit_forget(JSRuntime* rt) {
    EnterCriticalSection(&g_limits_lock);
    QsLimitEntry* e = qs_limit_find(rt);
    if (e) {
        e->rt = NULL;
        e->deadline = 0;
        e->tripped = 0;
    }
    LeaveCriticalSection(&g_limits_lock);
}

/* Claim (or reuse) this runtime's slot. Returns NULL when the table is full. */
static QsLimitEntry* qs_limit_claim(JSRuntime* rt) {
    QsLimitEntry* e = qs_limit_find(rt);
    if (!e) {
        e = qs_limit_find(NULL); /* first free slot */
        if (e) {
            e->rt = rt;
            e->deadline = 0;
            e->tripped = 0;
        }
    }
    return e;
}

/**
 * QuickJS calls this periodically while executing bytecode. Returning non-zero
 * unwinds the script with an InterruptedError exception, which qs_eval then
 * reports the usual way -- so an interrupted script is indistinguishable from
 * any other throwing script at the FFI boundary, and Dart tells them apart via
 * qs_deadline_tripped.
 */
static int qs_interrupt_handler(JSRuntime* rt, void* opaque) {
    (void)opaque;

    EnterCriticalSection(&g_limits_lock);
    QsLimitEntry* e = qs_limit_find(rt);
    int abort = 0;
    if (e && e->deadline && GetTickCount64() >= e->deadline) {
        e->tripped = 1;
        abort = 1;
    }
    LeaveCriticalSection(&g_limits_lock);

    return abort;
}

/**
 * Cap the runtime's heap. Exceeding it makes allocations fail, which surfaces
 * as a normal JS OutOfMemory exception -- the context dies, the process lives.
 * Returns 1 when the limit was applied.
 */
__declspec(dllexport) int qs_set_memory_limit(void* rt, uint64_t bytes) {
    if (!rt || !pJS_SetMemoryLimit) return 0;
    pJS_SetMemoryLimit((JSRuntime*)rt, (size_t)bytes);
    return 1;
}

/** Cap JS stack depth, so runaway recursion throws instead of smashing the
 *  native stack and taking the process with it. Returns 1 on success. */
__declspec(dllexport) int qs_set_max_stack_size(void* rt, uint64_t bytes) {
    if (!rt || !pJS_SetMaxStackSize) return 0;
    pJS_SetMaxStackSize((JSRuntime*)rt, (size_t)bytes);
    return 1;
}

/**
 * Arm a wall-clock deadline for the next evaluation and install the interrupt
 * handler if it is not already there. Returns 1 when the deadline is in force.
 *
 * Installing lazily (rather than at qs_new_runtime) keeps a build without
 * JS_SetInterruptHandler working: it just cannot arm deadlines, and says so.
 */
__declspec(dllexport) int qs_arm_deadline(void* rt, int timeout_ms) {
    if (!rt || !pJS_SetInterruptHandler || timeout_ms <= 0) return 0;

    JSRuntime* r = (JSRuntime*)rt;

    EnterCriticalSection(&g_limits_lock);
    QsLimitEntry* e = qs_limit_claim(r);
    int ok = 0;
    if (e) {
        e->deadline = GetTickCount64() + (ULONGLONG)timeout_ms;
        e->tripped = 0;
        ok = 1;
    }
    LeaveCriticalSection(&g_limits_lock);

    if (ok) pJS_SetInterruptHandler(r, qs_interrupt_handler, NULL);
    return ok;
}

/** Disarm the deadline. The tripped flag survives so Dart can read it after
 *  the failing eval returns. */
__declspec(dllexport) void qs_disarm_deadline(void* rt) {
    if (!rt) return;
    EnterCriticalSection(&g_limits_lock);
    QsLimitEntry* e = qs_limit_find((JSRuntime*)rt);
    if (e) e->deadline = 0;
    LeaveCriticalSection(&g_limits_lock);
}

/** 1 when the last armed deadline actually fired. Distinguishes "script threw"
 *  from "we killed it" -- they look identical in qs_eval's return value. */
__declspec(dllexport) int qs_deadline_tripped(void* rt) {
    if (!rt) return 0;
    EnterCriticalSection(&g_limits_lock);
    QsLimitEntry* e = qs_limit_find((JSRuntime*)rt);
    int tripped = e ? e->tripped : 0;
    LeaveCriticalSection(&g_limits_lock);
    return tripped;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    switch (fdwReason) {
        case DLL_PROCESS_ATTACH:
            InitializeCriticalSection(&g_hosts_lock);
            InitializeCriticalSection(&g_limits_lock);
            break;
        case DLL_PROCESS_DETACH:
            if (hQuickJS) {
                FreeLibrary(hQuickJS);
                hQuickJS = NULL;
            }
            DeleteCriticalSection(&g_hosts_lock);
            DeleteCriticalSection(&g_limits_lock);
            break;
    }
    return TRUE;
}
