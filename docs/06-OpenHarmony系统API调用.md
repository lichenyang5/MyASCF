# OpenHarmony 系统 API 调用：以剪贴板 pasteboard 为例

## 1. 为什么要接系统 API

在 Step 6 之前，Imp 返回的是 mock 数据。
这只能说明架构链路跑通了，但还不能说明 H5 真的调用到了系统能力。

Step 7 的目标是让调用链路继续往下走：

```
H5
  ↓
JavaScriptProxy
  ↓
Controller
  ↓
Dispatcher
  ↓
Register
  ↓
ClipboardBiz
  ↓
ClipboardImp
  ↓
OpenHarmony pasteboard API
```

只有走到最底层的系统 API，整个 ASCF 桥接才算真的接通了元服务底座。

## 2. pasteboard 是什么

pasteboard 是 OpenHarmony / HarmonyOS 提供的系统剪贴板能力，用于支持复制、粘贴等场景。
它属于系统能力，不是 H5 自己的 localStorage，也不是浏览器前端 Clipboard API。

H5 自带的 `navigator.clipboard` 走的是 WebView 沙箱里的剪贴板，跨应用不一定可见。
而 pasteboard 是 HarmonyOS 系统全局剪贴板，写进去之后桌面上任何 App 粘贴都能拿到。

本项目使用的 import：

```typescript
import { pasteboard } from '@kit.BasicServicesKit'
```

也可以等价地写成（兼容老 SDK）：

```typescript
import pasteboard from '@ohos.pasteboard'
```

实际类型签名以本项目 SDK（HarmonyOS 6.1.0 / API 23）d.ts 提示为准。

## 3. 为什么要放在 Imp 层

Biz 负责业务语义：
`clipboard.writeText` 表示「写入剪贴板」。

Imp 负责具体实现：
调用 pasteboard API。

这样以后如果系统 API 变化（比如 OpenHarmony 升级 / 拆 kit / 改方法名），只需要改 Imp，不需要改 H5、Controller、Dispatcher、Register、Biz。
能力实现的细节被锁在了最里层，对外只暴露语义化的 action。

## 4. 本阶段新增 action

- `clipboard.writeText` — 把 `params.text` 写入系统剪贴板。
- `clipboard.readText` — 读取系统剪贴板中的文本。

## 5. 调用链路

```
H5 Button
  ↓
window.ascf.send("clipboard.writeText", params)
  ↓
BridgeRequest
  ↓
JavaScriptProxy
  ↓
BridgeController.handle(rawReq)
  ↓
BridgeDispatcher.dispatch(request)
  ↓
HandlerRegister.getHandler("clipboard.writeText")
  ↓
ClipboardBiz.writeText(request)
  ↓
ClipboardImp.writeText(text)
  ↓
pasteboard.getSystemPasteboard().setData(pasteData)   ← OpenHarmony 系统 API
  ↓
BridgeResponse
  ↓
WebviewController.runJavaScript(...)
  ↓
window.__ascfResolve(response)
  ↓
Promise resolve
```

readText 同理，只是底层换成 `getSystemPasteboard().getData()` + `PasteData.getPrimaryText()`。

## 6. 对应架构图里的箭头

```
ClipboardImp
  ↓
OpenHarmony pasteboard API
```

这就是 API → OpenHarmony 的第一条真实链路。
之前所有层（Controller / Dispatcher / Register / Biz）的存在意义，在这一步终于落了地。

## 7. 注意事项

- 读取剪贴板可能受系统安全策略限制：HarmonyOS NEXT（API 12+）默认要求用户手势触发或声明 `ohos.permission.READ_PASTEBOARD`，否则可能抛错或返回空。
- 本项目的读取是从用户点击按钮触发的，属于用户手势上下文，多数情况下可直接读到。如果设备策略更严，readText 会被 ClipboardImp catch 并抛出，最终由 BridgeDispatcher 包成 `code: 500 / Handler execute failed` 的 BridgeResponse 回给 H5。
- H5 页面收到错误 response 时会走 Promise.reject 分支，Trace 区显示红色 `[H5] Promise reject`，Response 区显示完整错误 JSON，**页面不会崩溃**。
- H5 不能直接调用 OpenHarmony pasteboard，必须通过 ArkTS 桥接。这是 ASCF 元服务安全模型的一部分。
- 本阶段还没有使用 NAPI。NAPI 是下一阶段 ArkTS 调 C/C++ 的桥，不是 H5 直接调系统的桥。

## 8. 异步链路改造

接系统 API 之后，Imp 的方法变成 `async`。为了让 `await` 一路传上去，本阶段把 handler 链整体升级为 Promise：

- `BridgeHandler = (request) => Promise<BridgeResponse>`
- `BridgeDispatcher.dispatch(): Promise<BridgeResponse>`
- `BridgeController.handle(): Promise<void>`
- `AscfBridgeObject.send()` 保持 sync（JavaScriptProxy 方法不能声明 async），但内部 `controller.handle(rawReq).catch(...)` fire-and-forget。
- 之前的同步 handler（runtime.ping / device.getInfo 等）用 `async () => { return biz.xxx(req) }` 包一层即可继续工作。

## 9. 验收结果

记录：

- writeText 是否成功
- readText 是否成功（包括权限受限情况）
- DevEco HiLog 中 `[ASCF][ClipboardImp]` / `[ASCF][ClipboardBiz]` 是否打印
- 遇到的问题与处理方式
