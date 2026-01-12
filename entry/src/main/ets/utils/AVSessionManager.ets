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
      hilog.error(0x0000, "HOMO", `init session error: ${err.message}`)
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
      hilog.info(0x0000, "HOMO", "Continuous task started successfully")
    } catch (error) {
      const err = error as BusinessError
      if (err.code === 9800005 || err.code === 9800002) {
        // 9800005: 已经申请过长久运行任务，忽略该错误
        hilog.info(0x0000, "HOMO", "Continuous task already running")
      } else {
        hilog.error(0x0000, "HOMO", `startContinuousTask error: ${err.code} ${err.message}`)
      }
    }
  }

  SetMetaData(song: SongItemType) {
    if (!this.session) {
      hilog.warn(0x0000, "HOMO", "SetMetaData failed: session not initialized")
      return
    }
    try {
      this.session.setAVMetadata({
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
    if (!this.session) {
      hilog.warn(0x0000, "HOMO", "setPlaybackStatus skipped: session null")
      return
    }
    try {
      this.session.setAVPlaybackState({
        state: this.GlobalMusic.isPlay
          ? avSession.PlaybackState.PLAYBACK_STATE_PLAY
          : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        speed: 1,
        position: { elapsedTime: this.GlobalMusic.time, updateTime: Date.now() },
        duration: this.GlobalMusic.duration
      })
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `setAVPlaybackState error: [${err.code}] ${err.message}`)
      if (err.code === 5400102) {
        // 尝试重新激活 Session
        this.session.activate().catch(() => {})
      }
    }
  }

  RegisterControlCommand() {
    try {
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
      this.session?.activate()
    } catch (error) {
      const err = error as BusinessError
      hilog.error(0x0000, "HOMO", `RegisterControlCommand or activate error: ${err.message}`)
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
