from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class AudioItem(BaseModel):
    id: int
    filename: str
    name: str
    url: str


class Track(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    name: str
    audio_url: str = Field(..., alias="audioUrl")
    default_volume: float = Field(..., alias="defaultVolume")


class SceneListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    name: str
    description: str
    cover_url: str = Field(..., alias="coverUrl")
    atmosphere: str


class SceneDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    name: str
    description: str
    cover_url: str = Field(..., alias="coverUrl")
    atmosphere: str
    tracks: List[Track]


class PresetTrack(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    track_id: int = Field(..., alias="trackId")
    name: str
    volume: float
    audio_url: str = Field(..., alias="audioUrl")


class PresetDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    name: str
    scene_id: int = Field(..., alias="sceneId")
    tracks: List[PresetTrack]


class SessionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    scene_id: int = Field(..., alias="sceneId")
    preset_id: Optional[int] = Field(None, alias="presetId")
    duration_minutes: Optional[int] = Field(None, alias="durationMinutes")
    notes: Optional[str] = None
