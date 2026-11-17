# 项目进度

## 阶段 1：技术脚手架

**状态：阶段 1 技术验收通过（仅脚手架，不是可玩 Demo）。** 阶段 1 只做技术验收，不要求 Chris 试玩空白场景。首个可玩版本须等核心循环完成后，再交 Chris 体验验收。

工程根目录为本仓库根目录。阶段 1 脚手架包含空白 `Node2D` 主场景、Godot Web 导出预设和 TECH 推荐目录占位；当时未加入玩法代码、正式 UI、游戏素材、外部运行时依赖、插件或 SDK，也未安装 Playwright。阶段 1 的构建输出目录 `build/` 从 Web 资源包排除；验证截图及日志保存在项目树之外。

### 阶段 1 技术验收证据

| 检查 | 结果 |
| --- | --- |
| Godot 版本 | `4.7.2.stable.official.ed1daf0bf`，符合批准版本 |
| 项目导入 | Headless Editor 导入成功，无错误 |
| 空主场景启动 | Headless 启动空白 `Node2D` 主场景并正常运行后退出，无错误 |
| Web 导出 | Debug 导出成功；生成 `index.html`、`index.js`、`index.pck`、`index.wasm`；PCK 为 1,592 bytes，确认不含 build 输出或证据文件 |
| Chromium 加载 | Chrome 151.0.7922.34（headless）；页面加载完成，WebAssembly 与 WebGL 2.0 可用，并创建一个画布 |
| 浏览器 console | Console errors 0、未捕获异常 0、资源加载失败 0 |

Chromium 在此云端 headless 环境自动使用 SwiftShader 软件 WebGL；此结果不代表真实 GPU 性能，也不定义浏览器支持矩阵。Playwright E2E 仍由 QA 后续单独验收。阶段 1 原始验证材料保存在仓库外的 `../game-design-wiki-stage1-evidence/`；阶段 2 材料另存于 `../game-design-wiki-evidence/`。

阶段 1 只验收技术脚手架证据；不代表玩法功能、核心循环或首个可玩版本已完成。首个可玩版本须按 [`ACCEPTANCE.md`](ACCEPTANCE.md) 的 AC-01 至 AC-07 完成后交 Chris 验收；已批准的玩法边界保持不变。

阶段 1 脚手架源文件和进度文档已分别提交到 `main`（`3a8e6c1`、`a780090`）；`build/`、`.godot/` 与证据文件未纳入提交。

## 阶段 2：核心循环

### 已确认方向与首轮原型方案

- **已确认方向：** 阶段 2 首个单维度采用“单次落锤时机＋即时反馈”。
- **首轮原型方案：** 玩家先看到时机窗口，主动落锤一次，按确定规则立即得到“偏早／命中／偏晚”反馈，并可明确重试；T2-01 只覆盖这段锻造交互，不代表完整 AC-01 或完整核心循环。
- **待验证假设：** 时长、命中窗口位置与宽度均是临时测试参数，不是已批准的最终平衡值；不设剑属性映射或历练效果。

### T2-01 当前进展

本地工作副本已实现可见时机轨道、每轮一次主动落锤、确定性即时反馈和手动重试。未加入剑属性、历练结果或其他系统；代码尚未提交、推送或发布。

Godot `4.7.2.stable.official.ed1daf0bf` Headless Editor 导入、主场景运行和 Web Debug 导出均退出码 0；Chromium `151.0.7922.34`（headless，1280×800）成功启动 Godot WebGL 2.0。DevTools Protocol 监听 `Runtime`、`Log` 与 `Network` 事件；console errors、未捕获异常和资源加载失败均为 0。

最终构建上的实际操作结果：在 `3.531 s` 落锤为“命中”；点击“再试一次”后，在 `1.405 s` 落锤为“偏早”；在 `4.195 s` 落锤为“偏晚”；未操作至 `6.000 s` 自动显示“偏晚”。初始界面及结果截图、Godot 日志、Chromium console JSON 与自测摘要保存在本地工作区仓库外的 `/workspace/game-design-wiki-evidence/`；原始证据未纳入本轮文档同步，结果摘要已记载于本文件。

**仅用于本次测试的集中临时参数：** 总时长 `6.0 s`，命中窗口为 `40%–60%`，即 `2.4–3.6 s`（含边界）；窗口前为“偏早”，窗口内为“命中”，窗口后或超时未操作为“偏晚”。这些是可调测试假设，不是最终平衡值或设计定案，集中定义在 `scripts/forge_trial.gd`。

### 字体资源例外与导出体积

Chris 于 2026-11-17 12:59（香港时间）批准仅为 T2-01 当前 UI 加入必要的最小中文字体子集。Godot 官方字体文档指出 `SystemFont` 并不适用于 Web 导出，故以随包字体字形保证 Chromium 中的中文可读性；参见 [Godot 字体使用文档](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html) 与 [SystemFont 类文档](https://docs.godotengine.org/en/4.5/classes/class_systemfont.html)。

字体取自 Debian `fonts-noto-cjk` `1:20230817+repack1-3` 的 Noto Sans CJK SC Regular（TTC face 2），上游为 [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk)，按 SIL OFL 1.1 修改并分发；内部字体名改为 `T2-01 UI CJK Subset`。当前 UI 所需的 148 个字符均有字形。来源、版权和完整许可文本位于本地工作副本的 `assets/fonts/LICENSE-Noto-CJK-OFL-1.1.txt`，不在本轮文档同步范围内；该例外只适用于本任务，不扩展到其他 UI、任务、正式美术或运行时依赖。

| 体积检查 | 结果 |
| --- | ---: |
| 字体 WOFF2 子集 | 25,128 B |
| OFL 许可文件 | 4,830 B；已确认随 Web PCK 打包 |
| 加字体前基线 PCK | 10,204 B |
| 最终 Web PCK | 41,492 B |
| PCK 净增 | 31,288 B（含字体、许可文本和资源索引开销） |

### 工作区状态与下一检查点

`git diff --check` 通过。原型代码与字体资源保持未提交、未推送或发布；本轮仅同步项目文档。工作区改动涉及 `PROGRESS.md`、`ACCEPTANCE.md`、`docs/task-cards/T2-01-single-strike-forging.md`、`export_presets.cfg`、`scenes/main.tscn`、`scripts/forge_trial.gd` 及其 `.uid`、`assets/fonts/` 中的 WOFF2 子集、Godot 导入设置和 OFL 许可文件。文档同步不包含代码、字体二进制、许可文件、导出目录 `build/`、导入缓存 `.godot/` 或仓库外原始证据。

原 ETA `2026-11-16 23:30`（香港时间）已逾期；收到字体许可后更新的 ETA 为 `2026-11-17 15:30`，本次本地自测和最终复验已于 `2026-11-17 13:15` 提前完成。当前技术阻塞：无。按任务卡的下一检查点为主策评审；T2-01 仅表示单次锻造本地原型自测完成，不代表完整 AC-01、完整核心循环或 Chris 对首个可玩版本的验收。Playwright E2E 未运行，仍由 QA 后续单独验证。
