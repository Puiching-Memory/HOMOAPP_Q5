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

import librosa
import numpy as np
import hashlib
import math
import json

logger = logging.getLogger("uvicorn.error")
settings = get_settings()

CACHE_FILE = settings.data_dir / "waveform_cache.json"
WAVEFORM_CACHE = {}

if CACHE_FILE.exists():
    try:
        with open(CACHE_FILE, 'r', encoding='utf-8') as f:
            WAVEFORM_CACHE = json.load(f)
            logger.info(f"Loaded {len(WAVEFORM_CACHE)} items from waveform cache")
    except Exception as e:
        logger.warning(f"Failed to load waveform cache: {e}")

def save_cache():
    try:
        with open(CACHE_FILE, 'w', encoding='utf-8') as f:
            json.dump(WAVEFORM_CACHE, f, ensure_ascii=False)
    except Exception as e:
        logger.error(f"Failed to save waveform cache: {e}")

def generate_pseudo_waveform(filename: str, points: int = 128) -> List[float]:
    """兜底方案：根据文件名生成确定性的伪波形数据"""
    seed = int(hashlib.md5(filename.encode()).hexdigest(), 16)
    waveform = []
    for i in range(points):
        val = (
            math.sin(i * 0.1 + seed % 10) * 0.3 + 
            math.sin(i * 0.25 + seed % 7) * 0.2 + 
            math.sin(i * 0.05 + seed % 13) * 0.4 +
            0.5
        )
        val = max(0.1, min(0.9, val))
        waveform.append(round(val, 3))
    return waveform

def get_real_waveform(file_path: Path, points: int = 128) -> List[float]:
    """
    核心算法：使用短时傅里叶变换 (STFT) 提取频谱质心和能量，
    反映音频在频率维度上的真实特征，而不仅仅是时域能量。
    """
    file_str = str(file_path.resolve())
    if file_str in WAVEFORM_CACHE:
        return WAVEFORM_CACHE[file_str]
    
    logger.info(f"Analyzing spectral waveform for: {file_path.name}")
    try:
        # 1. 加载音频
        y, sr = librosa.load(file_path, sr=22050, mono=True)
        
        # 2. 执行短时傅里叶变换 (STFT)
        # 使用较大的 n_fft 以获得更好的频率分辨率
        n_fft = 2048
        hop_length = max(1, len(y) // points)
        stft = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop_length))
        
        # 3. 提取特征：这里使用频谱对比度或简单的梅尔频率谱能量
        # 为了让 UI 看起来“依据频率显示”，我们取不同频段的平均能量
        # 如果点数多，则按时间轴取每个时刻的频谱质心高度
        
        # 计算频谱中心 (Spectral Centroid) - 反映频率分布的重心
        centroid = librosa.feature.spectral_centroid(y=y, sr=sr, n_fft=n_fft, hop_length=hop_length)[0]
        
        # 计算梅尔谱能量以增强视觉表现力
        mels = librosa.feature.melspectrogram(y=y, sr=sr, n_fft=n_fft, hop_length=hop_length)
        mels_db = librosa.power_to_db(mels, ref=np.max)
        intensity = np.mean(mels_db, axis=0) # 时间轴上的强度
        
        # 结合质心和强度（类似于音调和响度的结合）
        combined = (centroid / np.max(centroid)) * 0.4 + (intensity - np.min(intensity)) / (np.max(intensity) - np.min(intensity)) * 0.6
        
        # 4. 线性插值/截断到固定长度
        if len(combined) > points:
            combined = combined[:points]
            
        # 归一化到 [0.1, 0.9]
        min_val, max_val = np.min(combined), np.max(combined)
        if max_val > min_val:
            normalized = (combined - min_val) / (max_val - min_val) * 0.8 + 0.1
        else:
            normalized = np.full_like(combined, 0.5)
            
        result = [round(float(v), 3) for v in normalized]
        
        # 补齐点数
        if len(result) < points:
            result.extend([0.1] * (points - len(result)))
            
        WAVEFORM_CACHE[file_str] = result
        save_cache()
        return result
    except Exception as e:
        logger.warning(f"Could not analyze spectral feature of {file_path.name}: {e}")
        return generate_pseudo_waveform(file_path.name, points)

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

import json

def inject_waveforms_recursively(data):
    """递归遍历 JSON 数据，尝试分析音频文件的真实波形"""
    if isinstance(data, list):
        for item in data:
            inject_waveforms_recursively(item)
    elif isinstance(data, dict):
        if "url" in data and (".mp3" in data["url"] or ".wav" in data["url"]) and "waveform" not in data:
            # 根据内部 URL 推断本地文件路径进行分析
            url_path = data["url"]
            local_path = None
            if "/data/" in url_path:
                local_path = settings.data_dir / url_path.split("/data/")[-1]
            elif "/static/song/" in url_path:
                local_path = Path(__file__).resolve().parent.parent / "static" / "song" / url_path.split("/static/song/")[-1]
                
            if local_path and local_path.is_file():
                data["waveform"] = get_real_waveform(local_path)
            else:
                data["waveform"] = generate_pseudo_waveform(data.get("name", "audio"))
        for key in data:
            inject_waveforms_recursively(data[key])

@app.get("/api/v1/{resource}")
async def get_json_data(resource: str, request: Request):
    """读取 JSON 数据并根据请求来源动态替换 IP 地址，同时注入波形数据"""
    # 优先从请求头获取 Host
    host = request.headers.get("host")
    if not host:
        ip = get_local_ip()
        port = settings.port
        host = f"{ip}:{port}"
    
    resource = resource.replace(".json", "")
    file_path = Path(__file__).resolve().parent.parent / "data" / f"{resource}.json"
    
    if not file_path.exists():
        if resource == "audio":
            return await list_audio_files_dynamically(host)
        raise HTTPException(status_code=404, detail=f"Resource {resource} not found")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
            # 为数据注入波形
            inject_waveforms_recursively(data)
            
            # 序列化并替换 Host
            content = json.dumps(data, ensure_ascii=False)
            placeholder = "127.0.0.1:8080"
            content = content.replace(placeholder, host)
            content = content.replace("localhost:8080", host)
            
            return Response(content=content, media_type="application/json")
    except Exception as e:
        logger.error(f"Error reading {resource}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

async def list_audio_files_dynamically(host: str):
    """动态扫描音频目录并使用 librosa 分析真实波形"""
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
                    "cover_url": f"/static/song/{len(audio_items) % 15}.png",
                    "waveform": get_real_waveform(entry)
                })
    
    # 2. 扫描 static/song 目录下的音频文件
    if static_song_dir.is_dir():
        for entry in sorted(static_song_dir.iterdir()):
            if entry.suffix.lower() == ".mp3":
                if any(item["filename"] == entry.name for item in audio_items):
                    continue
                
                cover_name = entry.stem + ".png"
                cover_path = static_song_dir / cover_name
                cover_url = f"/static/song/{cover_name}" if cover_path.exists() else f"/static/song/{len(audio_items) % 15}.png"
                
                audio_items.append({
                    "id": len(audio_items) + 1,
                    "filename": entry.name,
                    "name": f"环境音 {entry.stem}",
                    "url": f"http://{host}/static/song/{entry.name}",
                    "artist": "系统精选",
                    "cover_url": cover_url,
                    "waveform": get_real_waveform(entry)
                })
                
    return audio_items
