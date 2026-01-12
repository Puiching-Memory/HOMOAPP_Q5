import { media } from "@kit.MediaKit"
import { GlobalMusic } from "../type/GlobalMusic"
import { AppStorageV2 } from "@kit.ArkUI"
import { SongItemType } from "../type/SongItemType"
import { hilog } from "@kit.PerformanceAnalysisKit"
import { SessionManager } from "./AVSessionManager"
import { BusinessError } from "@ohos.base"

class AvPlayerMusic {
  GlobalMusic: GlobalMusic = AppStorageV2.connect(GlobalMusic, "GlobalMusic", () => new GlobalMusic())!
  avPlayer: media.AVPlayer | null = null

  async init() {
    if (this.avPlayer) {
      return
    }
    try {
      this.avPlayer = await media.createAVPlayer()
      this.bindEvents()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `${err.message}`)
    }
  }

  private bindEvents() {
    if (!this.avPlayer) {
      return
    }
    this.avPlayer.on("stateChange", (state: media.AVPlayerState) => {
      if (state === "initialized") {
        this.GlobalMusic.isLoading = true
        this.avPlayer?.prepare().catch(() => {})
      } else if (state === "prepared") {
        this.GlobalMusic.isLoading = false
        this.GlobalMusic.isPlay = true
        this.avPlayer?.play().catch(() => {})
      } else if (state === "playing") {
        this.GlobalMusic.isLoading = false
        this.GlobalMusic.isPlay = true
        SessionManager.setPlaybackStatus()
      } else if (state === "paused") {
        this.GlobalMusic.isLoading = false
        this.GlobalMusic.isPlay = false
        SessionManager.setPlaybackStatus()
      } else if (state === "completed") {
        this.GlobalMusic.isLoading = false
        this.nextSong()
      } else if (state === "released") {
        this.GlobalMusic.isLoading = false
        this.release()
      } else if (state === "idle" || state === "stopped") {
        this.GlobalMusic.isLoading = false
        this.GlobalMusic.isPlay = false
      }
    })

    this.avPlayer.on("durationUpdate", (duration: number) => {
      this.GlobalMusic.duration = duration
      const song = this.GlobalMusic.playList[this.GlobalMusic.currentMusic]
      if (song) {
        SessionManager.SetMetaData(song)
      }
    })

    this.avPlayer.on("timeUpdate", (time: number) => {
      this.GlobalMusic.time = time
      SessionManager.setPlaybackStatus()
    })

    this.avPlayer.on("error", (error: BusinessError) => {
      hilog.error(0x0000, "HOMO", `${JSON.stringify(error)}`)
    })
  }

  private syncCurrentSong(song: SongItemType) {
    this.GlobalMusic.url = song.url
    this.GlobalMusic.img = song.img
    this.GlobalMusic.name = song.name
    this.GlobalMusic.author = song.author
    this.GlobalMusic.waveform = song.waveform || []
    hilog.info(0x0000, "HOMO", `Sync song: ${song.name}, Waveform points: ${this.GlobalMusic.waveform.length}`)
    
    // 应用响度均衡
    this.applyLoudnessBalance()
    
    SessionManager.SetMetaData(song)
  }

  // 计算并应用均衡后的音量
  private applyLoudnessBalance() {
    if (!this.avPlayer) return

    let finalVolume = this.GlobalMusic.volume
    
    if (this.GlobalMusic.isLoudnessBalanced && this.GlobalMusic.waveform.length > 0) {
      // 计算平均响度 (0.1 - 0.9 之间)
      const avg = this.GlobalMusic.waveform.reduce((a, b) => a + b, 0) / this.GlobalMusic.waveform.length
      // 目标基准响度设定为 0.5
      const target = 0.5
      // 计算补偿系数，限制在 0.5x 到 2.0x 之间避免过度放大或静音
      const ratio = Math.max(0.5, Math.min(2.0, target / avg))
      finalVolume = Math.min(1.0, this.GlobalMusic.volume * ratio)
      hilog.info(0x0000, "HOMO", `Loudness Balance: avg=${avg.toFixed(3)}, ratio=${ratio.toFixed(2)}, volume=${finalVolume.toFixed(2)}`)
    }
    
    this.avPlayer.setVolume(finalVolume)
  }

  async changePlay() {
    try {
      if (!this.avPlayer) {
        await this.init()
      }
      if (!this.avPlayer) {
        return
      }
      const song = this.GlobalMusic.playList[this.GlobalMusic.currentMusic]
      if (!song) {
        return
      }
      await this.avPlayer.reset()
      this.GlobalMusic.time = 0
      this.GlobalMusic.duration = 0
      this.syncCurrentSong(song)
      this.avPlayer.url = song.url
      this.avPlayer.setVolume(this.GlobalMusic.volume)
      this.GlobalMusic.isPlay = true
      this.GlobalMusic.isShowPlayBar = true
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `changePlay error: ${err.message}`)
    }
  }

  preSong() {
    try {
      if (this.GlobalMusic.playbackStatus === "顺序播放" || this.GlobalMusic.playbackStatus === "随机播放") {
        if (this.GlobalMusic.currentMusic <= 0) {
          this.GlobalMusic.currentMusic = this.GlobalMusic.playList.length - 1
        } else {
          this.GlobalMusic.currentMusic--
        }
        this.changePlay()
      } else {
        this.avPlayer?.play()
      }
      SessionManager.setPlaybackStatus()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `preSong error: ${err.message}`)
    }
  }

  nextSong() {
    try {
      if (this.GlobalMusic.playbackStatus === "顺序播放") {
        if (this.GlobalMusic.currentMusic >= this.GlobalMusic.playList.length - 1) {
          this.GlobalMusic.currentMusic = 0
        } else {
          this.GlobalMusic.currentMusic++
        }
        this.changePlay()
      } else if (this.GlobalMusic.playbackStatus === "单曲循环") {
        this.avPlayer?.play()
      } else {
        let old = this.GlobalMusic.currentMusic
        this.GlobalMusic.currentMusic = Math.floor(Math.random() * this.GlobalMusic.playList.length)
        if (old === this.GlobalMusic.currentMusic && this.GlobalMusic.playList.length > 1) {
          this.GlobalMusic.currentMusic = Math.floor(Math.random() * this.GlobalMusic.playList.length)
        }
        old = this.GlobalMusic.currentMusic
        this.changePlay()
      }
      SessionManager.setPlaybackStatus()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `nextSong error: ${err.message}`)
    }
  }

  stopOrContinueSong() {
    try {
      if (!this.avPlayer) {
        return
      }
      if (this.GlobalMusic.isPlay) {
        this.GlobalMusic.isPlay = false
        this.avPlayer.pause()
      } else {
        this.GlobalMusic.isPlay = true
        this.avPlayer.play()
      }
      SessionManager.setPlaybackStatus()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `stopOrContinueSong error: ${err.message}`)
    }
  }

  async playResources(song: SongItemType) {
    await SessionManager.startContinuousTask()
    const index = this.GlobalMusic.playList.findIndex(item => item.id === song.id)
    if (index >= 0) {
      if (song.url === this.GlobalMusic.url && this.GlobalMusic.isPlay) {
        return
      }
      this.GlobalMusic.currentMusic = index
      await this.changePlay()
    } else {
      this.GlobalMusic.playList.unshift(song)
      this.GlobalMusic.currentMusic = 0
      await this.changePlay()
    }
    this.GlobalMusic.isShowPlayBar = true
    SessionManager.setPlaybackStatus()
  }

  jumpToPlay(jumpToTime: number) {
    try {
      this.avPlayer?.seek(jumpToTime)
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `jumpToPlay error: ${err.message}`)
    }
  }

  deleteSong(index: number) {
    this.GlobalMusic.playList.splice(index, 1)
  }

  async stop() {
    try {
      if (!this.avPlayer) {
        return
      }
      await this.avPlayer.stop()
      this.GlobalMusic.isPlay = false
      this.GlobalMusic.time = 0
      SessionManager.setPlaybackStatus()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `stop error: ${err.message}`)
    }
  }

  setVolume(volume: number) {
    try {
      this.GlobalMusic.volume = volume
      this.applyLoudnessBalance()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `setVolume error: ${err.message}`)
    }
  }

  // 外部切换均衡器开关
  toggleLoudnessBalance(isOn: boolean) {
    this.GlobalMusic.isLoudnessBalanced = isOn
    this.applyLoudnessBalance()
  }

  async release() {
    try {
      await this.avPlayer?.release()
      this.avPlayer = null
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `release error: ${err.message}`)
    }
  }
}

export const avPlayerManage: AvPlayerMusic = new AvPlayerMusic()
