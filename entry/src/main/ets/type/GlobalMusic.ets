import { SongItemType } from "./SongItemType"

@ObservedV2
export class GlobalMusic {
  @Trace img: string = ""  // 音乐封面
  @Trace name: string = ""  // 音乐名称
  @Trace author: string = ""  // 作者
  @Trace url: string = ""  // 当前播放链接
  @Trace time: number = 0  // 播放时间
  @Trace duration: number = 0  // 音乐的播放时长
  @Trace isPlay: boolean = false
  @Trace isLoading: boolean = false
  @Trace volume: number = 0.5
  @Trace playbackStatus: "单曲循环" | "随机播放" | "顺序播放" = "顺序播放"
  @Trace currentMusic: number = 0
  @Trace isShowPlayBar: boolean = false
  @Trace isBarCollapsed: boolean = false // 新增：播放条折叠状态
  @Trace waveform: number[] = [] // 新增：音频波形包络数据
  @Trace isLoudnessBalanced: boolean = false // 新增：响度均衡开关
  @Trace playList: SongItemType[] = []
}
