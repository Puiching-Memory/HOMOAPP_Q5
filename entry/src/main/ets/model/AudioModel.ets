import media from '@ohos.multimedia.media';

// 音频项
export class AudioItem {
  id: number = 0;
  name: string = '';
  url: string = '';
  artist: string = '未知艺术家';
  cover_url: string = '';
}

// 轮播图
export class Banner {
  url: string = '';
}

// 推荐项
export class Recommendation {
  id: number = 0;
  img: string = '';
  title: string = '';
  count: string = '';
}

// 动态信息
export class Moment {
  id: number = 0;
  author: string = '';
  avatar: string = '';
  content: string = '';
  comment: number = 0;
  like: number = 0;
  song: AudioItem = new AudioItem();
}

// 播放状态枚举
export enum PlaybackState {
  IDLE,
  LOADING,
  PLAYING,
  PAUSED
}

// 场景模型
export class Scene {
  id: number = 0;
  name: string = '';
  description: string = '';
  coverUrl: string = '';
  tracks: Array<AudioItem> = [];
}
