package config

import (
    "os"
    "path/filepath"
)

// Config holds configurable settings for the noise API service.
type Config struct {
    Port   string
    DBPath string
}

// LoadConfig reads environment variables and fills default values.
func LoadConfig() Config {
    port := os.Getenv("NOISE_BACKEND_PORT")
    if port == "" {
        port = "8080"
    }

    dbPath := os.Getenv("NOISE_DB_PATH")
    if dbPath == "" {
        dbPath = "data/white_noise.db"
    }

    return Config{
        Port:   port,
        DBPath: dbPath,
    }
}

// EnsureDataDir makes sure the directory for the SQLite file exists.
func EnsureDataDir(dbPath string) error {
    dir := filepath.Dir(dbPath)
    if dir == "." {
        return nil
    }
    return os.MkdirAll(dir, 0o755)
}
