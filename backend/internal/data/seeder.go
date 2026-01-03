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
                    AudioURL:      "https://cdn.pixabay.com/download/audio/2023/01/23/audio_f7bb2c9a08.mp3?filename=calm-rain-7901.mp3",
                    DefaultVolume: 0.75,
                },
                {
                    Name:          "雷鸣",
                    AudioURL:      "https://cdn.pixabay.com/download/audio/2023/02/11/audio_576d5d8d10.mp3?filename=thunderstorm-13546.mp3",
                    DefaultVolume: 0.35,
                },
                {
                    Name:          "轻风",
                    AudioURL:      "https://cdn.pixabay.com/download/audio/2023/03/10/audio_7b2eec2a6d.mp3?filename=gentle-wind-16163.mp3",
                    DefaultVolume: 0.45,
                },
            },
        },
        {
            Name:        "森林清晨",
            Description: "露珠在叶尖摇曳，鸟鸣与水滴交织成透明旋律。",
            CoverURL:    "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=60",
            Atmosphere:  "Forest Calm",
            Tracks: []model.Track{
                {
                    Name:          "林间细雨",
                    AudioURL:      "https://cdn.pixabay.com/download/audio/2021/12/18/audio_7bf4da677a.mp3?filename=small-rain-114945.mp3",
                    DefaultVolume: 0.7,
                },
                {
                    Name:          "鸟群",
                    AudioURL:      "https://cdn.pixabay.com/download/audio/2021/10/12/audio_7c5f28591f.mp3?filename=birdsong-13803.mp3",
                    DefaultVolume: 0.55,
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
                    AudioURL:      "https://cdn.pixabay.com/download/audio/2021/08/04/audio_8cb6ef2bc0.mp3?filename=calm-sea-9931.mp3",
                    DefaultVolume: 0.9,
                },
                {
                    Name:          "晚风",
                    AudioURL:      "https://cdn.pixabay.com/download/audio/2023/08/10/audio_1c4db7a40f.mp3?filename=evening-breeze-13532.mp3",
                    DefaultVolume: 0.5,
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
                {TrackID: trackIndex["雨夜静听::雷鸣"], Volume: 0.25},
                {TrackID: trackIndex["雨夜静听::轻风"], Volume: 0.45},
            },
        },
        {
            Name:    "沉静森林",
            SceneID: scenes[1].ID,
            PresetTracks: []model.PresetTrack{
                {TrackID: trackIndex["森林清晨::林间细雨"], Volume: 0.85},
                {TrackID: trackIndex["森林清晨::鸟群"], Volume: 0.6},
            },
        },
        {
            Name:    "睡眠模式",
            SceneID: scenes[2].ID,
            PresetTracks: []model.PresetTrack{
                {TrackID: trackIndex["海浪低语::远洋海浪"], Volume: 1.0},
                {TrackID: trackIndex["海浪低语::晚风"], Volume: 0.6},
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
