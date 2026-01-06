import media from '@ohos.multimedia.media';

// 音频项
export class AudioItem {
  id: number = 0;
  name: string = '';
  url: string = '';
  icon: string = '';
}

// 播放状态枚举
export enum PlaybackState {
  IDLE,
  LOADING,
  PLAYING,
  PAUSED
}

// 播放器状态
export class PlayerState {
  player: media.AVPlayer | null = null;
  state: PlaybackState = PlaybackState.IDLE;
  isPlaying: boolean = false; // 保留旧的标识以便兼容，或者直接替换
  volume: number = 0.5;
}

// 场景模型
export class Scene {
  id: number = 0;
  name: string = '';
  description: string = '';
  coverUrl: string = '';
  tracks: Array<AudioItem> = [];
}
