# Environment White Noise Backend

Go + Gin 服务，用于为 HarmonyOS 客户端提供环境场景、音轨与预设等数据。

## 核心能力
- **数据存储**：SQLite 自动迁移 `data/white_noise.db`，首次启动会注入雨夜、森林、海岸等样本场景及预设。
- **API**：RESTful 接口返回 JSON，包含场景列表、场景详情、预设与听音日志。
- **Docker**：多阶段构建镜像，直接以压缩后的二进制+数据运行，默认暴露 8080 端口。

## 本地启动
1. 安装 Go 1.22 及模块支持。
2. 在 backend 目录下运行 `go mod tidy` 生成依赖文件。
3. `GO111MODULE=on go run ./cmd/server`，或运行构建好的二进制 `./noise-backend`。
4. 支持环境变量：
   - `NOISE_BACKEND_PORT`（默认 8080）
   - `NOISE_DB_PATH`（默认 data/white_noise.db）

服务启动后会自动创建数据库目录并注入演示数据。用于开发时可直接调用 `GET /api/v1/scenes` 等。

## Docker 化部署
```sh
cd backend
docker build -t homo-noise-backend:latest .
docker run -p 8080:8080 homo-noise-backend:latest
```
如果想挂载数据卷：
```sh
docker run -p 8080:8080 -v $(pwd)/data:/app/data homo-noise-backend:latest
```

## API 快速参考
| 路径 | 方法 | 描述 |
| --- | --- | --- |
| `/api/v1/scenes` | `GET` | 返回所有场景（含封面、氛围描述）。 |
| `/api/v1/scenes/{id}` | `GET` | 返回单个场景的所有音轨信息。 |
| `/api/v1/presets` | `GET` | 返回预设模式及其轨道音量。|
| `/api/v1/listening-session` | `POST` | 接收 `{ sceneId, presetId?, durationMinutes?, notes? }` 并返回确认。|

响应格式遵循 `application/json`，跨域允许所有来源。

## 前端集成提示
- 默认客户端通过 `http://10.0.2.2:8080/api/v1` 访问服务器。请根据设备环境调整 BASE_URL。
- 返回的 `audioUrl` 指向 Pixabay CC0 样本，可直接给 ArkUI 的媒体播放器使用。
