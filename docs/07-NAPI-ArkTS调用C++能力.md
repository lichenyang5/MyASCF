# NAPI：ArkTS 如何调用 C++ Native 能力

## 1. 为什么 Step 8 要接 NAPI

Step 7 已经证明 Imp 可以调用 OpenHarmony 系统 API（pasteboard）。
但是 ASCF 架构图里还有一类能力：ArkTS / JS 调用 Native C++。

这类链路不是 H5 直接调 C++，而是：

```
H5
  ↓
JavaScriptProxy
  ↓
ArkTS
  ↓
NAPI / Node-API
  ↓
C++
```

Step 7 接通的是「ArkTS → 系统 API」，Step 8 接通的是「ArkTS → C++ 自定义代码」。
两条都属于「Imp 层不再返回 mock」，但走的路完全不同。

## 2. NAPI 是什么

NAPI，全称 Node-API，是 ArkTS / JS 和 C/C++ 之间的跨语言调用接口。
在 HarmonyOS 工程里：

- C++ 侧用 `napi_define_properties` 把 C 函数注册到 exports；
- 用 `napi_module_register` 把模块注册到 NAPI 运行时；
- ArkTS 侧通过 `import { add } from 'libentry.so'` 拿到 native 方法的句柄；
- 调用 `add(1, 2)` 时，NAPI 在 JS 引擎和 C++ 之间打通参数/返回值。

必须引用说明：

- 参考 HarmonyOS 官方 Node-API / NAPI 开发文档。
- 不要写成 H5 直接调用 NAPI。
- 不要把 NAPI 和 JavaScriptProxy 混为一谈。

## 3. 它和 JavaScriptProxy / runJavaScript 有什么区别

- **JavaScriptProxy**：H5 → ArkTS。Web 容器把 ArkTS 对象注入到 window 上。
- **runJavaScript**：ArkTS → H5。Web 容器主动在 WebView 里执行一段 JS。
- **NAPI / Node-API**：ArkTS（或 JS）→ C++。运行在同一个进程里，跨语言而已。

三者不是一回事，组合起来才支持「H5 → ArkTS → C++」的完整链路。

## 4. 本阶段新增 action

- `native.addByNapi` — 把 a 和 b 交给 C++ 的 `add(a, b)`，验证基础类型互通。
- `native.getNativeVersion` — 调用 C++ 的 `getNativeVersion()`，验证字符串返回。

## 5. 调用链路

```
H5 Button
  ↓
window.ascf.send("native.addByNapi", { a: 7, b: 5 })
  ↓
BridgeRequest
  ↓
JavaScriptProxy
  ↓
BridgeController.handle(rawReq)
  ↓
BridgeDispatcher.dispatch(request)
  ↓
HandlerRegister.getHandler("native.addByNapi")
  ↓
NativeBiz.addByNapi(request)
  ↓
NativeImp.addByNapi(a, b)
  ↓
napiAdd(a, b)            ← ArkTS 端的 native 句柄
  ↓
C++ Add(env, info)       ← napi_init.cpp 里的 Add 函数
  ↓
v0 + v1                  ← 真正的 C++ 计算
  ↓
napi_create_double       ← 把结果包成 napi_value
  ↓
ArkTS 收到 number
  ↓
BridgeResponse
  ↓
WebviewController.runJavaScript(...)
  ↓
window.__ascfResolve(response)
  ↓
Promise resolve
```

`getNativeVersion` 走完全一样的路，只是 C++ 端 `napi_create_string_utf8` 返回字符串。

## 6. 对应架构图里的箭头

```
NativeImp
  ↓
NAPI / Node-API
  ↓
C++ Native 模块
```

ASCF 图里这条「ArkTS → C++」的箭头，在本仓库就是：

- `NativeImp.ets` ── 那行 `napiAdd(a, b)`
- `cpp/napi_init.cpp` ── 那个 `Add(napi_env env, napi_callback_info info)`
- `cpp/CMakeLists.txt` ── 那条 `add_library(entry SHARED napi_init.cpp)`

## 7. 为什么不在 H5 里直接 import native

因为 H5 运行在 WebView 渲染环境里。
WebView 拿不到 HarmonyOS native `.so` 模块的句柄 —— `.so` 是给 ArkTS / JS 运行时用的，不是给 HTML 文档里的 `<script>` 用的。

H5 只能通过：

```
JavaScriptProxy(window.ascfBridge.send) → ArkTS → NAPI → C++
```

这条链路触达 native。NAPI **不是** H5 调用系统能力的桥，而是 ArkTS 调用 C++ 的桥。把 H5 直接和 NAPI 连线，是 ASCF 元服务架构里的反模式。

## 8. 工程结构

```
entry/
  build-profile.json5            ← 加 externalNativeOptions 指向 CMakeLists
  oh-package.json5               ← 加 dependencies: libentry.so → file:./...
  src/main/
    cpp/
      CMakeLists.txt             ← add_library(entry SHARED napi_init.cpp)
      napi_init.cpp              ← Add / GetNativeVersion / Init / 模块注册
      types/libentry/
        Index.d.ts               ← ArkTS 用的类型声明
        oh-package.json5         ← name: libentry.so, types: ./Index.d.ts
    ets/ascf/
      imp/NativeImp.ets          ← import { add, getNativeVersion } from 'libentry.so'
      biz/NativeBiz.ets          ← 参数校验 + 包装成 BridgeResponse
      register/HandlerRegister.ets ← bind 两个 native action
```

要点：

- CMake 的 `add_library(entry ...)` → 产物 `libentry.so`
- 模块注册时 `nm_modname = "entry"` → NAPI 运行时按这个名字找模块
- ArkTS `import ... from 'libentry.so'` → 通过 oh-package 依赖找到 d.ts
- 三处 `entry` / `libentry` 必须一致，改名要一起改

## 9. 验收记录

记录：

- `native.addByNapi` 是否返回 `data.result === 12`
- `native.getNativeVersion` 是否返回 `data.version === "native-cpp-v1.0.0"`
- DevEco HiLog 是否能看到 `[ASCF][NativeBiz] / [ASCF][NativeImp] / [ASCF][NAPI]` 三层
- 是否遇到 CMake 找不到 / d.ts 类型不识别 / import 模块名不匹配的问题
- 如有报错，记录报错 + 修复过程
