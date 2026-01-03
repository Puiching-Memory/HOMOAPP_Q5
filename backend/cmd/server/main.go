package main

import (
    "fmt"
    "log"

    "github.com/homoapp/environment-noise-backend/internal/api"
    "github.com/homoapp/environment-noise-backend/internal/config"
    "github.com/homoapp/environment-noise-backend/internal/data"
    "github.com/homoapp/environment-noise-backend/internal/model"
    "github.com/homoapp/environment-noise-backend/internal/storage"
    "gorm.io/driver/sqlite"
    "gorm.io/gorm"
)

func main() {
    cfg := config.LoadConfig()
    if err := config.EnsureDataDir(cfg.DBPath); err != nil {
        log.Fatalf("failed to ensure database directory: %v", err)
    }

    db, err := gorm.Open(sqlite.Open(cfg.DBPath), &gorm.Config{})
    if err != nil {
        log.Fatalf("failed to open datastore: %v", err)
    }

    if err := db.AutoMigrate(&model.Scene{}, &model.Track{}, &model.Preset{}, &model.PresetTrack{}); err != nil {
        log.Fatalf("migration failed: %v", err)
    }

    if err := data.Seed(db); err != nil {
        log.Fatalf("failed to seed demo data: %v", err)
    }

    store := storage.New(db)
    router := api.NewRouter(store)
    addr := fmt.Sprintf(":%s", cfg.Port)
    log.Printf("environment noise API listening on %s", addr)

    if err := router.Run(addr); err != nil {
        log.Fatalf("server stopped: %v", err)
    }
}
