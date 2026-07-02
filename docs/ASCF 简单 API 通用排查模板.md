# ASCF 简单 API 通用排查模板

> 说明：本文是基于 `has.showToast` 链路抽象出来的简单 API 排查模板，后续可以用于分析存储、网络、设备、媒体等其他 API。内容只记录通用排查思路，不记录内部源码细节、内部类名、私有接口或敏感信息。

---

## 一、适用范围

这份模板适用于排查 ASCF 中“业务侧调用一个 API，底层执行一个能力”的场景，例如：

```text
UI 提示类 API
存储类 API
设备信息类 API
网络请求类 API
媒体选择类 API
基础能力类 API
```

这类 API 通常具备以下特点：

```text
业务侧通过全局 API 对象调用
逻辑层负责 API 暴露和参数传递
底层通过能力 key 找到对应模块
能力模块最终调用鸿蒙系统能力
```

通用调用链路可以理解为：

```text
业务调用
  ↓
全局 API 对象
  ↓
逻辑层 API 暴露
  ↓
requireAPI / 能力代理
  ↓
能力 key
  ↓
底层 moduleMap
  ↓
能力模块实例
  ↓
具体方法执行
  ↓
鸿蒙系统能力
  ↓
结果返回
```

---

## 二、排查步骤

## 1. 确认业务侧 API 是否存在

首先确认业务侧调用的 API 是否真的存在。

排查点：

```text
1. 全局 API 对象是否存在？
2. 目标 API 是否挂载到全局对象上？
3. API 名称是否拼写正确？
4. 当前运行环境是否支持该 API？
```

以 `has.showToast` 为例：

```text
has 是否存在？
has.showToast 是否存在？
```

如果这里就不存在，问题大概率在：

```text
逻辑层初始化
API 暴露清单
全局对象注入
API 是否被导出
```

---

## 2. 确认逻辑层是否正确暴露 API

如果业务侧 API 存在，下一步看逻辑层是否正确暴露了这个 API。

排查点：

```text
1. 该 API 是否在逻辑层对应能力模块中定义？
2. 该 API 是否被统一入口导出？
3. 该 API 是否被加入 API 暴露清单？
4. 框架初始化时是否把暴露清单挂载到了全局对象？
```

以 `has.showToast` 为例：

```text
showToast 是否在 UI 交互模块中暴露？
showToast 是否被加入 hasInterfaceList？
hasInterfaceList 是否赋值给全局 has？
```

如果这一步异常，现象通常是：

```text
has 存在，但 has.xxx 不存在
API 名称存在差异
某些 API 在当前环境不可用
```

---

## 3. 确认 API 是否通过 requireAPI 调到底层能力

简单 API 通常不是逻辑层自己完成所有能力，而是通过能力 key 调到底层。

排查点：

```text
1. API 内部是否调用 requireAPI？
2. requireAPI 传入的能力 key 是什么？
3. 能力 key 是否和底层注册 key 一致？
4. 参数是否被继续传到底层？
```

以 `has.showToast` 为例：

```text
has.showToast(params)
  ↓
requireAPI('system.prompt').showToast(params)
```

这里的关键是：

```text
能力 key = system.prompt
方法名 = showToast
参数 = { title, duration }
```

如果这一步异常，常见问题是：

```text
能力 key 写错
requireAPI 获取不到能力
逻辑层 API 和底层模块没有对上
参数没有正确透传
```

---

## 4. 确认底层 moduleMap 是否注册能力 key

逻辑层能调用到底层，前提是底层已经注册了对应能力。

排查点：

```text
1. moduleMap 是否创建成功？
2. 能力 key 是否被 set 到 moduleMap 中？
3. key 对应的 value 是什么？
4. value 是模块实例，还是模块创建函数？
5. 是否存在懒创建 / 懒加载机制？
```

以 `system.prompt` 为例：

```text
moduleMap.set('system.prompt', () => new PromptModule())
```

可以理解为：

```text
system.prompt → PromptModule 创建函数
```

如果这一步异常，常见问题是：

```text
底层能力没有注册
能力 key 不一致
模块初始化失败
模块创建函数异常
```

---

## 5. 确认底层能力模块是否能被创建 / 获取

当 API 真正执行时，底层需要根据能力 key 找到对应模块。

排查点：

```text
1. 调用时是否执行 moduleMap.get(moduleName)？
2. 是否能拿到对应模块创建函数？
3. 是否会 new 出能力模块实例？
4. 实例是否被缓存复用？
5. key 不存在时如何处理？
```

抽象链路：

```text
moduleName = system.prompt
  ↓
moduleMap.get(moduleName)
  ↓
获取 PromptModule 创建函数
  ↓
创建 / 获取 PromptModule 实例
```

如果这一步异常，常见问题是：

```text
moduleMap 中没有对应 key
创建模块实例失败
实例生命周期异常
模块被销毁或未初始化
```

---

## 6. 确认目标方法是否被正确声明和暴露

底层模块存在后，还要确认模块中是否有对应方法。

排查点：

```text
1. 能力模块里是否有目标方法？
2. 方法是否通过元信息声明可被 JS 调用？
3. 方法 alias 是否和逻辑层调用方法名一致？
4. 是否声明 callback？
5. 参数规则是否正确？
```

以 `showToast` 为例，底层方法会声明类似信息：

```text
alias: showToast
callback: true
params:
  - title: 必填，字符串
  - duration: 可选，数字，有默认值
```

如果这一步异常，常见问题是：

```text
方法名不一致
alias 不一致
方法没有被暴露
参数声明不正确
callback 行为不符合预期
```

---

## 7. 确认参数是否符合要求

很多 API 问题不是链路断了，而是参数不符合底层规则。

排查点：

```text
1. 必填参数是否传入？
2. 参数类型是否正确？
3. 可选参数是否有默认值？
4. 参数是否在逻辑层被修改？
5. 参数是否在桥接过程中丢失？
6. 底层是否做了参数校验？
```

以 `has.showToast` 为例：

```text
title 是否存在？
title 是否为字符串？
duration 是否为数字？
duration 不传时是否有默认值？
```

如果这一步异常，常见问题是：

```text
参数缺失
参数类型错误
默认值不符合预期
参数字段名和底层声明不一致
```

---

## 8. 确认底层是否真正调用系统能力

能力模块方法执行后，最后要确认是否真正调用了鸿蒙系统能力。

排查点：

```text
1. 底层方法内部调用了哪个系统能力？
2. 参数是否转换成系统能力需要的格式？
3. 系统能力是否需要 UIContext / AbilityContext？
4. 当前线程 / 生命周期状态是否允许调用？
5. 系统能力是否抛出异常？
```

以 `has.showToast` 为例：

```text
PromptModule.showToast(option)
  ↓
读取 title / duration
  ↓
组装 toastOption
  ↓
调用 ArkUI PromptAction
  ↓
展示 Toast
```

如果这一步异常，常见问题是：

```text
系统能力调用失败
上下文不正确
生命周期不合适
权限或环境不满足
参数转换错误
```

---

## 9. 确认 Promise / 回调是否正常返回

很多 API 即使底层执行成功，也可能因为回调链路异常导致业务侧无感知。

排查点：

```text
1. 底层方法是否返回 Promise？
2. 成功时是否 resolve？
3. 失败时是否 reject？
4. callback: true 是否参与回调封装？
5. success / fail / complete 是否按预期触发？
6. 桥接层是否正确返回执行结果？
```

以 `showToast` 为例：

```text
PromptModule.showToast
  ↓
Promise resolve / reject
  ↓
桥接层封装结果
  ↓
逻辑层接收结果
  ↓
业务侧感知调用完成
```

如果这一步异常，常见问题是：

```text
Promise 没有 resolve / reject
异常没有被捕获
回调 ID 丢失
桥接返回格式不一致
success / fail / complete 没触发
```

---

## 三、通用排查清单

以后排查一个简单 API，可以直接按下面清单走。

```text
1. 全局 API 对象是否存在？
2. 目标 API 是否挂载到全局对象上？
3. API 名称是否拼写正确？
4. 逻辑层是否暴露该 API？
5. 该 API 是否被加入暴露清单？
6. API 内部是否通过 requireAPI 调到底层？
7. 能力 key 是什么？
8. 能力 key 是否和底层注册 key 一致？
9. 底层 moduleMap 是否注册该 key？
10. moduleMap.get 是否能获取模块创建函数？
11. 能力模块是否能被创建 / 获取？
12. 能力模块中是否有目标方法？
13. 方法 alias 是否和调用名一致？
14. 参数声明是否正确？
15. 必填参数是否传入？
16. 参数类型是否正确？
17. 参数是否成功传到底层？
18. 底层是否调用了系统能力？
19. 系统能力调用是否成功？
20. Promise / 回调是否正常返回？
```

---

## 四、按问题现象快速定位

| 问题现象 | 优先排查方向 |
|---|---|
| `has` 不存在 | 逻辑层初始化、全局对象注入 |
| `has.xxx` 不存在 | API 暴露清单、统一导出入口 |
| API 调用后无反应 | requireAPI、能力 key、桥接链路 |
| 提示 key 不存在 | 底层 moduleMap 注册 |
| 方法找不到 | 能力模块方法声明、alias 映射 |
| 参数报错 | 参数声明、必填参数、类型校验 |
| 底层没有执行 | moduleMap.get、模块实例创建、方法分发 |
| 系统能力没效果 | ArkUI / 系统 API 调用、上下文、生命周期 |
| 没有回调 | Promise、callback、桥接返回链路 |
| 偶发失败 | 生命周期、异步时序、上下文失效、实例缓存 |

---

## 五、套用示例：has.showToast

以 `has.showToast` 为例，完整排查链路如下：

```text
1. has 是否存在？
2. has.showToast 是否存在？
3. showToast 是否被逻辑层 UI 交互模块暴露？
4. showToast 是否被加入 hasInterfaceList？
5. showToast 是否通过 requireAPI('system.prompt') 调用？
6. system.prompt 是否在底层 moduleMap 中注册？
7. system.prompt 是否对应 PromptModule？
8. PromptModule 是否能创建实例？
9. PromptModule 是否有 showToast 方法？
10. showToast 的 alias 是否正确？
11. title 是否必填并正确传入？
12. duration 是否可选并有默认值？
13. showToast 是否组装 toastOption？
14. 是否调用 ArkUI PromptAction？
15. Promise / 回调是否正常返回？
```

对应链路：

```text
has.showToast({ title, duration })
  ↓
requireAPI('system.prompt').showToast(params)
  ↓
system.prompt
  ↓
moduleMap
  ↓
PromptModule
  ↓
showToast
  ↓
ArkUI PromptAction
```

---

## 六、后续使用方式

后续分析其他 API 时，可以复制下面模板填写。

```md
## API 名称

### 1. 业务侧调用方式

```js
// 示例调用
```

### 2. 逻辑层暴露情况

```text
全局对象：
API 名称：
所属模块：
是否加入暴露清单：
```

### 3. requireAPI / 能力 key

```text
requireAPI 参数：
能力 key：
方法名：
参数：
```

### 4. 底层 moduleMap 注册情况

```text
moduleMap key：
value：
是否懒创建：
对应能力模块：
```

### 5. 底层方法声明

```text
alias：
callback：
params：
返回值：
```

### 6. 系统能力调用

```text
底层模块：
目标方法：
调用的系统能力：
上下文要求：
```

### 7. 回调 / 返回

```text
是否 Promise：
success：
fail：
complete：
异常处理：
```

### 8. 问题排查结论

```text
问题现象：
断点位置：
失败层级：
原因判断：
解决方向：
```
```

---

## 七、当前总结

简单 API 的排查关键不是直接看某个函数，而是顺着这条链路逐层确认：

```text
全局 API
  ↓
逻辑层暴露
  ↓
requireAPI
  ↓
能力 key
  ↓
moduleMap
  ↓
能力模块
  ↓
方法声明
  ↓
参数校验
  ↓
系统能力
  ↓
Promise / 回调
```

只要能判断问题断在哪一层，就能避免一上来直接在源码里乱搜。
