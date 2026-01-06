from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from . import models


def list_scenes(db: Session) -> list[models.Scene]:
    stmt = select(models.Scene).options(selectinload(models.Scene.tracks)).order_by(models.Scene.id.asc())
    return list(db.scalars(stmt).all())


def get_scene(db: Session, scene_id: int) -> models.Scene | None:
    stmt = (
        select(models.Scene)
        .options(selectinload(models.Scene.tracks))
        .where(models.Scene.id == scene_id)
        .limit(1)
    )
    return db.scalars(stmt).first()


def list_presets(db: Session) -> list[models.Preset]:
    stmt = (
        select(models.Preset)
        .options(
            selectinload(models.Preset.preset_tracks).selectinload(models.PresetTrack.track)
        )
        .order_by(models.Preset.id.asc())
    )
    return list(db.scalars(stmt).all())
