#include "napi/native_api.h"
#include "hilog/log.h"

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x3200
#define LOG_TAG "ASCF_NAPI"

static napi_value Add(napi_env env, napi_callback_info info)
{
    OH_LOG_INFO(LOG_APP, "[ASCF][NAPI] add called");

    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_valuetype valuetype0;
    napi_typeof(env, args[0], &valuetype0);
    napi_valuetype valuetype1;
    napi_typeof(env, args[1], &valuetype1);

    if (valuetype0 != napi_number || valuetype1 != napi_number) {
        napi_value result;
        napi_create_double(env, -1, &result);
        return result;
    }

    double v0 = 0;
    double v1 = 0;
    napi_get_value_double(env, args[0], &v0);
    napi_get_value_double(env, args[1], &v1);

    napi_value sum;
    napi_create_double(env, v0 + v1, &sum);
    return sum;
}

static napi_value GetNativeVersion(napi_env env, napi_callback_info info)
{
    OH_LOG_INFO(LOG_APP, "[ASCF][NAPI] getNativeVersion called");
    const char *version = "native-cpp-v1.0.0";
    napi_value result;
    napi_create_string_utf8(env, version, NAPI_AUTO_LENGTH, &result);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "add", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getNativeVersion", nullptr, GetNativeVersion, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void)
{
    napi_module_register(&demoModule);
}
