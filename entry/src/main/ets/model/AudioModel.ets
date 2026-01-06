import media from '@ohos.multimedia.media';

// 音频项
export class AudioItem {
  id: number = 0;
  name: string = '';
  url: string = '';
  icon: string = '';
}

// 播放器状态
export class PlayerState {
  player: media.AVPlayer | null = null;
  isPlaying: boolean = false;
  volume: number = 0.5;
}
