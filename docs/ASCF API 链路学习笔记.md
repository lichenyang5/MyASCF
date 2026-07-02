# ASCF API 链路学习笔记

> 说明：本文是 ASCF Runtime 源码学习过程中的链路笔记，主要用于个人理解和后续持续更新。内容只记录抽象流程、模块职责和排查思路，不记录内部源码实现细节、内部类名、私有接口、客户信息或敏感配置。

---

## 目录

- [一、当前学习目标](#一当前学习目标)
- [二、has.showToast 完整链路](#二hasshowtoast-完整链路)
- [三、system.prompt 注册、查找与执行链路](#三systemprompt-注册查找与执行链路)
- [四、当前未完全确认的问题](#四当前未完全确认的问题)
- [五、简单 API 通用排查模板](#五简单-api-通用排查模板)
- [六、后续更新计划](#六后续更新计划)

---

## 一、当前学习目标

当前阶段不是泛泛地看所有 API，也不是逐个对照 API 文档，而是先选取一个简单 API，打通一条完整链路。

本阶段选择的 API 是：

```js
has.showToast({
  title: '保存成功',
  duration: 1500
})
```

选择原因：

1. 功能简单。
2. 参数少。
3. 结果可见。
4. 适合作为理解 ASCF API 调用链路的第一个切入点。

核心目标是搞清楚：

```text
开发者为什么可以直接调用 has.showToast？
has.showToast 如何映射到底层能力？
system.prompt 如何注册到能力 Map？
PromptModule 如何执行真实弹窗能力？
```

---

## 二、has.showToast 完整链路

### 1. 业务侧调用

业务侧调用方式：

```js
has.showToast({
  title: '保存成功',
  duration: 1500
})
```

目前观察到，业务侧不需要手动 `import has`，而是可以直接使用全局 `has` 对象。

因此可以先理解为：

```text
逻辑层初始化
  ↓
收集可用 API
  ↓
生成 API 暴露清单
  ↓
挂载到全局 has 对象
  ↓
开发者可以直接调用 has.showToast
```

也就是说，`has` 更像是 ASCF 逻辑层初始化时注入到 JavaScript 全局环境中的 API 命名空间。

---

### 2. 逻辑层暴露链路

`has.showToast` 不是孤立存在的函数，而是通过逻辑层的一套 API 暴露机制挂载到全局 `has` 对象上。

当前理解的链路如下：

```text
逻辑层 UI 交互模块
  ↓
通过 requireAPI 获取 system.prompt 能力
  ↓
暴露 showToast / hideLoading 等方法
  ↓
统一 API 入口收集 showToast
  ↓
加入 hasInterfaceList
  ↓
框架初始化时将 hasInterfaceList 赋值给全局 has
  ↓
开发者调用 has.showToast
```

其中关键点是：

```text
requireAPI('system.prompt')
```

它可以理解为逻辑层连接底层能力的一个中转站。逻辑层不直接关心底层如何实现 Toast，而是通过 `system.prompt` 这个能力标识，拿到底层对应的能力代理。

因此，`has.showToast` 在逻辑层中大致可以理解为：

```text
has.showToast(params)
  ↓
requireAPI('system.prompt').showToast(params)
```

这里的 `params` 主要包含：

```js
{
  title: '提示内容',
  duration: 1500
}
```

---

### 3. 底层能力执行链路

底层核心层会注册一个 Prompt 能力模块，并将其和 `system.prompt` 这个 key 建立映射关系。

完整链路可以理解为：

```text
业务代码
has.showToast({ title, duration })
  ↓
全局 has 对象
  ↓
逻辑层 showToast API
  ↓
requireAPI('system.prompt').showToast(params)
  ↓
桥接 / 能力代理
  ↓
底层模块映射表查找 system.prompt
  ↓
找到 PromptModule
  ↓
执行 PromptModule.showToast(option)
  ↓
读取 title 和 duration
  ↓
组装 toastOption
  ↓
调用 ArkUI PromptAction
  ↓
展示 Toast
```

这条链路可以拆成两部分：

```text
上半链路：逻辑层负责暴露 API
下半链路：底层核心层负责注册和执行真实能力
```

一句话总结：

> `has.showToast` 是逻辑层暴露给业务侧的 UI 提示 API，底层通过 `system.prompt` 找到 Prompt 能力模块，再由 Prompt 模块调用鸿蒙 ArkUI 的 Toast 能力完成展示。

---

## 三、system.prompt 注册、查找与执行链路

在 `has.showToast` 链路中，`system.prompt` 是逻辑层和底层核心层之间对齐能力的关键标识。

### 1. 注册过程

底层核心层会在 API 初始化阶段创建模块映射表，并集中注册各类底层能力模块。

当前观察到的抽象逻辑可以理解为：

```text
API 初始化
  ↓
创建 moduleMap
  ↓
注册 system.prompt
  ↓
value 指向 PromptModule 创建函数
```

可以抽象成：

```text
system.prompt → PromptModule 创建函数
```

也可以理解成：

```text
moduleMap.set('system.prompt', () => new PromptModule())
```

这里的 value 不是已经创建好的实例，而是一个用于创建 PromptModule 的函数。

这样做的好处是：

```text
注册阶段：只保存模块创建函数
调用阶段：真正需要时再创建 / 获取模块实例
```

因此，这里至少体现了能力实例的懒创建机制。

---

### 2. 核心层向逻辑层同步可用模块

底层 API 初始化能力会通过核心模块统一导出，并在主页面或运行时入口中被使用。

当前理解的链路如下：

```text
底层 API 初始化
  ↓
生成 modules / moduleMap
  ↓
通过核心模块统一导出
  ↓
主入口导入并拿到 modules
  ↓
通过 JS 服务桥接执行 initModules(modules)
  ↓
将可用模块信息注入逻辑层
```

逻辑层接收到模块信息后，会在 API 注册阶段记录这些模块。

链路可以理解为：

```text
逻辑层 API 注册
  ↓
遍历核心层传入的 modules
  ↓
requireAPI().initModule(moduleName)
  ↓
将 moduleName 加入 initModules 集合
  ↓
逻辑层知道 system.prompt 这个模块可用
```

因此，`system.prompt` 的注册可以分为两步：

```text
底层核心层注册真实能力模块
  ↓
逻辑层初始化时记录该模块可用
```

---

### 3. 查找过程

当前还没有完全确认 `requireAPI` 的具体封装位置，但可以先按能力代理入口理解。

当前推断链路如下：

```text
requireAPI('system.prompt')
  ↓
检查 system.prompt 是否为已初始化 / 可用模块
  ↓
返回 system.prompt 对应的能力代理
  ↓
开发者侧调用 showToast(params)
```

更完整地说，`requireAPI('system.prompt')` 很可能不是直接等于底层模块实例，而是一个逻辑层到核心层之间的能力代理。

它负责把逻辑层调用转换成底层能识别的模块能力调用。

可以理解为：

```text
逻辑层：
requireAPI('system.prompt').showToast(params)

桥接请求：
module = system.prompt
method = showToast
params = { title, duration }

核心层：
moduleMap.get('system.prompt')
  ↓
获取 PromptModule 创建函数
  ↓
创建 / 获取 PromptModule 实例
  ↓
执行 PromptModule.showToast(params)
```

---

### 4. 执行过程

当底层根据 `system.prompt` 找到 PromptModule 后，会根据方法名继续定位具体能力方法。

当前观察到，PromptModule 中的 `showToast` 是一个被框架声明过的底层能力方法。

它会声明：

```text
alias: showToast
callback: true
params:
  - title: 必填，字符串
  - duration: 可选，数字，有默认值
```

可以理解为：

```text
底层能力类
  ↓
通过方法元信息声明可被 JS 调用的方法
  ↓
声明方法别名、是否支持回调、参数规则
  ↓
方法内部执行鸿蒙侧 Toast 能力
  ↓
通过 Promise 返回执行结果
```

执行链路如下：

```text
PromptModule.showToast(option)
  ↓
读取 option.title
  ↓
读取 option.duration
  ↓
组装 toastOption
  ↓
调用 ArkUI PromptAction
  ↓
展示 Toast
```

因此，ASCF 自己并不是重新画了一个 Toast，而是把业务侧传入的参数转换成 ArkUI Prompt 能力需要的参数，最终交给鸿蒙 ArkUI 能力完成展示。

---

### 5. 当前完整链路

```text
业务代码
has.showToast({ title, duration })
  ↓
全局 has 对象
  ↓
逻辑层 showToast API
  ↓
requireAPI('system.prompt').showToast(params)
  ↓
逻辑层通过能力代理发起调用
  ↓
核心层根据 system.prompt 查找 moduleMap
  ↓
moduleMap.get('system.prompt')
  ↓
获取 PromptModule 创建函数
  ↓
创建 / 获取 PromptModule 实例
  ↓
根据 showToast 找到具体方法
  ↓
校验 / 处理 title、duration
  ↓
PromptModule.showToast(option)
  ↓
调用 ArkUI PromptAction
  ↓
展示 Toast
```

---

## 四、当前未完全确认的问题

当前已经确认大部分主链路，但还有一些细节后续需要继续补充。

### 1. requireAPI 的具体封装位置

目前已经确认：

```text
逻辑层通过 requireAPI('system.prompt') 获取能力代理
```

但 `requireAPI` 的具体封装位置还没有完全找到。

当前暂时理解为：

> `requireAPI` 是逻辑层获取底层能力代理的关键入口，负责把逻辑层的 API 调用转换成底层可以识别的模块能力调用。

后续需要继续确认：

```text
1. requireAPI 是在哪里定义的？
2. requireAPI 是否会先检查 initModules？
3. requireAPI 返回的是普通对象、代理对象，还是桥接封装函数？
4. requireAPI 调用方法时，桥接请求格式具体是什么？
```

---

### 2. moduleMap.get 的具体调用位置

当前已经确认：

```text
moduleMap.set('system.prompt', () => new PromptModule())
```

但还需要继续确认：

```text
真正执行 showToast 时，底层在哪个位置执行 moduleMap.get('system.prompt')？
```

目前推断：

```text
逻辑层通过能力代理发起请求
  ↓
核心层接收请求
  ↓
读取 moduleName = system.prompt
  ↓
moduleMap.get(moduleName)
  ↓
执行 PromptModule.showToast
```

这个位置后续需要继续查找。

---

### 3. JsMethod 元信息如何参与方法分发

当前已经看到底层方法会通过元信息声明：

```text
alias
callback
params
```

但还需要继续确认：

```text
1. alias 是在哪里被读取的？
2. callback: true 如何影响回调处理？
3. params 参数规则是在哪里统一校验的？
4. Promise resolve / reject 如何转换成逻辑层回调？
```

这部分可能涉及底层 API 分发框架，需要后续单独分析。

---

## 五、简单 API 通用排查模板

通过 `has.showToast` 可以初步总结出简单 API 的通用排查模板。

如果遇到某个简单 API 不生效，可以按下面顺序查：

```text
1. 全局 API 对象是否存在？
2. 目标 API 是否挂载到全局对象上？
3. 逻辑层是否正确暴露该 API？
4. 该 API 是否通过 requireAPI 调到底层能力？
5. 能力 key 是什么？
6. 底层 moduleMap 是否注册了这个 key？
7. key 对应的能力模块是否可以创建 / 获取？
8. 能力模块中是否声明了目标方法？
9. 方法参数是否符合声明规则？
10. 方法内部是否调用了对应系统能力？
11. Promise / 回调是否正常返回？
12. 如果失败，错误发生在逻辑层、桥接层、底层模块，还是系统能力层？
```

对应到 `has.showToast`：

```text
1. has 是否存在？
2. has.showToast 是否存在？
3. showToast 是否被加入 hasInterfaceList？
4. showToast 是否调用 requireAPI('system.prompt')？
5. system.prompt 是否在 moduleMap 中注册？
6. PromptModule 是否能被创建？
7. PromptModule 是否有 showToast 方法？
8. title 是否存在且类型正确？
9. duration 是否可选并有默认值？
10. ArkUI PromptAction 是否真正执行？
```

---

## 六、后续更新计划

后续这份笔记会继续补充以下内容：

```text
1. 找到 requireAPI 的具体定义和封装逻辑。
2. 找到 moduleMap.get('system.prompt') 的真实执行位置。
3. 分析 JsMethod 元信息如何参与方法分发、参数校验和回调处理。
4. 继续选择一个 storage 或 network 类 API，验证这套“全局 API → 能力 key → moduleMap → 能力模块 → 系统能力”的模式是否通用。
5. 最终沉淀一份 ASCF API 注册与分发机制总结。
```

当前阶段先记住这条主线：

```text
全局 API
  ↓
逻辑层 API 暴露
  ↓
能力 key
  ↓
底层 moduleMap
  ↓
能力模块实例
  ↓
具体系统能力
```

对应到 `has.showToast`：

```text
has.showToast
  ↓
requireAPI('system.prompt').showToast
  ↓
system.prompt
  ↓
PromptModule
  ↓
ArkUI PromptAction
```
