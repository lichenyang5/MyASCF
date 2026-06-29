---
title: 从 H5 按钮到 OpenHarmony 能力调用：我如何理解 ASCF 的运行链路
date: 2026-06-26
category: HarmonyOS
tags:
  - HarmonyOS
  - ASCF
  - ArkWeb
  - JSBridge
description: 从一次 H5 按钮点击出发，理解 ASCF Demo 中 H5、ArkWeb、ArkTS、Controller、Dispatcher、Register、Biz、Imp、OpenHarmony API 的完整调用链路。
---

# 从 H5 按钮到 OpenHarmony 能力调用：我如何理解 ASCF 的运行链路

我一开始看 ASCF 架构图的时候，最困惑的不是某个 API 怎么写，而是这个问题：

> H5 点了一个按钮，为什么最后能调用到 OpenHarmony 的底层能力？

如果直接看图，会看到很多词：

```text
Main Process
RenderProcess
Service Thread
Main Thread
UI Thread
JSVM
ArkWeb
JavaScriptProxy
runJavaScript
IPC
JSAPI
NAPI
```

这些词一起出现，很容易乱。

后来我发现，不能一开始就背概念。更好的方式是先把一次调用跑通。

也就是：

```text
H5 按钮
  ↓
ArkTS 收到请求
  ↓
找到对应 action
  ↓
执行系统能力
  ↓
把结果回传给 H5
```

这条线跑通之后，再回头看 IPC、JSVM、NAPI，就会清楚很多。

---

## 一、H5 自己不能直接调用系统能力

假设 H5 里有一个按钮：

```html
<button onclick="writeClipboard()">写入剪贴板</button>
```

点击之后，H5 想写入系统剪贴板：

```js
window.ascf.send('clipboard.writeText', {
  text: 'hello ASCF'
})
```

问题是，H5 不能直接调用 OpenHarmony 的 `pasteboard` API。

H5 能做的是页面里的事：

```text
处理点击
执行页面 JavaScript
操作 DOM
管理 Promise
展示结果
```

但是它不能直接访问 HarmonyOS 系统能力，也不能直接 import C++ native `.so`。

所以中间必须有一座桥。

在 MyASCF 里，这座桥就是：

```js
window.ascfBridge.send(JSON.stringify(request))
```

它背后对应 ArkWeb 提供的 `JavaScriptProxy` 能力。

---

## 二、一次调用的完整链路

先不管线程，也不管进程，只看应用层调用链。

MyASCF 里的调用链路可以写成：

```text
H5 Button
  ↓
window.ascf.send(action, params)
  ↓
window.ascfBridge.send(rawReq)
  ↓
JavaScriptProxy
  ↓
AscfBridgeObject.send(rawReq)
  ↓
BridgeController
  ↓
BridgeDispatcher
  ↓
HandlerRegister
  ↓
Biz
  ↓
Imp
  ↓
JSAPI / NAPI
  ↓
OpenHarmony API / C++ Native
  ↓
BridgeResponse
  ↓
runJavaScript
  ↓
window.__ascfResolve(response)
  ↓
H5 Promise resolve / reject
  ↓
页面更新
```

这条链路就是 Demo 的主线。

它不是完整复现 ASCF 内核，但是已经复现了应用层最重要的能力调用模型。

---

## 三、Request：H5 发出的不是函数调用，而是一份协议

H5 不是直接调用 `ClipboardImp.writeText()`。

H5 发出的是一份 JSON 请求：

```json
{
  "requestId": "req_001",
  "action": "clipboard.writeText",
  "params": {
    "text": "hello ASCF"
  },
  "timeout": 5000
}
```

这个请求里面最关键的是两个字段：

```text
requestId：这次请求的唯一标识，用于回调时找到对应 Promise
action：能力名，例如 clipboard.writeText、native.addByNapi
```

所以，H5 和 ArkTS 之间传的不是“一个函数”，而是“一个协议”。

这也是为什么后面需要 Controller、Dispatcher、Register。

---

## 四、Controller：入口层，只负责接收和解析请求

ArkTS 收到 `rawReq` 之后，第一步不是马上调用系统 API。

它要先判断：

```text
JSON 是否合法？
requestId 是否存在？
action 是否存在？
params 是否符合要求？
```

这就是 `BridgeController` 的职责。

它像一个前台接待员。

它不处理具体业务，只负责把请求整理成统一格式：

```text
rawReq
  ↓
BridgeRequest
```

再把处理结果封装成统一响应：

```text
BridgeResponse
  ↓
JSON string
```

这样 H5 不需要关心 ArkTS 内部怎么处理，只需要等待统一格式的 response。

---

## 五、Dispatcher 和 Register：把 action 变成真正的能力调用

如果没有分发层，Controller 里可能会出现很多判断：

```ts
if (action === 'runtime.ping') {
  // ...
} else if (action === 'clipboard.writeText') {
  // ...
} else if (action === 'native.addByNapi') {
  // ...
}
```

功能少的时候还能忍，功能多了就很难维护。

所以要拆成：

```text
BridgeController
  ↓
BridgeDispatcher
  ↓
HandlerRegister
```

`Dispatcher` 只负责一件事：

> 根据 action 找 handler。

`Register` 也只负责一件事：

> 维护 action 到 handler 的映射。

比如：

```text
runtime.ping          → RuntimeBiz.ping
clipboard.writeText  → ClipboardBiz.writeText
clipboard.readText   → ClipboardBiz.readText
native.addByNapi     → NativeBiz.addByNapi
```

如果 action 没有注册，就返回：

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

这一步让整个架构开始像一个框架，而不是一堆 if else。

---

## 六、Biz 和 Imp：为什么要分两层？

一开始，我也觉得 handler 里面直接调系统 API 就行。

比如：

```text
clipboard.writeText
  ↓
pasteboard.setData
```

但是这样写久了会有一个问题：业务语义和具体实现混在一起。

更稳的写法是：

```text
ClipboardBiz
  ↓
ClipboardImp
  ↓
OpenHarmony pasteboard API
```

`Biz` 负责业务语义：

```text
clipboard.writeText 表示“写入剪贴板”
```

`Imp` 负责具体实现：

```text
调用 pasteboard API
```

这带来一个好处：如果系统 API 变化，只需要改 Imp；如果参数规则变化，只需要改 Biz。

H5、Controller、Dispatcher、Register 都不用改。

---

## 七、Imp：真正碰系统能力的地方

以剪贴板为例，MyASCF 的真实链路是：

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
ClipboardBiz
  ↓
ClipboardImp
  ↓
OpenHarmony pasteboard API
```

这里的 `pasteboard` 就是 OpenHarmony / HarmonyOS 的系统剪贴板能力。

所以，这一层证明了：

```text
H5 不能直接调系统能力，
但 H5 可以通过 ArkTS 桥接到系统能力。
```

换句话说：

```text
H5 → ArkTS → JSAPI → OpenHarmony
```

这就是图里 `API → OpenHarmony` 这根箭头在 Demo 里的落地。

---

## 八、Response：为什么回调时必须带 requestId？

ArkTS 处理完之后，会返回一份统一响应：

```json
{
  "requestId": "req_001",
  "code": 0,
  "message": "clipboard.writeText success",
  "data": {
    "stage": "ClipboardBiz -> ClipboardImp -> OpenHarmony pasteboard"
  }
}
```

这里 `requestId` 很重要。

因为 H5 可能同时发起多个请求：

```text
req_001：写剪贴板
req_002：读剪贴板
req_003：NAPI 求和
```

当 ArkTS 回调 H5 时，H5 必须知道这个 response 对应哪个 Promise。

所以 H5 会维护一个 `pendingMap`：

```js
window.ascf.pendingMap.set(requestId, { resolve, reject })
```

等 ArkTS 回调：

```js
window.__ascfResolve(response)
```

H5 再根据 `response.requestId` 找到对应 Promise。

---

## 九、这条链路真正解决了什么？

这条链路解决的是：

```text
H5 如何安全、统一、可扩展地调用 ArkTS / OpenHarmony 能力。
```

它避免了几个问题：

```text
H5 直接碰系统 API：不现实
Controller 写一堆 if else：不可维护
Handler 直接写系统 API：业务和实现混乱
回调没有 requestId：异步请求无法匹配
错误没有统一格式：H5 难处理
```

所以 MyASCF 的价值不是“写了一个剪贴板按钮”。

真正的价值是它复现了一个小型运行时的骨架：

```text
协议
桥接
分发
注册
业务
实现
回调
错误处理
```

---

## 十、总结

这篇只讲应用层主链路。

一句话总结：

```text
H5 发出的不是普通函数调用，而是一份 BridgeRequest；
ArkTS 通过 Controller 解析请求，通过 Dispatcher / Register 找到能力；
Biz 解释业务语义，Imp 调用真实能力；
最后 ArkTS 通过 runJavaScript 把 BridgeResponse 回调给 H5。
```

理解这条线之后，再去看 `JavaScriptProxy`、`runJavaScript`、`IPC`、`JSVM`、`NAPI`，就不会把所有概念混在一起。

下一篇专门讲：

```text
JavaScriptProxy 和 runJavaScript 到底有什么区别？
```

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
