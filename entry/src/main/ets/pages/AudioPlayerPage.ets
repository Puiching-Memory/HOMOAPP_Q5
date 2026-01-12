import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { AudioItem, PlaybackState } from '../model/AudioModel';
import { AudioCard } from '../components/AudioCard';
import { avPlayerManage } from '../utils/avPlayerMusic';
import { GlobalMusic } from '../type/GlobalMusic';
import { SongItemType } from '../type/SongItemType';
import { AppStorageV2 } from '@kit.ArkUI';

@Entry
@Component
struct AudioPlayerPage {
  @State audioList: Array<AudioItem> = [];
  @State isLoading: boolean = true;
  @State sessionStatus: string = '选择要播放的音频';
  private globalMusic: GlobalMusic = AppStorageV2.connect(GlobalMusic, 'GlobalMusic', () => new GlobalMusic())!;
  private readonly BASE_URL: string = 'http://10.0.2.2:8080/api/v1';
  private readonly BASE_ASSET_URL: string = 'http://10.0.2.2:8080';

  getAssetUrl(url: string | undefined): string {
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${this.BASE_ASSET_URL}${url.startsWith('/') ? '' : '/'}${url}`;
  }

  aboutToAppear(): void {
    avPlayerManage.init();
    this.loadAudioList();
  }

  aboutToDisappear(): void {
    this.stopAll();
  }

  async loadAudioList(): Promise<void> {
    try {
      const list = await this.fetchData<Array<AudioItem>>(`${this.BASE_URL}/audio`);
      if (list && Array.isArray(list)) {
        this.audioList = list;
        const playlist = list.map(item => this.toSong(item));
        this.globalMusic.playList = playlist;
        if (playlist.length > 0) {
          this.globalMusic.currentMusic = 0;
          const first = playlist[0];
          this.globalMusic.img = first.img;
          this.globalMusic.name = first.name;
          this.globalMusic.author = first.author;
          this.globalMusic.url = first.url;
        }
      }
    } catch (e) {
      console.error(`[AudioPlayer] Failed: ${JSON.stringify(e)}`);
    } finally {
      this.isLoading = false;
    }
  }

  async togglePlay(item: AudioItem): Promise<void> {
    const song = this.toSong(item);
    const current = this.globalMusic.playList[this.globalMusic.currentMusic];
    try {
      if (current && current.id === song.id) {
        avPlayerManage.stopOrContinueSong();
        this.sessionStatus = this.globalMusic.isPlay ? `正在播放: ${item.name}` : `已暂停: ${item.name}`;
      } else {
        avPlayerManage.playResources(song);
        this.sessionStatus = `正在播放: ${item.name}`;
      }
    } catch (e) {
      console.error(`[AudioPlayer] Toggle error: ${JSON.stringify(e)}`);
    }
  }

  async stop(item: AudioItem): Promise<void> {
    const current = this.globalMusic.playList[this.globalMusic.currentMusic];
    if (!current || current.id !== item.id.toString()) {
      return;
    }
    await avPlayerManage.stop();
    this.sessionStatus = `已停止: ${item.name}`;
  }

  async stopAll(): Promise<void> {
    await avPlayerManage.stop();
    this.sessionStatus = '已停止全部';
  }

  onVolumeChange(item: AudioItem, value: number): void {
    avPlayerManage.setVolume(value);
    this.globalMusic.volume = value;
    this.sessionStatus = `音量 ${Math.round(value * 100)}%`;
  }

  private async fetchData<T>(url: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const httpRequest = http.createHttp();
      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000
      }, (err: BusinessError, data: http.HttpResponse) => {
        if (!err && data.responseCode === http.ResponseCode.OK) {
          try {
            const jsonStr = data.result as string;
            const result: T = JSON.parse(jsonStr) as T;
            resolve(result);
          } catch (e) {
            reject(e);
          }
        } else {
          reject(err || new Error(`HTTP ${data.responseCode}`));
        }
        httpRequest.destroy();
      });
    });
  }

  build() {
    Column() {
      Row() {
        Text('白噪音')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button('停止全部')
          .onClick(() => this.stopAll())
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 40, bottom: 16 })

      Text(this.sessionStatus)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 16 })

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.audioList, (item: AudioItem) => {
              AudioCard({
                item: item,
                state: this.getItemState(item.id),
                volume: this.getVolume(item.id),
                onPlay: (): void => { this.togglePlay(item) },
                onStop: (): void => { this.stop(item) },
                onVolumeChange: (v: number): void => { this.onVolumeChange(item, v) }
              })
            }, (item: AudioItem) => `${item.id}`)
          }
          .padding(20)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  getItemState(id: number): PlaybackState {
    const song = this.audioList.find(a => a.id === id);
    if (!song) return PlaybackState.IDLE;
    
    if (this.globalMusic.url === this.getAssetUrl(song.url)) {
      if (this.globalMusic.isLoading) return PlaybackState.LOADING;
      return this.globalMusic.isPlay ? PlaybackState.PLAYING : PlaybackState.PAUSED;
    }
    return PlaybackState.IDLE;
  }

  getVolume(id: number): number {
    return this.globalMusic.volume;
  }

  private toSong(item: AudioItem): SongItemType {
    return {
      id: item.id.toString(),
      name: item.name,
      author: item.artist || '未知艺术家',
      img: this.getAssetUrl(item.cover_url),
      url: this.getAssetUrl(item.url)
    };
  }
}