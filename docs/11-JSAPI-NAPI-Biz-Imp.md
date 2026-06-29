---
title: JSAPI、NAPI、Biz、Imp：ASCF Demo 如何真正调用系统能力和 C++ 能力
date: 2026-06-26
category: HarmonyOS
tags:
  - HarmonyOS
  - ASCF
  - JSAPI
  - NAPI
  - C++
  - Biz
  - Imp
description: 解释 MyASCF Demo 中 clipboard.writeText、clipboard.readText、native.addByNapi 如何通过 Biz / Imp 分层分别调用 OpenHarmony 系统能力和 C++ Native 能力。
---

# JSAPI、NAPI、Biz、Imp：ASCF Demo 如何真正调用系统能力和 C++ 能力

前面讲了 H5 怎么进 ArkTS，也讲了 ArkTS 怎么回调 H5。

但是还有一个关键问题：

> ArkTS 收到请求之后，怎么真正调用 OpenHarmony 系统能力，甚至 C++ Native 能力？

在 MyASCF 里，我做了两类能力：

```text
clipboard.writeText / clipboard.readText
native.addByNapi / native.getNativeVersion
```

前者验证 JSAPI / 系统能力。

后者验证 NAPI / C++ Native 能力。

---

## 一、为什么要有 Biz / Imp？

如果只做 Demo，可以把所有逻辑写在 handler 里。

比如：

```text
clipboard.writeText handler
  ↓
直接调用 pasteboard
```

但是这不适合框架。

框架要考虑扩展。

所以我把能力拆成两层：

```text
Biz
  ↓
Imp
```

`Biz` 负责业务语义：

```text
clipboard.writeText 是写入剪贴板。
native.addByNapi 是通过 NAPI 调 C++ 求和。
```

`Imp` 负责具体实现：

```text
ClipboardImp 调 pasteboard。
NativeImp 调 C++ native module。
```

这样拆以后，调用链路变成：

```text
Register
  ↓
Biz
  ↓
Imp
  ↓
系统 API / NAPI
```

---

## 二、clipboard.writeText：调用 OpenHarmony 系统剪贴板

H5 发起请求：

```js
window.ascf.send('clipboard.writeText', {
  text: 'hello ASCF'
})
```

完整链路是：

```text
H5
  ↓
JavaScriptProxy
  ↓
BridgeController
  ↓
BridgeDispatcher
  ↓
HandlerRegister
  ↓
ClipboardBiz.writeText
  ↓
ClipboardImp.writeText
  ↓
OpenHarmony pasteboard API
  ↓
BridgeResponse
  ↓
runJavaScript
  ↓
H5 Promise resolve
```

这里最关键的是：

```text
ClipboardImp
  ↓
OpenHarmony pasteboard API
```

这说明 H5 最终确实通过 ArkTS 调到了系统能力。

但是 H5 没有直接调系统 API。

它只是发了一个 action：

```text
clipboard.writeText
```

真正接触系统能力的是 `ClipboardImp`。

---

## 三、JSAPI 是什么？

在这篇文章里，可以把 JSAPI 先理解成：

```text
ArkTS / JS 调用 OpenHarmony 系统能力的接口。
```

比如剪贴板、设备信息、文件、位置、网络等能力。

以 pasteboard 为例，它属于系统剪贴板能力。

所以这条线可以写成：

```text
ArkTS
  ↓
JSAPI
  ↓
OpenHarmony 系统能力
```

在 MyASCF 里就是：

```text
ClipboardImp
  ↓
pasteboard
```

注意，它不是 H5 的浏览器 Clipboard API。

它是 OpenHarmony / HarmonyOS 提供的系统能力。

---

## 四、native.addByNapi：调用 C++ 求和

另一个能力是：

```text
native.addByNapi
```

H5 发起：

```js
window.ascf.send('native.addByNapi', {
  a: 7,
  b: 5
})
```

完整链路是：

```text
H5
  ↓
JavaScriptProxy
  ↓
BridgeController
  ↓
BridgeDispatcher
  ↓
HandlerRegister
  ↓
NativeBiz.addByNapi
  ↓
NativeImp.addByNapi
  ↓
NAPI
  ↓
C++ add(a, b)
  ↓
返回 12
  ↓
BridgeResponse
  ↓
runJavaScript
  ↓
H5 Promise resolve
```

这个能力的重点不是加法。

重点是验证：

```text
ArkTS 可以通过 NAPI 调 C++ Native 模块。
```

---

## 五、NAPI 是什么？

NAPI，也叫 Node-API，可以先理解成：

```text
ArkTS / JS 和 C/C++ 之间的桥。
```

它不是 H5 直接调 C++ 的桥。

这句话很重要：

```text
H5 不能直接调用 NAPI。
```

正确链路是：

```text
H5
  ↓
JavaScriptProxy
  ↓
ArkTS
  ↓
NAPI
  ↓
C++
```

所以在 MyASCF 里，真正调用 NAPI 的是：

```text
NativeImp
```

不是 H5。

---

## 六、JSAPI 和 NAPI 的区别

这两个词很容易混。

可以这样记：

```text
JSAPI：
ArkTS / JS 调 OpenHarmony 系统能力。

NAPI：
ArkTS / JS 调 C++ Native 能力。
```

对应 Demo：

```text
clipboard.writeText
  ↓
ClipboardImp
  ↓
JSAPI / pasteboard
  ↓
OpenHarmony 系统剪贴板

native.addByNapi
  ↓
NativeImp
  ↓
NAPI
  ↓
C++ add(a, b)
```

一句话：

```text
JSAPI 面向系统能力；
NAPI 面向 C/C++ 扩展能力。
```

---

## 七、为什么不让 H5 直接调用 NAPI？

因为 H5 运行在 WebView 页面环境里。

它能执行页面 JS，但不能直接 import HarmonyOS native `.so` 模块。

如果让 H5 直接接触 C++，也会带来安全和边界问题。

所以更合理的链路是：

```text
H5 只发请求
ArkTS 做校验和分发
Biz 解释语义
Imp 调用真实能力
```

这就是框架的价值。

H5 不需要知道底层到底是 pasteboard，还是 C++，还是别的系统 API。

它只需要知道：

```text
action = clipboard.writeText
action = native.addByNapi
```

---

## 八、错误处理也应该在框架层统一

比如 H5 发了错误参数：

```js
window.ascf.send('native.addByNapi', {
  a: '7',
  b: 5
})
```

`NativeBiz` 应该做参数校验。

如果参数不合法，返回：

```json
{
  "requestId": "req_001",
  "code": 400,
  "message": "native.addByNapi requires number params.a and params.b",
  "data": {}
}
```

如果 action 没注册，Dispatcher 返回：

```json
{
  "requestId": "req_001",
  "code": 404,
  "message": "UNKNOWN_ACTION: unknown.action",
  "data": {
    "action": "unknown.action"
  }
}
```

如果系统能力调用失败，返回：

```json
{
  "requestId": "req_001",
  "code": 500,
  "message": "Handler execute failed",
  "data": {
    "action": "clipboard.readText"
  }
}
```

这样 H5 只需要处理统一的 response。

---

## 九、这套分层带来的好处

拆成 Biz / Imp 之后，有几个好处。

第一，H5 不依赖底层实现。

```text
H5 只知道 action，不关心 pasteboard 或 C++。
```

第二，Controller 不关心具体能力。

```text
Controller 只解析协议，不写业务。
```

第三，Register 只维护映射。

```text
action → handler
```

第四，Biz 负责参数和业务语义。

```text
native.addByNapi 必须有 number 类型的 a 和 b。
```

第五，Imp 负责真实能力调用。

```text
ClipboardImp 调 pasteboard。
NativeImp 调 NAPI。
```

这样项目会更像框架，而不是功能堆砌。

---

## 十、总结

这一篇主要讲两条能力链路：

```text
clipboard.writeText
  ↓
JSAPI / pasteboard
  ↓
OpenHarmony 系统能力
```

和：

```text
native.addByNapi
  ↓
NAPI
  ↓
C++ Native 模块
```

它们共同说明一件事：

```text
H5 不直接调用系统能力，也不直接调用 C++。
H5 只通过 JavaScriptProxy 把请求交给 ArkTS。
ArkTS 通过 Controller / Dispatcher / Register / Biz / Imp 把请求送到真正的能力实现层。
最后再通过 runJavaScript 把结果回调给 H5。
```

这就是 MyASCF 目前最核心的学习价值。

---

## 参考资料

- ArkWeb 前端页面调用应用侧函数：JavaScriptProxy / registerJavaScriptProxy  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-in-page-app-function-invoking
- ArkWeb 应用侧调用前端页面函数：runJavaScript / runJavaScriptExt  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-in-app-frontend-page-function-invoking
- WebviewController API 参考  
  https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-webview-webviewcontroller
- pasteboard 剪贴板 API  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-pasteboard
- Node-API / NAPI  
  https://developer.huawei.com/consumer/en/doc/harmonyos-references-V14/napi-V14
- IPC / RPC 开发指导  
  https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ipc-rpc-development-guideline
- JSVM API 参考  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/_j_s_v_m-V5
