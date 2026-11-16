# 项目进度

## 阶段 1：技术脚手架

**状态：技术脚手架与对应验证已完成；这不是可玩 Demo。** 阶段 1 只做技术验收，不要求 Chris 试玩空白场景。首个可玩版本须等核心循环完成后，再交 Chris 体验验收。

工程根目录为本仓库根目录。当前脚手架包含空白 `Node2D` 主场景、Godot Web 导出预设和 TECH 推荐目录占位；保留 Godot 默认窗口适配、比例及输入设置。未加入玩法代码、正式 UI、游戏素材、外部运行时依赖、插件或 SDK，也未安装 Playwright。构建输出目录 `build/` 从 Web 资源包排除；验证截图及日志保存在项目树之外，不会进入游戏包。

## 阶段 1 技术验收证据

| 检查 | 结果 |
| --- | --- |
| Godot 版本 | `4.7.2.stable.official.ed1daf0bf`，符合批准版本 |
| 项目导入 | Headless Editor 导入成功，无错误 |
| 空主场景启动 | Headless 启动空白 `Node2D` 主场景并正常运行后退出，无错误 |
| Web 导出 | Debug 导出成功；生成 `index.html`、`index.js`、`index.pck`、`index.wasm`；PCK 为 1,592 bytes，确认不含 build 输出或证据文件 |
| Chromium 加载 | Chrome 151.0.7922.34（headless）；页面加载完成，WebAssembly 与 WebGL 2.0 可用，并创建一个画布 |
| 浏览器 console | Console errors 0、未捕获异常 0、资源加载失败 0 |

Chromium 在此云端 headless 环境自动使用 SwiftShader 软件 WebGL；本次只验证空白场景启动及 WebAssembly／WebGL 2.0 能力，不代表真实 GPU 性能，也不定义浏览器支持矩阵。Playwright E2E 仍由 QA 后续单独验收。

原始验证材料保存在当前工作区仓库外的 `../game-design-wiki-stage1-evidence/`，未包含在本次文档同步中：`godot-build.txt`、`browser-console.txt` 和 `main-scene.png`。Web 导出文件在被 `.gitignore` 排除的 `build/web/`，Godot 导入缓存位于被排除的 `.godot/`。

## 验收边界与下次检查点

阶段 1 只验收上述技术脚手架证据；不代表玩法功能、核心循环或首个可玩版本已完成。首个可玩版本须按 [`ACCEPTANCE.md`](ACCEPTANCE.md) 的 AC-01 至 AC-07 完成后交 Chris 验收；已批准的玩法边界保持不变。

本次文档同步不包含本地 Godot 脚手架源文件或构建产物，也不授权超出已批准范围的生产代码改动。
