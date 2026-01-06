## 环境白噪音 APP 项目规划（plan）

### 1. 项目概述

- **项目名称**：环境白噪音专注 APP
- **应用场景**：学习、工作、睡眠时提供环境白噪音，帮助专注与放松。
- **整体架构**：
  - 前端：HarmonyOS/ArkTS 应用（本项目 `HOMOAPP_Q5`），通过 HTTP 访问后端。
  - 后端：FastAPI (Python) 编写的异步 REST API 服务。
  - 数据库：SQLite 存储场景、音轨、预设等数据。
  - 部署：后端打包为 Docker 镜像，前端通过配置好的 BASE_URL 调用。

### 2. 需求分析

#### 2.1 核心功能（必做）

- **环境场景管理**
  - 展示环境场景列表：雨天、咖啡厅、海边、森林等。
  - 每个场景包含：名称、描述、封面图、多个音轨。
- **场景详情与多音轨混音**
  - 进入场景详情页，展示该场景的多个音轨（如小雨、雷声、风声）。
  - 支持单独控制每条音轨的开关与音量，多个音轨可同时播放（混音）。
- **预设模式**
  - 提供若干预设模式：学习模式、睡眠模式、放松模式等。
  - 一键应用预设：自动加载对应的场景/音轨及默认音量组合。
- **专注/睡眠计时**
  - 设置专注时长（如 15/25/45 分钟或自定义）。
  - 倒计时结束自动停止所有音频播放。

#### 2.2 扩展功能（选做/加分）

- **使用统计**：记录每日使用时长、常用场景，做简单统计页面。
- **自定义场景**：允许用户选取若干音轨保存为“我的场景”。
- **主题适配**：支持浅色/深色主题，与 HarmonyOS 资源适配机制结合。

### 3. 系统架构设计

#### 3.1 前后端分离

- **前端（HarmonyOS/ArkTS）**
  - 使用声明式 UI 编写页面：首页、场景详情页、计时页、统计/设置页等。
  - 通过 HTTP 调用后端 REST API，获取场景、音轨、预设配置。
  - 使用前端音频播放能力，播放后端返回的音频 URL（本地或远程）。

- **后端（FastAPI + SQLAlchemy + SQLite）**
  - Web 框架：`FastAPI`。
  - ORM：`SQLAlchemy` + `SQLite` 驱动。
  - 对外提供 JSON 格式的 REST 接口，负责数据增删改查。
  - 使用 Docker 镜像部署，暴露 8080 端口对前端服务。

#### 3.2 模块划分

- **前端模块**
  - 场景列表模块
  - 场景详情与混音控制模块
  - 专注/睡眠计时模块
  - 预设模式模块
  - 设置/统计模块（可选）

- **后端模块**
  - 数据访问层（SQLite）
  - 场景/音轨管理接口
  - 预设管理接口
  - （可选）用户数据接口：收藏、自定义场景、使用记录

### 4. 数据库设计（SQLite）

#### 4.1 表结构

- **表：scenes（场景表）**
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `name` TEXT NOT NULL
  - `description` TEXT
  - `cover_url` TEXT

- **表：tracks（音轨表）**
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `scene_id` INTEGER NOT NULL  — 外键，关联 scenes.id
  - `name` TEXT NOT NULL
  - `audio_url` TEXT NOT NULL
  - `default_volume` REAL NOT NULL DEFAULT 0.7

- **表：presets（预设模式表）**
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `name` TEXT NOT NULL

- **表：preset_tracks（预设包含音轨）**
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `preset_id` INTEGER NOT NULL — 外键，关联 presets.id
  - `track_id` INTEGER NOT NULL — 外键，关联 tracks.id
  - `volume` REAL NOT NULL DEFAULT 0.7

> 说明：上述表结构支持“多场景、多音轨、多预设”的扩展，后续如需增加用户维度，可以新增用户表和关联表。

### 5. 后端 REST API 设计

#### 5.1 基础约定

- **基础路径**：`/api/v1`
- **数据格式**：请求与响应均使用 `application/json`。
- **示例错误格式**：
  - `{ "error": "错误描述" }`

#### 5.2 接口列表（核心）

- **获取场景列表**
  - 方法：`GET /api/v1/scenes`
  - 请求参数：无
  - 响应示例：
    ```json
    [
      {
        "id": 1,
        "name": "雨天",
        "description": "适合学习和睡眠的雨声",
        "coverUrl": "https://example.com/covers/rain.png"
      }
    ]
    ```

- **获取场景详情（含音轨）**
  - 方法：`GET /api/v1/scenes/{id}`
  - 响应示例：
    ```json
    {
      "id": 1,
      "name": "雨天",
      "description": "适合学习和睡眠的雨声",
      "coverUrl": "https://example.com/covers/rain.png",
      "tracks": [
        {
          "id": 11,
          "sceneId": 1,
          "name": "小雨",
          "audioUrl": "https://example.com/audios/light_rain.mp3",
          "defaultVolume": 0.7
        }
      ]
    }
    ```

- **获取预设模式列表**
  - 方法：`GET /api/v1/presets`
  - 响应示例：
    ```json
    [
      {
        "id": 1,
        "name": "学习模式"
      },
      {
        "id": 2,
        "name": "睡眠模式"
      }
    ]
    ```

> 如需管理数据（后台管理），可另外设计 `POST/PUT/DELETE` 接口用于增删改。

### 6. 开发步骤与里程碑

#### 阶段一：后端原型搭建

1. 初始化 Go 模块与项目结构。
2. 集成 Gin + GORM + SQLite，完成数据库连接与自动迁移。
3. 实现基础模型（Scene、Track、Preset、PresetTrack）。
4. 实现核心查询接口：`GET /scenes` 与 `GET /scenes/{id}`。
5. 手动插入几条测试数据，使用 Postman/curl 验证接口返回 JSON 正常。

#### 阶段二：Docker 化后端

1. 编写多阶段构建的 `Dockerfile`。
2. 构建镜像并本地运行容器，映射 8080 端口和数据卷。
3. 确认容器内服务可正常访问，SQLite 数据持久化正常。

#### 阶段三：前端页面与接口联调

1. 设计并实现首页 UI：场景列表展示与点击跳转。
2. 在前端配置后端 `BASE_URL`，调用 `GET /scenes` 渲染列表。
3. 实现场景详情页，调用 `GET /scenes/{id}` 获取音轨并显示。
4. 集成音频播放能力，实现多音轨播放与音量控制。

#### 阶段四：预设模式与计时功能

1. 前端增加预设模式入口，调用 `GET /presets` 展示列表。
2. 根据选中的预设加载对应场景/音轨组合并开始播放。
3. 实现专注/睡眠计时器，倒计时结束自动暂停所有音频。

#### 阶段五：优化与扩展（可选）

1. 加入使用统计页面，展示每日使用时长和常用场景（需扩展后端表）。
2. 优化 UI/交互，适配深色模式和不同尺寸屏幕。
3. 补充错误提示、网络异常处理等细节。

### 7. 测试与验证

- **后端测试**
  - 使用 Postman 或 curl 测试各个 REST 接口，验证返回数据结构与状态码。
  - 针对数据库读写操作进行基本单元测试（可选）。

- **前端测试**
  - 在模拟器/真机上测试场景列表、场景详情、音轨播放、预设与计时等功能。
  - 测试网络异常、后端不可用时的提示与降级处理。

### 8. 总结与可扩展方向

- 当前规划已经覆盖：前后端分离、HTTP+JSON 通信、Go+SQLite 后端、Docker 部署、多音轨白噪音播放等核心点，满足音视频课程设计的要求。
- 后续可扩展方向：
  - 增加用户系统与登录，支持云端同步收藏与自定义场景。
  - 支持更多类型的音频资源与在线音频源。
  - 考虑引入简单的推荐逻辑，根据使用历史推荐场景与预设。
