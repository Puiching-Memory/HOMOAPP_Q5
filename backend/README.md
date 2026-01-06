# Environment White Noise Backend

Go + Gin 服务，为 HarmonyOS 客户端提供音频文件列表和静态文件服务。

## 核心能力
- **音频文件服务**：自动扫描 `data/` 目录，列出所有音频文件
- **静态文件访问**：通过 `/data/*` 路径提供音频流
- **Docker**：多阶段构建镜像，默认暴露 8080 端口

## 本地启动
```sh
cd backend
go mod tidy
go run ./cmd/server
```

或使用 Docker：
```sh
docker build -t homo-noise-backend:latest .
docker run -p 8080:8080 --rm homo-noise-backend:latest
```

## API 参考

| 路径 | 方法 | 描述 |
| --- | --- | --- |
| `/api/v1/audio` | GET | 返回音频文件列表 |
| `/data/*` | GET | 音频文件流（MP3） |

### `/api/v1/audio` 响应示例
```json
[
  {"id":1,"name":"light_rain","filename":"light_rain.mp3","url":"/data/light_rain.mp3"},
  {"id":2,"name":"ocean_waves","filename":"ocean_waves.mp3","url":"/data/ocean_waves.mp3"}
]
```

## 添加新音频
将 MP3/WAV/OGG 文件放入 `backend/data/` 目录即可自动加载。
