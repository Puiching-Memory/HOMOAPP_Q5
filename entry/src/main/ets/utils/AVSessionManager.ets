import { avSession } from "@kit.AVSessionKit"
import { hilog } from "@kit.PerformanceAnalysisKit"
import { backgroundTaskManager } from "@kit.BackgroundTasksKit"
import { wantAgent, common } from "@kit.AbilityKit"
import { GlobalMusic } from "../type/GlobalMusic"
import { AppStorageV2 } from "@kit.ArkUI"
import { SongItemType } from "../type/SongItemType"
import { avPlayerManage } from "./avPlayerMusic"
import { BusinessError } from "@ohos.base"

class AVSessionManager {
  session: avSession.AVSession | null = null
  GlobalMusic: GlobalMusic = AppStorageV2.connect(GlobalMusic, "GlobalMusic", () => new GlobalMusic())!
  private abilityContext: common.Context | null = null

  async init(context: common.Context) {
    this.abilityContext = context
    try {
      this.session = await avSession.createAVSession(context, "bgPlay", "audio")
      this.RegisterControlCommand()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `${err.message}`)
    }
  }

  async startContinuousTask() {
    if (!this.abilityContext) {
      return
    }
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: "com.example.homoq5",
          abilityName: "EntryAbility"
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }
    try {
      const want = await wantAgent.getWantAgent(wantAgentInfo)
      await backgroundTaskManager.startBackgroundRunning(
        this.abilityContext,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        want
      )
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `${err.message}`)
    }
  }

  SetMetaData(song: SongItemType) {
    try {
      this.session?.setAVMetadata({
        assetId: song.id,
        title: song.name,
        mediaImage: song.img,
        artist: song.author,
        duration: this.GlobalMusic.duration
      })
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `setAVMetadata error: ${err.message}`)
    }
  }

  setPlaybackStatus() {
    try {
      this.session?.setAVPlaybackState({
        state: this.GlobalMusic.isPlay
          ? avSession.PlaybackState.PLAYBACK_STATE_PLAY
          : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        speed: 1,
        position: { elapsedTime: this.GlobalMusic.time, updateTime: Date.now() },
        duration: this.GlobalMusic.duration
      })
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `setAVPlaybackState error: ${err.message}`)
    }
  }

  RegisterControlCommand() {
    this.session?.on("play", () => {
      try {
        avPlayerManage.stopOrContinueSong()
      } catch (err) {
        hilog.error(0x0000, "HOMO", `play session error: ${JSON.stringify(err)}`)
      }
    })

    this.session?.on("pause", () => {
      try {
        avPlayerManage.stopOrContinueSong()
      } catch (err) {
        hilog.error(0x0000, "HOMO", `pause session error: ${JSON.stringify(err)}`)
      }
    })

    this.session?.on("playNext", () => {
      try {
        avPlayerManage.nextSong()
      } catch (err) {
        hilog.error(0x0000, "HOMO", `nextSong session error: ${JSON.stringify(err)}`)
      }
    })

    this.session?.on("playPrevious", () => {
      try {
        avPlayerManage.preSong()
      } catch (err) {
        hilog.error(0x0000, "HOMO", `preSong session error: ${JSON.stringify(err)}`)
      }
    })

    this.session?.on("seek", (n: number) => {
      try {
        avPlayerManage.jumpToPlay(n)
      } catch (err) {
        hilog.error(0x0000, "HOMO", `seek session error: ${JSON.stringify(err)}`)
      }
    })

    try {
      this.session?.activate()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `activate error: ${err.message}`)
    }
  }

  async DestroySession() {
    try {
      await this.session?.destroy()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `DestroySession error: ${err.message}`)
    }
  }
}

export const SessionManager: AVSessionManager = new AVSessionManager()
