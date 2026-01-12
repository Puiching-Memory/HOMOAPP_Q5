import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { AudioItem, PlaybackState } from '../model/AudioModel';
import { AudioCard } from '../components/AudioCard';
import { avPlayerManage } from '../utils/avPlayerMusic';
import { GlobalMusic } from '../type/GlobalMusic';
import { SongItemType } from '../type/SongItemType';
import { AppStorageV2 } from '@kit.ArkUI';

import { MusicPlayerBar } from '../components/MusicPlayerBar';

@ComponentV2
export struct AudioPlayerPage {
  @Local audioList: Array<AudioItem> = [];
  @Local isLoading: boolean = true;
  @Local sessionStatus: string = '选择要播放的音频';
  private globalMusic: GlobalMusic = AppStorageV2.connect(GlobalMusic, 'GlobalMusic', () => new GlobalMusic())!;
  private readonly BASE_URL: string = 'http://10.0.2.2:8080/api/v1';
  private readonly BASE_ASSET_URL: string = 'http://10.0.2.2:8080';

  getAssetUrl(url: string | undefined): string {
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${this.BASE_ASSET_URL}${url.startsWith('/') ? '' : '/'}${url}`;
  }

  aboutToAppear(): void {
    this.loadAudioList();
  }

  async loadAudioList(): Promise<void> {
    try {
      const list = await this.fetchData<Array<AudioItem>>(`${this.BASE_URL}/audio`);
      if (list && Array.isArray(list)) {
        this.audioList = list;
        const playlist: Array<SongItemType> = list.map((item: AudioItem): SongItemType => {
          return this.toSong(item);
        });
        this.globalMusic.playList = playlist;
      }
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[AudioPlayer] Failed: ${JSON.stringify(err)}`);
    } finally {
      this.isLoading = false;
    }
  }

  async togglePlay(item: AudioItem): Promise<void> {
    const song = this.toSong(item);
    try {
      if (this.globalMusic.url === song.url) {
        avPlayerManage.stopOrContinueSong();
      } else {
        avPlayerManage.playResources(song);
      }
      this.sessionStatus = this.globalMusic.isPlay ? `正在播放: ${item.name}` : `已暂停: ${item.name}`;
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[AudioPlayer] Toggle error: ${JSON.stringify(err)}`);
    }
  }

  async stop(item: AudioItem): Promise<void> {
    if (this.globalMusic.url === this.getAssetUrl(item.url)) {
      await avPlayerManage.stop();
      this.sessionStatus = `已停止: ${item.name}`;
    }
  }

  async stopAll(): Promise<void> {
    await avPlayerManage.stop();
    this.sessionStatus = '已停止全部';
  }

  onGlobalVolumeChange(value: number): void {
    avPlayerManage.setVolume(value);
    this.globalMusic.volume = value;
    this.sessionStatus = `系统音量 ${Math.round(value * 100)}%`;
  }

  private async fetchData<T>(url: string): Promise<T> {
    // ... httpRequest logic ...
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
            const err = e as BusinessError;
            reject(err);
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
      .padding({ left: 24, right: 24, top: 40, bottom: 8 })

      // 全局音量控制区域
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.speaker_wave_2'))
            .fontSize(20)
            .fontColor([$r('app.color.text_secondary')])
          
          Slider({
            value: this.globalMusic.volume * 100,
            min: 0,
            max: 100,
            step: 1
          })
          .layoutWeight(1)
          .blockColor('#5CD6FF')
          .selectedColor('#5CD6FF')
          .trackColor('#27518B')
          .onChange((value: number) => {
            this.onGlobalVolumeChange(value / 100);
          })
          
          Text(`${Math.round(this.globalMusic.volume * 100)}%`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width(40)
        }
        .width('100%')

        // 响度均衡器开关 (Loudness Equalizer)
        Row() {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.waveform_circle'))
              .fontSize(18)
              .fontColor([this.globalMusic.isLoudnessBalanced ? $r('app.color.primary_accent') : $r('app.color.text_secondary')])
            Text('智能响度均衡')
              .fontSize(14)
              .fontColor(this.globalMusic.isLoudnessBalanced ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          }
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.globalMusic.isLoudnessBalanced })
            .selectedColor($r('app.color.primary_accent'))
            .height(24)
            .onChange((isOn: boolean) => {
              avPlayerManage.toggleLoudnessBalance(isOn);
            })
        }
        .width('100%')
        .padding({ top: 4 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })

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
                onPlay: (): void => { this.togglePlay(item) },
                onStop: (): void => { this.stop(item) }
              })
            }, (item: AudioItem) => `${item.id}`)
          }
          .padding(20)
        }
        .layoutWeight(1)
      }

      // 播放控制条：只有在有歌曲播放或显示标志为真时才显示
      if (this.globalMusic.isShowPlayBar) {
        MusicPlayerBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  getItemState(id: number): PlaybackState {
    const song: AudioItem | undefined = this.audioList.find((a: AudioItem): boolean => a.id === id);
    if (!song) {
      return PlaybackState.IDLE;
    }
    
    if (this.globalMusic.url === this.getAssetUrl(song.url)) {
      if (this.globalMusic.isLoading) {
        return PlaybackState.LOADING;
      }
      return this.globalMusic.isPlay ? PlaybackState.PLAYING : PlaybackState.PAUSED;
    }
    return PlaybackState.IDLE;
  }

  private toSong(item: AudioItem): SongItemType {
    const song: SongItemType = {
      id: item.id.toString(),
      name: item.name,
      author: item.artist || '未知艺术家',
      img: this.getAssetUrl(item.cover_url),
      url: this.getAssetUrl(item.url),
      waveform: item.waveform
    };
    return song;
  }
}