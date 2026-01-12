from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent


class Settings:
    """Application runtime configuration loaded from environment."""

    def __init__(self) -> None:
        default_data_dir = BASE_DIR / "data"

        self.port = int(os.getenv("NOISE_BACKEND_PORT", "8080"))
        self.data_dir = Path(os.getenv("NOISE_DATA_DIR", default_data_dir)).resolve()
        self.local_ip = os.getenv("NOISE_LOCAL_IP", None)

    def ensure_paths(self) -> None:
        """Create directories for data files if missing."""
        self.data_dir.mkdir(parents=True, exist_ok=True)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
