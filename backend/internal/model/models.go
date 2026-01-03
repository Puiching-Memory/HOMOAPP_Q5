package model

// Scene describes an immersive environment with its tracks.
type Scene struct {
    ID          uint    `gorm:"primaryKey" json:"id"`
    Name        string  `json:"name"`
    Description string  `json:"description"`
    CoverURL    string  `json:"coverUrl"`
    Atmosphere  string  `json:"atmosphere"`
    Tracks      []Track `json:"tracks" gorm:"foreignKey:SceneID"`
}

// Track represents a single audio stem within a scene.
type Track struct {
    ID            uint    `gorm:"primaryKey" json:"id"`
    SceneID       uint    `json:"sceneId"`
    Name          string  `json:"name"`
    AudioURL      string  `json:"audioUrl"`
    DefaultVolume float32 `json:"defaultVolume"`
}

// Preset is a quick collection of tracks saved for a mood.
type Preset struct {
    ID            uint           `gorm:"primaryKey" json:"id"`
    Name          string         `json:"name"`
    SceneID       uint           `json:"sceneId"`
    PresetTracks  []PresetTrack  `json:"tracks" gorm:"foreignKey:PresetID"`
}

// PresetTrack links a preset to a track and stores volume preference.
type PresetTrack struct {
    ID       uint    `gorm:"primaryKey" json:"id"`
    PresetID uint    `json:"presetId"`
    TrackID  uint    `json:"trackId"`
    Volume   float32 `json:"volume"`
    Track    Track   `json:"track" gorm:"foreignKey:TrackID"`
}
