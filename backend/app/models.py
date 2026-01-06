from __future__ import annotations

from sqlalchemy import Column, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from .database import Base


class Scene(Base):
    __tablename__ = "scenes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=False)
    cover_url = Column(String, nullable=False)
    atmosphere = Column(String, nullable=False)

    tracks = relationship("Track", back_populates="scene", cascade="all, delete-orphan")


class Track(Base):
    __tablename__ = "tracks"

    id = Column(Integer, primary_key=True, index=True)
    scene_id = Column(Integer, ForeignKey("scenes.id"), nullable=False)
    name = Column(String, nullable=False)
    audio_url = Column(String, nullable=False)
    default_volume = Column(Float, nullable=False, default=1.0)

    scene = relationship("Scene", back_populates="tracks")
    preset_tracks = relationship("PresetTrack", back_populates="track", cascade="all, delete-orphan")


class Preset(Base):
    __tablename__ = "presets"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    scene_id = Column(Integer, ForeignKey("scenes.id"), nullable=False)

    preset_tracks = relationship("PresetTrack", back_populates="preset", cascade="all, delete-orphan")


class PresetTrack(Base):
    __tablename__ = "preset_tracks"

    id = Column(Integer, primary_key=True, index=True)
    preset_id = Column(Integer, ForeignKey("presets.id"), nullable=False)
    track_id = Column(Integer, ForeignKey("tracks.id"), nullable=False)
    volume = Column(Float, nullable=False, default=1.0)

    preset = relationship("Preset", back_populates="preset_tracks")
    track = relationship("Track", back_populates="preset_tracks")
