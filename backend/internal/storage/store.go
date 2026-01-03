package storage

import (
    "github.com/homoapp/environment-noise-backend/internal/model"
    "gorm.io/gorm"
)

// Store wraps the database connection and provides database helpers.
type Store struct {
    db *gorm.DB
}

// New returns a Store bound to the provided gorm DB.
func New(db *gorm.DB) *Store {
    return &Store{db: db}
}

// ListScenes returns all scenes with their tracks preloaded.
func (s *Store) ListScenes() ([]model.Scene, error) {
    var scenes []model.Scene
    err := s.db.Preload("Tracks").Order("id asc").Find(&scenes).Error
    return scenes, err
}

// GetScene returns a specific scene by ID with tracks.
func (s *Store) GetScene(id uint) (model.Scene, error) {
    var scene model.Scene
    err := s.db.Preload("Tracks").First(&scene, id).Error
    return scene, err
}

// ListPresets returns all presets with track metadata.
func (s *Store) ListPresets() ([]model.Preset, error) {
    var presets []model.Preset
    err := s.db.Preload("PresetTracks.Track").Order("id asc").Find(&presets).Error
    return presets, err
}
