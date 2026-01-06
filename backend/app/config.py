from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent


class Settings:
    """Application runtime configuration loaded from environment."""

    def __init__(self) -> None:
        default_db = BASE_DIR / "data" / "white_noise.db"
        default_data_dir = BASE_DIR / "data"

        self.port = int(os.getenv("NOISE_BACKEND_PORT", "8080"))
        self.db_path = Path(os.getenv("NOISE_DB_PATH", default_db)).resolve()
        self.data_dir = Path(os.getenv("NOISE_DATA_DIR", default_data_dir)).resolve()

    @property
    def sqlite_url(self) -> str:
        return f"sqlite:///{self.db_path}"

    def ensure_paths(self) -> None:
        """Create directories for the SQLite file and data files if missing."""
        if self.db_path.parent.name:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.data_dir.mkdir(parents=True, exist_ok=True)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
