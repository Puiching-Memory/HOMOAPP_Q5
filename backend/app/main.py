from __future__ import annotations

import logging
from pathlib import Path
from typing import Annotated, List

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from . import crud, models
from .config import get_settings
from .database import Base, SessionLocal, engine
from .schemas import AudioItem, PresetDetail, PresetTrack, SceneDetail, SceneListItem, SessionRequest, Track
from .seed import seed_if_needed

logger = logging.getLogger("uvicorn.error")
settings = get_settings()

app = FastAPI(title="Environment Noise API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"] ,
    allow_headers=["*"],
)


# Dependency
async def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_if_needed(db)


@app.get("/data/{file_path:path}")
async def serve_static_file(file_path: str):
    """Serve audio files from the data directory with basic path safety."""
    safe_base = settings.data_dir
    target = (safe_base / file_path).resolve()
    if safe_base not in target.parents and target != safe_base:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid file path")
    if not target.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="file not found")
    return FileResponse(target, media_type="audio/mpeg")


@app.get("/api/v1/audio", response_model=List[AudioItem])
async def list_audio_files():
    """Return audio files under the data directory."""
    data_dir: Path = settings.data_dir
    if not data_dir.is_dir():
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="data directory missing")

    audio_items: List[AudioItem] = []
    for entry in sorted(data_dir.iterdir()):
        if entry.is_dir():
            continue
        if entry.suffix.lower() not in {".mp3", ".wav", ".ogg"}:
            continue
        display_name = entry.stem
        audio_items.append(
            AudioItem(
                id=len(audio_items) + 1,
                filename=entry.name,
                name=display_name,
                url=f"/data/{entry.name}",
            )
        )
    return audio_items


@app.get("/api/v1/scenes", response_model=List[SceneListItem])
async def list_scenes(db: Annotated[Session, Depends(get_db)]):
    scenes = crud.list_scenes(db)
    return [
        SceneListItem(
            id=scene.id,
            name=scene.name,
            description=scene.description,
            cover_url=scene.cover_url,
            atmosphere=scene.atmosphere,
        )
        for scene in scenes
    ]


@app.get("/api/v1/scenes/{scene_id}", response_model=SceneDetail)
async def get_scene(scene_id: int, db: Annotated[Session, Depends(get_db)]):
    scene = crud.get_scene(db, scene_id)
    if scene is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="scene not found")

    tracks = [
        Track(
            id=track.id,
            name=track.name,
            audio_url=track.audio_url,
            default_volume=track.default_volume,
        )
        for track in scene.tracks
    ]

    return SceneDetail(
        id=scene.id,
        name=scene.name,
        description=scene.description,
        cover_url=scene.cover_url,
        atmosphere=scene.atmosphere,
        tracks=tracks,
    )


@app.get("/api/v1/presets", response_model=List[PresetDetail])
async def list_presets(db: Annotated[Session, Depends(get_db)]):
    presets = crud.list_presets(db)
    response: List[PresetDetail] = []
    for preset in presets:
        tracks = [
            PresetTrack(
                track_id=pt.track_id,
                name=pt.track.name,
                volume=pt.volume,
                audio_url=pt.track.audio_url,
            )
            for pt in preset.preset_tracks
        ]
        response.append(
            PresetDetail(
                id=preset.id,
                name=preset.name,
                scene_id=preset.scene_id,
                tracks=tracks,
            )
        )
    return response


@app.post("/api/v1/listening-session", status_code=status.HTTP_202_ACCEPTED)
async def record_session(payload: SessionRequest):
    # Persisting sessions can be added later; logging is sufficient for now.
    logger.info("session recorded", extra={"sceneId": payload.scene_id, "presetId": payload.preset_id})
    return {"status": "recorded", "session": payload.model_dump(by_alias=True)}
