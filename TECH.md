# TECH：首个可玩 Demo 技术规格草案

> **状态：阶段 0 决策门禁已通过；首个内部可分享浏览器 Demo 的技术基线已获 Chris 批准。** 本文不含生产代码；文档包复核通过，阶段 1 尚未开始。最终发行平台与完整浏览器／设备矩阵仍未决定。

## 引擎与精确版本

- **已确认的引擎方向：** Godot。
- **已批准的精确版本：** Godot **4.7.2-stable** 标准版（非 .NET），脚本语言为 **GDScript**，用于首个内部可分享浏览器 Demo。
- 官方归档将 4.7.2 标为 stable，发布日期为 2026-08-18；官方稳定手册当前对应 Godot 4.7。此批准限定于首个内部 Demo 技术基线。
- [Godot 官方 4.7.2-stable 下载与归档](https://godotengine.org/download/archive/4.7.2-stable/)
- [Godot 官方 4.7 稳定版文档](https://docs.godotengine.org/en/stable/)

## 渲染器、平台与导出矩阵

| 项目 | 首个内部 Demo 基线 | 状态与范围 |
| --- | --- | --- |
| 引擎与脚本 | Godot 4.7.2-stable 标准版 + GDScript | **已批准**，限定首个内部 Demo。 |
| 渲染器 | Compatibility | **已批准**；Godot Web 的 WebGL 2.0 导出使用 Compatibility。 |
| 导出目标 | Godot Web，作为可在浏览器分享的首个内部 Demo | **已批准**；这不是最终发行平台或完整浏览器支持承诺。 |
| Web 图形／运行要求 | WebAssembly + WebGL 2.0 | 浏览器必须支持；不假定 WebGL 1.0 回退。 |
| 早期移动检查 | 尽早在移动浏览器做 smoke test | 必须安排，用于提前发现性能、触控和布局风险；不是移动端发行承诺。 |
| 浏览器 E2E | Playwright | **必需测试工具**；只用于开发／测试，不随游戏打包，不是运行时依赖。 |
| 其他发行平台／浏览器矩阵 | 尚未决定 | 本次批准不承诺桌面原生版、移动原生版或最终支持的浏览器／设备清单。 |
| 项目形态 | 2D、单机、以 UI 和节点叙事为主 | **建议，待确认**；不是本次 Web 技术基线的额外已批范围。 |

Godot 官方 Web 导出文档说明，Godot 4 Web 导出需要浏览器支持 WebAssembly 和 WebGL 2.0；Godot 4 的 Web 目标只使用 Compatibility 渲染方式，Forward+ 与 Mobile 渲染器不支持 Web。官方文档还提示移动设备上的 Web 性能更受 CPU／GPU 限制，因此需尽早做移动浏览器 smoke test。Safari 存在额外 WebGL 2.0 问题；具体浏览器支持矩阵仍待决定。

- [Godot 官方渲染器概览](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Godot 官方导出指南](https://docs.godotengine.org/en/stable/tutorials/export/index.html)
- [Godot 官方 Web 导出与 WebGL 2.0 文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [Godot 官方版本导出模板归档](https://godotengine.org/download/archive/4.7.2-stable/)

## 官方文档片段

> “In Godot, a game is a tree of nodes that you group together into scenes. You can then wire these nodes so they can communicate using signals.”

来源：[Godot 4.7 官方关键概念概览](https://docs.godotengine.org/en/stable/getting_started/introduction/key_concepts_overview.html)。本项目据此把画面阶段拆成少量可复用场景，并通过明确的状态流转衔接；这是项目级组织建议，不是要求每个节点都独立做成场景。

## 场景清单（提案）

1. **DemoRoot：** 载入试玩流程、持有当前 Demo 会话的唯一状态、决定当前阶段及结束提示。
2. **Forge：** 首次锻剑与失败后的重铸，复用同一操作与反馈。
3. **DispatchBrief：** 展示唯一弟子、唯一地点、剑况和出发风险，确认派遣。
4. **ExpeditionNode：** 呈现一个历练节点和选项；按节点数据重复使用，不为每个节点复制一套交互场景。
5. **Outcome：** 说明结果、具体损失／保留内容与失败原因，并提供重铸入口。

以上是逻辑场景建议；UI 是否合并成单场景、如何切换场景由 Chris 后续确认，不预设技术架构。

## 推荐目录结构

```text
res://
  scenes/       # DemoRoot、Forge、DispatchBrief、ExpeditionNode、Outcome
  scripts/      # 流程、状态、锻造／节点结果规则、界面适配
  data/         # 地点、节点、选项和风险文案的唯一内容定义
  assets/       # 占位图、音效等项目自有资源
  ui/           # 可复用的提示、选项与状态显示组件
  tests/        # 手工验收步骤或项目内测试材料（是否自动化待定）
```

目录是建议布局；不因为列出 `tests/` 就承诺引入外部测试框架。

## 模块边界

- **流程模块：** 管理锻造、简报、节点、结算、重铸、结束的阶段顺序。
- **会话状态模块：** 维护本次试玩的剑、弟子、当前节点、选择历史、结局和 Demo 是否完成。
- **锻造规则模块：** 接收玩家操作并产出可展示的锻造状态；具体状态和规则待 GDD 锁稿。
- **历练规则／内容模块：** 按唯一节点数据展示风险与选项，接收选择并产出明示结果。
- **界面模块：** 只呈现权威状态和文案，提交玩家动作，不另行计算或保存一份游戏规则。

## 单一事实源规则

1. **一次 Demo 会话只允许一个权威会话状态。** 剑况、弟子状况、当前阶段／节点、玩家选择和结局不得在 UI 控件、节点文案或多个管理器中各存一份互相可改的数据。
2. **内容数据只定义一次。** 每个节点的选项、风险说明和结果文案集中在一份项目内数据记录中；显示层引用它，不复制粘贴另一份规则。
3. **规则结果先更新状态，再显示反馈。** 界面不得自行推算成功、损失或结局；所有结果由同一规则入口写入权威状态。
4. **重铸重置范围显式定义。** 重铸只重置 GDD 确认的试玩字段，不通过残留 UI 或隐藏状态继承上一次结果。
5. **确定性优先。** 首切片的关键损失按已展示的选择和规则产生；如采用受控失败，触发条件必须在关卡规格中清楚记录，禁止暗中加入未说明的随机判定。

## 依赖政策

- **禁止新增随游戏交付或运行时加载的第三方依赖、插件或外部 SDK。** 游戏运行时只用选定 Godot 版本自带能力和项目自有资源。
- **Playwright 是唯一已批准的测试工具例外：** 必须用于浏览器 E2E，但仅作开发／测试工具，不进入游戏包、不参与运行时；本次规格整理不安装它，也不编写测试或生产代码。
- 其他第三方工具或依赖仍须先说明用途、维护／授权风险和替代方案，再请 Chris 单独批准；不得以“顺手安装”带入。

## 仍待 Chris 决定

- 最终发行平台，以及正式支持的浏览器、操作系统与设备矩阵；当前只批准首个内部可分享浏览器 Demo。
- 浏览器 E2E 的具体浏览器版本／项目矩阵，以及早期移动浏览器 smoke test 的设备组合。
- 是否采用建议的 2D 项目形态、逻辑场景／目录结构，以及最终输入设备与目标屏幕比例。

**阶段 0 决策门禁已通过；GDD、TECH、ACCEPTANCE、README、主线与里程碑文档均已复核通过；阶段 1 尚未开始。阶段 1 未启动前不建立项目工程、不生成生产代码、不安装测试工具或依赖。**
