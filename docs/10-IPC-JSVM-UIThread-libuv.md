---
title: IPC、JSVM、UIThread、libuv：ASCF 架构图里最容易混的几个词
date: 2026-06-26
category: HarmonyOS
tags:
  - HarmonyOS
  - ASCF
  - IPC
  - JSVM
  - UIThread
  - libuv
description: 解释 ASCF 双线程 / 双进程通信架构图中 IPC、JSVM、UIThread、libuv、Main Process、RenderProcess、run in 的含义。
---

# IPC、JSVM、UIThread、libuv：ASCF 架构图里最容易混的几个词

前面两篇讲的是应用层链路：

```text
H5
  ↓
JavaScriptProxy
  ↓
ArkTS
  ↓
Biz / Imp
  ↓
runJavaScript
  ↓
H5
```

这条线跑通之后，再看架构图里的这些词：

```text
Main Process
RenderProcess
Service Thread
Main Thread
UI Thread
JSVM
IPC
libuv
run in
```

就会发现，它们不是和 `Controller / Biz / Imp` 同一层的东西。

它们更多是在解释：

> 这条调用链背后的运行时环境是什么样的？

---

## 一、先纠正一个误解：渲染进程也会执行 JS

很容易误解成：

```text
H5 页面不执行 JS，等逻辑层 JSVM 执行。
```

这是错的。

H5 页面里的 JavaScript 当然会执行。

比如：

```js
button.onclick = function() {}
window.ascf.send()
window.__ascfResolve()
Promise.resolve()
document.body.innerHTML = '...'
```

这些都属于页面侧 JavaScript。

它们运行在：

```text
RenderProcess
  ↓
UI Thread
  ↓
H5 / JavaScript
```

所以渲染进程不是只画页面，它也会执行页面 JS。

---

## 二、那 JSVM 又是什么？

JSVM 可以先简单理解成：

```text
逻辑层 JavaScript 的执行引擎。
```

在小程序式架构里，常见会把运行环境拆成两层：

```text
UI 层：
负责页面渲染、用户点击、DOM 更新。

逻辑层：
负责业务逻辑、状态管理、生命周期、能力调度。
```

H5 页面里的 JS 属于 UI 层。

Service Thread 里的 JSVM 更偏逻辑层。

所以应该区分两套 JS 环境：

```text
H5 JavaScript：
页面侧 JS，负责点击、DOM、Promise、页面更新。

Service JSVM：
逻辑侧 JS，负责业务逻辑、框架运行时、能力调度。
```

JSVM 不是 `JavaScriptProxy`。

JSVM 也不是 `runJavaScript`。

它是执行 JS 的引擎环境。

---

## 三、Main Process 和 RenderProcess

架构图里通常会分成两个进程：

```text
Main Process
RenderProcess
```

可以先这样理解：

```text
RenderProcess：
WebView 渲染进程，负责 H5 页面、页面 JavaScript、UIThread、DOM 更新。

Main Process：
应用/逻辑主进程，负责 ArkTS、ArkWeb 控制、Controller、Dispatcher、Biz、Imp、系统能力调用。
```

更直观一点：

```text
用户点按钮
  ↓
RenderProcess / UIThread / H5 JS 先执行

需要调用系统能力
  ↓
通过桥发给 Main Process

Main Process 处理完成
  ↓
通过 runJavaScript 回到 RenderProcess

H5 页面更新
```

所以，不是一个进程把所有事情都做了。

---

## 四、IPC：进程之间通信

IPC 是：

```text
Inter-Process Communication
进程间通信
```

它解决的问题是：

> 两个进程之间怎么传消息？

如果 H5 在 RenderProcess，ArkTS 能力调度在 Main Process，那么它们不能像普通函数调用一样共享变量。

所以底层需要 IPC。

在业务代码里，你一般不会直接写 IPC。

你写的是：

```text
JavaScriptProxy
runJavaScript
```

底层跨进程消息传递由 ArkWeb / 系统框架处理。

所以可以这样记：

```text
JavaScriptProxy / runJavaScript：
开发者能看到的桥。

IPC：
桥底下跨进程传消息的机制。
```

IPC 不是 Controller，也不是 Biz，也不是 JavaScriptProxy 本身。

它是更底层的通信机制。

---

## 五、逻辑上双线程通信是不是 IPC？

不完全是。

“逻辑上双线程通信”是架构描述。

它强调：

```text
UI 层和逻辑层分开执行；
它们不在同一个普通函数调用栈里；
它们通过消息协作。
```

IPC 是具体机制之一。

如果 UI 层和逻辑层跨进程，那么底层会涉及 IPC。

但是不能简单说：

```text
逻辑上双线程通信 = IPC
```

更准确是：

```text
逻辑上双线程通信：
UI 层和逻辑层分离执行。

IPC：
当这种分离跨越进程边界时，用来传消息的底层机制。
```

---

## 六、Service Thread 和 Main Thread

在 Main Process 内部，图里可能还有两个线程：

```text
Service Thread
Main Thread
```

可以先这样理解：

```text
Service Thread：
逻辑层执行线程，里面可能有 JSVM，负责业务逻辑和框架运行时。

Main Thread：
应用主线程，里面有 ArkWeb、API 调用入口、UI/生命周期相关任务。
```

这两个线程之间也需要通信。

图里如果写 `libuv`，它表达的是：

```text
Service Thread ↔ Main Thread 的线程通信 / 事件调度机制。
```

不要把它和 IPC 混在一起。

```text
线程间通信：Service Thread ↔ Main Thread
进程间通信：Main Process ↔ RenderProcess
```

这是两个层级。

---

## 七、libuv 是什么位置？

在这张架构图里，libuv 不是你业务代码里直接调用的 API。

它更像运行时内部的事件循环 / 线程通信基础设施。

你可以先把它记成：

```text
Main Process 内部，Service Thread 和 Main Thread 之间协作的一种运行时机制。
```

在 MyASCF 这种应用层 Demo 里，我们不会手写 libuv。

我们能做的是在文档里解释它的位置：

```text
Service Thread
  ↔ libuv
Main Thread
```

真正写代码时，我们关注的是：

```text
JavaScriptProxy
Controller / Dispatcher / Register
Biz / Imp
runJavaScript
```

---

## 八、run in 是什么意思？

图里有时会写：

```text
run in Main Process
run in RenderProcess
```

这里的 `run in` 不是 API。

它只是英文：

```text
运行在……
```

例如：

```text
Service run in Main Process
```

意思是：

```text
Service 运行在主进程里。
```

```text
H5 run in RenderProcess
```

意思是：

```text
H5 运行在渲染进程里。
```

不要把 `run in` 当成函数名。

---

## 九、把这些概念放回一次调用里

现在再看一次 H5 调用：

```text
RenderProcess / UIThread
  ↓
H5 页面 JS 执行 button.onclick
  ↓
window.ascfBridge.send(rawReq)
  ↓
JavaScriptProxy

========== 底层可能跨进程：IPC ==========

Main Process
  ↓
ArkTS / Controller / Dispatcher / Biz / Imp
  ↓
系统 API / NAPI / C++

========== 返回时可能跨进程：IPC ==========

runJavaScript
  ↓
RenderProcess / UIThread
  ↓
window.__ascfResolve(response)
  ↓
Promise resolve
  ↓
DOM 更新
```

这样就清楚了：

```text
H5 JS 在 RenderProcess 执行。
ArkTS 能力调度在 Main Process 执行。
两边通过桥通信。
底层跨进程时需要 IPC。
逻辑层可能有 JSVM。
Main Process 内部线程协作可能涉及 libuv。
```

---

## 十、MyASCF 覆盖了什么，没有覆盖什么？

MyASCF 已经覆盖：

```text
H5 页面
H5 JavaScript
JavaScriptProxy
BridgeController
BridgeDispatcher
HandlerRegister
Biz
Imp
JSAPI / pasteboard
NAPI / C++
runJavaScript
Promise resolve / reject
```

MyASCF 没有手写覆盖：

```text
真实 IPC
真实 RenderProcess 管理
JSVM 初始化
libuv 线程通信
ArkWeb 内部调度
```

这不是问题。

因为 MyASCF 的定位是：

```text
应用层 ASCF 调用链路复现 Demo
```

不是：

```text
ASCF 运行时内核复现
```

---

## 十一、总结

这篇只记住几个对应关系：

```text
RenderProcess / UIThread：
执行 H5 页面和页面 JavaScript。

Main Process：
执行 ArkTS 侧桥接、分发、能力调用。

JSVM：
逻辑层 JavaScript 执行引擎，不等于 JavaScriptProxy。

IPC：
Main Process 和 RenderProcess 之间的底层通信机制。

libuv：
Main Process 内部 Service Thread 和 Main Thread 之间的线程通信 / 事件调度机制。

JavaScriptProxy：
H5 → ArkTS。

runJavaScript：
ArkTS → H5。
```

理解这些之后，再看 ASCF 双线程 / 双进程通信图，就不会把所有箭头都理解成一个东西。

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
