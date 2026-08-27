/*
 * Minimal N-API addon so dlopen succeeds for private Windows-only modules
 * that have no public Linux source or prebuild.
 */
#include <node_api.h>

static napi_value Init(napi_env env, napi_value exports) { return exports; }

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
