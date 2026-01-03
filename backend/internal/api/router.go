package api

import (
    "errors"
    "net/http"
    "strconv"

    "github.com/gin-gonic/gin"
    "github.com/homoapp/environment-noise-backend/internal/storage"
    "gorm.io/gorm"
)

// Handler exposes API routes.
type Handler struct {
    store *storage.Store
}

// NewRouter builds the Gin engine with middleware and routes.
func NewRouter(store *storage.Store) *gin.Engine {
    router := gin.New()
    router.Use(gin.Logger(), gin.Recovery(), corsMiddleware)

    handler := &Handler{store: store}
    api := router.Group("/api/v1")
    {
        api.GET("/scenes", handler.listScenes)
        api.GET("/scenes/:id", handler.getSceneByID)
        api.GET("/presets", handler.listPresets)
        api.POST("/listening-session", handler.recordSession)
    }

    return router
}

func corsMiddleware(c *gin.Context) {
    c.Header("Access-Control-Allow-Origin", "*")
    c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept")
    if c.Request.Method == http.MethodOptions {
        c.AbortWithStatus(http.StatusNoContent)
        return
    }
    c.Next()
}

func (h *Handler) listScenes(c *gin.Context) {
    scenes, err := h.store.ListScenes()
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    response := make([]sceneListItem, 0, len(scenes))
    for _, scene := range scenes {
        response = append(response, sceneListItem{
            ID:          scene.ID,
            Name:        scene.Name,
            Description: scene.Description,
            CoverURL:    scene.CoverURL,
            Atmosphere:  scene.Atmosphere,
        })
    }

    c.JSON(http.StatusOK, response)
}

func (h *Handler) getSceneByID(c *gin.Context) {
    id, err := parseIDParam(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "scene id invalid"})
        return
    }

    scene, err := h.store.GetScene(id)
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            c.JSON(http.StatusNotFound, gin.H{"error": "scene not found"})
            return
        }
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    tracks := make([]trackDetail, 0, len(scene.Tracks))
    for _, track := range scene.Tracks {
        tracks = append(tracks, trackDetail{
            ID:            track.ID,
            Name:          track.Name,
            AudioURL:      track.AudioURL,
            DefaultVolume: track.DefaultVolume,
        })
    }

    c.JSON(http.StatusOK, sceneDetail{
        ID:          scene.ID,
        Name:        scene.Name,
        Description: scene.Description,
        CoverURL:    scene.CoverURL,
        Atmosphere:  scene.Atmosphere,
        Tracks:      tracks,
    })
}

func (h *Handler) listPresets(c *gin.Context) {
    presets, err := h.store.ListPresets()
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    response := make([]presetDetail, 0, len(presets))
    for _, preset := range presets {
        tracks := make([]presetTrackDetail, 0, len(preset.PresetTracks))
        for _, pt := range preset.PresetTracks {
            trackName := pt.Track.Name
            audioURL := pt.Track.AudioURL
            tracks = append(tracks, presetTrackDetail{
                TrackID:  pt.TrackID,
                Name:     trackName,
                Volume:   pt.Volume,
                AudioURL: audioURL,
            })
        }

        response = append(response, presetDetail{
            ID:      preset.ID,
            Name:    preset.Name,
            SceneID: preset.SceneID,
            Tracks:  tracks,
        })
    }

    c.JSON(http.StatusOK, response)
}

func (h *Handler) recordSession(c *gin.Context) {
    var req sessionRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
        return
    }

    // Logging is enough for now; session persistence can be added later.
    c.JSON(http.StatusAccepted, gin.H{"status": "recorded", "session": req})
}

func parseIDParam(raw string) (uint, error) {
    value, err := strconv.ParseUint(raw, 10, 64)
    if err != nil {
        return 0, err
    }
    return uint(value), nil
}

// --- response helpers ---

type sceneListItem struct {
    ID          uint   `json:"id"`
    Name        string `json:"name"`
    Description string `json:"description"`
    CoverURL    string `json:"coverUrl"`
    Atmosphere  string `json:"atmosphere"`
}

type sceneDetail struct {
    ID          uint          `json:"id"`
    Name        string        `json:"name"`
    Description string        `json:"description"`
    CoverURL    string        `json:"coverUrl"`
    Atmosphere  string        `json:"atmosphere"`
    Tracks      []trackDetail `json:"tracks"`
}

type trackDetail struct {
    ID            uint    `json:"id"`
    Name          string  `json:"name"`
    AudioURL      string  `json:"audioUrl"`
    DefaultVolume float32 `json:"defaultVolume"`
}

type presetDetail struct {
    ID      uint                 `json:"id"`
    Name    string               `json:"name"`
    SceneID uint                 `json:"sceneId"`
    Tracks  []presetTrackDetail  `json:"tracks"`
}

type presetTrackDetail struct {
    TrackID  uint    `json:"trackId"`
    Name     string  `json:"name"`
    Volume   float32 `json:"volume"`
    AudioURL string  `json:"audioUrl"`
}

type sessionRequest struct {
    SceneID         uint   `json:"sceneId"`
    PresetID        *uint  `json:"presetId,omitempty"`
    DurationMinutes int    `json:"durationMinutes,omitempty"`
    Notes           string `json:"notes,omitempty"`
}
