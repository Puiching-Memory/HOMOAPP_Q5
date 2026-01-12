from __future__ import annotations

import logging
import socket
from pathlib import Path
from typing import List

from fastapi import FastAPI, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, FileResponse
from fastapi.staticfiles import StaticFiles

from .config import get_settings

logger = logging.getLogger("uvicorn.error")
settings = get_settings()

def get_local_ip():
    """获取本机局域网 IP，支持环境变量覆盖"""
    if settings.local_ip:
        return settings.local_ip
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

app = FastAPI(title="Environment Noise API (Static)", version="1.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"] ,
    allow_headers=["*"],
)

# 挂载静态资源展示 (图片等)
static_path = Path(__file__).resolve().parent.parent / "static"
app.mount("/static", StaticFiles(directory=str(static_path)), name="static")

@app.get("/data/{file_path:path}")
async def serve_audio_file(file_path: str):
    """直接服务音频资源"""
    safe_base = settings.data_dir
    target = (safe_base / file_path).resolve()
    if safe_base not in target.parents and target != safe_base:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid file path")
    if not target.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="file not found")
    return FileResponse(target)

@app.get("/api/v1/{resource}")
async def get_json_data(resource: str, request: Request):
    """读取 JSON 数据并根据请求来源动态替换 IP 地址，完美适配 Docker 环境"""
    # 优先从请求头获取 Host (例如 10.0.2.2:8080 或 mydomain.com)
    host = request.headers.get("host")
    if not host:
        # 降级方案：使用之前的探测逻辑
        ip = get_local_ip()
        port = settings.port
        host = f"{ip}:{port}"
    
    # 移除多余后缀
    resource = resource.replace(".json", "")
    file_path = Path(__file__).resolve().parent.parent / "data" / f"{resource}.json"
    
    if not file_path.exists():
        if resource == "audio":
            return await list_audio_files_dynamically(host)
        raise HTTPException(status_code=404, detail=f"Resource {resource} not found")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            # 执行 IP 动态适配：将所有 127.0.0.1:8080 替换为用户访问的实际 Host
            # 这样无论 Docker 内部 IP 是什么，返回给 App 的都是它能连通的地址
            placeholder = "127.0.0.1:8080"
            content = content.replace(placeholder, host)
            content = content.replace("localhost:8080", host)
            
            return Response(content=content, media_type="application/json")
    except Exception as e:
        logger.error(f"Error reading {resource}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

async def list_audio_files_dynamically(host: str):
    """动态扫描音频目录并整合静态目录中的 MP3，使用请求中的 Host"""
    data_dir: Path = settings.data_dir
    static_song_dir: Path = Path(__file__).resolve().parent.parent / "static" / "song"
    audio_items = []
    
    # 1. 扫描 data 目录下的音频文件
    if data_dir.is_dir():
        for entry in sorted(data_dir.iterdir()):
            if entry.suffix.lower() in {".mp3", ".wav", ".ogg"}:
                audio_items.append({
                    "id": len(audio_items) + 1,
                    "filename": entry.name,
                    "name": entry.stem.replace("_", " ").title(),
                    "url": f"http://{host}/data/{entry.name}",
                    "artist": "自然之声",
                    "cover_url": f"/static/song/{len(audio_items) % 15}.png"
                })
    
    # 2. 扫描 static/song 目录下的音频文件，丰富资源库
    if static_song_dir.is_dir():
        for entry in sorted(static_song_dir.iterdir()):
            if entry.suffix.lower() == ".mp3":
                # 检查是否已包含(避免重复)
                if any(item["filename"] == entry.name for item in audio_items):
                    continue
                
                # 尝试匹配同名的 png 作为封面
                cover_name = entry.stem + ".png"
                cover_path = static_song_dir / cover_name
                cover_url = f"/static/song/{cover_name}" if cover_path.exists() else f"/static/song/{len(audio_items) % 15}.png"
                
                audio_items.append({
                    "id": len(audio_items) + 1,
                    "filename": entry.name,
                    "name": f"环境音 {entry.stem}",
                    "url": f"http://{host}/static/song/{entry.name}",
                    "artist": "系统精选",
                    "cover_url": cover_url
                })
                
    return audio_items
