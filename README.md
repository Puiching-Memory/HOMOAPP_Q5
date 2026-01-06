# HOMOAPP_Q5
HarmonyOS 环境白噪音 APP，整合 ArkTS 前端与 Docker 化后端，实现场景卡片、预设、轨道混合与专注倒计时体验。

## 项目概述
- 前端：`entry` 模块加载 [entry/src/main/ets/pages/Index.ets](entry/src/main/ets/pages/Index.ets)，展示场景卡片、音轨控制、预设模式与专注计时器。
- 后端：FastAPI 提供 `/api/v1/scenes`、`/api/v1/presets` 等接口，数据存储在 SQLite 并打包至 Docker 容器。
- 交互：前端默认请求 `http://10.0.2.2:8080/api/v1`，返回的 `audioUrl` 指向公开白噪音样本，可驱动 ArkUI 播放机制。

## 快速启动
1. 参考 [backend/README.md](backend/README.md) 运行或构建 Docker 化后端，并确认 8080 端口可达。
2. 如需定制 API 地址，修改 [entry/src/main/ets/pages/Index.ets](entry/src/main/ets/pages/Index.ets) 中的 `BASE_API_URL` 常量。
3. 使用 DevEco Studio 或 hvigor 编译部署 `entry`，即可在模拟器上体验场景列表、轨道微调、预设与倒计时。

## 架构亮点
- **前端**：Compound UI 通过 `fetch` 拉取场景/预设，维护选中场景、轨道音量与专注计时状态，支持场景切换与错误提示。
- **后端**：使用 FastAPI 异步架构，支持自动模型迁移与数据注入，API 跨域开放，提供极简的 Docker 部署。

## 目录结构
- `entry/`：ArkTS 应用，入口在 [entry/src/main/ets/pages/Index.ets](entry/src/main/ets/pages/Index.ets)。
- `backend/`：FastAPI REST API，含 Dockerfile、SQLite 数据目录与文档。
- `plan.md`：项目规划，覆盖需求分析、数据库与 API 设计。
