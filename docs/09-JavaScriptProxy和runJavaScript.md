---
title: JavaScriptProxy 和 runJavaScript：ASCF 里两根最重要的桥
date: 2026-06-26
category: HarmonyOS
tags:
  - HarmonyOS
  - ArkWeb
  - JavaScriptProxy
  - runJavaScript
  - JSBridge
description: 专门解释 H5 到 ArkTS、ArkTS 到 H5 两个方向的通信：JavaScriptProxy 和 runJavaScript 分别解决什么问题。
---

# JavaScriptProxy 和 runJavaScript：ASCF 里两根最重要的桥

看 ASCF 这类架构，最先要搞清楚的不是 IPC，也不是 JSVM，而是这两个东西：

```text
JavaScriptProxy
runJavaScript
```

它们一个负责 H5 调 ArkTS，一个负责 ArkTS 回调 H5。

如果这两个方向没搞清楚，后面讲 Controller、Dispatcher、JSAPI、NAPI 都会乱。

---

## 一、先从一个按钮开始

H5 页面里有一个按钮：

```html
<button onclick="callNative()">调用 ArkTS</button>
```

点击之后，H5 希望把请求发给 ArkTS。

在 MyASCF 里，它会这样写：

```js
window.ascfBridge.send(JSON.stringify({
  requestId: 'req_001',
  action: 'runtime.ping',
  params: {
    from: 'h5'
  },
  timeout: 5000
}))
```

这里的 `window.ascfBridge` 不是浏览器原生对象。

它是 ArkTS 通过 ArkWeb 注入给 H5 的对象。

这就是 `JavaScriptProxy`。

---

## 二、JavaScriptProxy：H5 调 ArkTS

`JavaScriptProxy` 解决的问题是：

> 前端页面里的 JavaScript，怎么调用应用侧 ArkTS 方法？

ArkTS 侧注册一个对象：

```ts
.javaScriptProxy({
  object: this.bridge,
  name: 'ascfBridge',
  methodList: ['send'],
  controller: this.webController
})
```

H5 侧就可以调用：

```js
window.ascfBridge.send(rawReq)
```

所以它的方向是：

```text
H5 / JavaScript
  ↓
JavaScriptProxy
  ↓
ArkTS
```

这句话很重要：

```text
JavaScriptProxy 是 H5 → ArkTS。
```

它不是 ArkTS 回调 H5。

---

## 三、AscfBridgeObject：桥对象只是入口

在 MyASCF 里，`ascfBridge` 对应 ArkTS 侧的 `AscfBridgeObject`。

它大概做这件事：

```text
H5 调 window.ascfBridge.send(rawReq)
  ↓
AscfBridgeObject.send(rawReq)
  ↓
BridgeController.handle(rawReq)
```

注意，`AscfBridgeObject` 不应该承担太多业务。

它最好只做入口：

```text
打印日志
接收 rawReq
交给 Controller
```

因为真正的协议解析、分发、业务处理，应该交给后面的层：

```text
Controller
Dispatcher
Register
Biz
Imp
```

这样桥对象就不会越来越臃肿。

---

## 四、为什么 H5 不直接拿 send 的返回值？

一开始你可能会这样写：

```js
const res = window.ascfBridge.send(rawReq)
```

这看起来很简单。

但是 ASCF 这种能力调用，更接近异步模型：

```text
H5 发请求
ArkTS 处理
可能调用系统 API
可能调用 C++
可能失败
可能超时
最后再回调 H5
```

所以更好的做法是 Promise：

```js
window.ascf.send('runtime.ping', params)
  .then(res => {
    console.log('success', res)
  })
  .catch(err => {
    console.log('failed', err)
  })
```

H5 发出去之后，不是马上拿返回值，而是等 ArkTS 处理完，再通过回调回来。

这时候就需要第二根桥：`runJavaScript`。

---

## 五、runJavaScript：ArkTS 回调 H5

`runJavaScript` 解决的问题是：

> ArkTS 怎么主动调用 H5 页面里的 JavaScript 函数？

H5 先定义一个全局函数：

```js
window.__ascfResolve = function(response) {
  const item = window.ascf.pendingMap.get(response.requestId)

  if (!item) {
    console.log('pending request not found')
    return
  }

  window.ascf.pendingMap.delete(response.requestId)

  if (response.code === 0) {
    item.resolve(response)
  } else {
    item.reject(response)
  }
}
```

ArkTS 处理完之后：

```ts
this.webController.runJavaScript(
  `window.__ascfResolve(${responseJson})`
)
```

这时 H5 页面里的 `window.__ascfResolve` 被执行。

所以方向是：

```text
ArkTS
  ↓
runJavaScript
  ↓
H5 / JavaScript
```

记住：

```text
runJavaScript 是 ArkTS → H5。
```

---

## 六、pendingMap：Promise 怎么和回调对应起来？

H5 发请求时，会生成一个 `requestId`：

```js
const requestId = 'req_' + Date.now()
```

然后把 Promise 的 `resolve` 和 `reject` 保存起来：

```js
window.ascf.pendingMap.set(requestId, {
  resolve,
  reject
})
```

请求发给 ArkTS：

```js
window.ascfBridge.send(JSON.stringify(request))
```

ArkTS 处理完之后，回调 H5：

```js
window.__ascfResolve({
  requestId: 'req_001',
  code: 0,
  message: 'success',
  data: {}
})
```

H5 再用 `requestId` 找到对应 Promise：

```js
const item = window.ascf.pendingMap.get(response.requestId)
```

所以 `requestId` 是异步回调的钥匙。

没有它，多个请求同时发出时，H5 就不知道哪个结果对应哪个请求。

---

## 七、两根桥合起来就是 JSBridge

现在可以把主链路写清楚了：

```text
H5
  ↓
window.ascf.send(...)
  ↓
window.ascfBridge.send(rawReq)
  ↓
JavaScriptProxy
  ↓
ArkTS Controller / Dispatcher / Biz / Imp
  ↓
runJavaScript
  ↓
window.__ascfResolve(response)
  ↓
H5 Promise resolve
```

这就是 MyASCF 的 JSBridge 模型。

注意，不要把这两个方向说反：

```text
JavaScriptProxy：H5 → ArkTS
runJavaScript：ArkTS → H5
```

---

## 八、JavaScriptProxy 和 runJavaScript 不是 IPC

这两个 API 是你在应用层能看到的接口。

但是如果 H5 页面运行在 WebView 渲染进程，ArkTS 逻辑运行在应用主进程，那么底层跨进程传消息时，框架内部可能会走 IPC。

所以层级关系应该是：

```text
应用层能看到：
JavaScriptProxy / runJavaScript

框架底层可能涉及：
IPC / RenderProcess / Main Process
```

不能简单说：

```text
JavaScriptProxy = IPC
runJavaScript = IPC
```

更准确是：

```text
JavaScriptProxy 和 runJavaScript 是上层桥接口；
IPC 是底层跨进程通信机制。
```

---

## 九、在 MyASCF 里如何验证？

你可以在 H5 和 ArkTS 两边都打日志。

H5：

```text
[H5] create request
[H5] call window.ascfBridge.send
[H5] window.__ascfResolve called
[H5] Promise resolve
```

ArkTS：

```text
[ASCF][Bridge] JavaScriptProxy send rawReq
[ASCF][Controller] parsed request
[ASCF][Dispatcher] dispatch action
[ASCF][Register] get handler
[ASCF][Controller] callbackToH5
[ASCF][WebRuntimePage] runJavaScript
```

看到这组日志，就说明两根桥跑通了。

---

## 十、总结

这篇只记住一句话：

```text
JavaScriptProxy 解决 H5 调 ArkTS。
runJavaScript 解决 ArkTS 回调 H5。
```

它们合起来，让 H5 和 ArkTS 可以形成一次完整的异步调用。

但是，它们不是 IPC，也不是 JSVM，也不是 NAPI。

下一篇再讲这些运行时概念：

```text
IPC、JSVM、UIThread、libuv 到底分别是什么？
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
