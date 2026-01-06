from __future__ import annotations

from typing import Dict

from sqlalchemy.orm import Session

from . import models


def seed_if_needed(db: Session) -> None:
    """Populate the database with starter data if empty."""
    if db.query(models.Scene).count() > 0:
        return

    scenes = [
        models.Scene(
            name="雨夜静听",
            description="微雨掠过窗沿，营造低调专注的脑波节奏。",
            cover_url="https://images.unsplash.com/photo-1509718443690-d8e2fb3474d1?auto=format&fit=crop&w=900&q=60",
            atmosphere="Rain Focus",
            tracks=[
                models.Track(
                    name="细雨",
                    audio_url="/data/light_rain.mp3",
                    default_volume=0.75,
                )
            ],
        ),
        models.Scene(
            name="海浪低语",
            description="海浪推移节奏柔慢，波光与晚风共同铺出催眠底色。",
            cover_url="https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=60",
            atmosphere="Coastal Flow",
            tracks=[
                models.Track(
                    name="远洋海浪",
                    audio_url="/data/ocean_waves.mp3",
                    default_volume=0.9,
                )
            ],
        ),
    ]

    for scene in scenes:
        db.add(scene)
    db.flush()

    track_index: Dict[str, int] = {}
    for scene in scenes:
        for track in scene.tracks:
            track_index[f"{scene.name}::{track.name}"] = track.id

    presets = [
        models.Preset(
            name="学习模式",
            scene_id=scenes[0].id,
            preset_tracks=[
                models.PresetTrack(track_id=track_index["雨夜静听::细雨"], volume=0.9)
            ],
        ),
        models.Preset(
            name="睡眠模式",
            scene_id=scenes[1].id,
            preset_tracks=[
                models.PresetTrack(track_id=track_index["海浪低语::远洋海浪"], volume=1.0)
            ],
        ),
    ]

    for preset in presets:
        db.add(preset)

    db.commit()
