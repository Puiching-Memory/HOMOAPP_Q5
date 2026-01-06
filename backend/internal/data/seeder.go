package data

import (
    "fmt"

    "github.com/homoapp/environment-noise-backend/internal/model"
    "gorm.io/gorm"
)

// Seed applies sample scenes, tracks, and presets if the database is empty.
func Seed(db *gorm.DB) error {
    var count int64
    if err := db.Model(&model.Scene{}).Count(&count).Error; err != nil {
        return err
    }
    if count > 0 {
        return nil
    }

    scenes := []model.Scene{
        {
            Name:        "雨夜静听",
            Description: "微雨掠过窗沿，营造低调专注的脑波节奏。",
            CoverURL:    "https://images.unsplash.com/photo-1509718443690-d8e2fb3474d1?auto=format&fit=crop&w=900&q=60",
            Atmosphere:  "Rain Focus",
            Tracks: []model.Track{
                {
                    Name:          "细雨",
                    AudioURL:      "/data/小区%20小雨%20白噪音%20下雨天%20城市%20高楼_爱给网_aigei_com.mp3",
                    DefaultVolume: 0.75,
                },
            },
        },
        {
            Name:        "海浪低语",
            Description: "海浪推移节奏柔慢，波光与晚风共同铺出催眠底色。",
            CoverURL:    "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=60",
            Atmosphere:  "Coastal Flow",
            Tracks: []model.Track{
                {
                    Name:          "远洋海浪",
                    AudioURL:      "/data/海浪%20沙滩%20海水冲刷细沙的沙沙声%20自然白噪音%20海边环境音%20风_爱给网_aigei_com.mp3",
                    DefaultVolume: 0.9,
                },
            },
        },
    }

    for idx := range scenes {
        if err := db.Create(&scenes[idx]).Error; err != nil {
            return err
        }
    }

    trackIndex := map[string]uint{}
    for _, scene := range scenes {
        for _, track := range scene.Tracks {
            key := fmt.Sprintf("%s::%s", scene.Name, track.Name)
            trackIndex[key] = track.ID
        }
    }

    presets := []model.Preset{
        {
            Name:    "学习模式",
            SceneID: scenes[0].ID,
            PresetTracks: []model.PresetTrack{
                {TrackID: trackIndex["雨夜静听::细雨"], Volume: 0.9},
            },
        },
        {
            Name:    "睡眠模式",
            SceneID: scenes[1].ID,
            PresetTracks: []model.PresetTrack{
                {TrackID: trackIndex["海浪低语::远洋海浪"], Volume: 1.0},
            },
        },
    }

    for idx := range presets {
        if err := db.Create(&presets[idx]).Error; err != nil {
            return err
        }
    }

    return nil
}
