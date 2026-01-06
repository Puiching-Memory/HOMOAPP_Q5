import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import media from '@ohos.multimedia.media';
import { AudioItem, PlayerState } from '../model/AudioModel';

@Entry
@Component
export struct AudioPlayerPage {
  @State audioList: Array<AudioItem> = [];
  @State isLoading: boolean = true;
  @State sessionStatus: string = '选择要播放的音频';
  @State showVolumePanel: number = -1;

  private players: Map<number, PlayerState> = new Map();
  private readonly BASE_URL: string = 'http://10.0.2.2:8080/api/v1';
  private readonly BASE_ASSET_URL: string = 'http://10.0.2.2:8080';

  aboutToAppear(): void {
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
      }
    } catch (e) {
      console.error(`[AudioPlayer] Failed: ${JSON.stringify(e)}`);
    } finally {
      this.isLoading = false;
    }
  }

  async togglePlay(item: AudioItem): Promise<void> {
    const state = this.players.get(item.id);
    if (state && state.isPlaying && state.player) {
      await state.player.pause();
      state.isPlaying = false;
      this.sessionStatus = `已暂停: ${item.name}`;
    } else {
      if (state && state.player) {
        await state.player.play();
        state.isPlaying = true;
      } else {
        await this.createPlayer(item);
      }
      this.sessionStatus = `正在播放: ${item.name}`;
    }
  }

  async stop(item: AudioItem) {
    const state = this.players.get(item.id);
    if (state && state.player) {
      await state.player.stop();
      await state.player.release();
      this.players.delete(item.id);
      this.sessionStatus = `已停止: ${item.name}`;
    }
  }

  async stopAll() {
    const entries = this.players.entries();
    let result = entries.next();
    while (!result.done) {
      const state = result.value[1];
      try {
        if (state.player) {
          await state.player.stop();
          await state.player.release();
        }
      } catch (e) {
        console.error(`[AudioPlayer] Stop error: ${e}`);
      }
      result = entries.next();
    }
    this.players.clear();
    this.sessionStatus = '已停止全部';
  }

  onVolumeChange(item: AudioItem, value: number) {
    const state = this.players.get(item.id);
    if (state && state.player) {
      state.volume = value;
      state.player.setVolume(value);
    }
  }

  private async createPlayer(item: AudioItem): Promise<void> {
    try {
      const avPlayer = await media.createAVPlayer();
      const url = item.url.startsWith('/') ? `${this.BASE_ASSET_URL}${item.url}` : item.url;

      avPlayer.on('stateChange', (state: media.AVPlayerState): void => {
        if (state === 'prepared') {
          avPlayer.play();
        }
      });

      avPlayer.on('error', (err: BusinessError): void => {
        console.error(`[AudioPlayer] ${item.name} error: ${JSON.stringify(err)}`);
      });

      avPlayer.url = url;
      avPlayer.loop = true;
      avPlayer.setVolume(0.5);

      const newState = new PlayerState();
      newState.player = avPlayer;
      newState.isPlaying = true;
      newState.volume = 0.5;
      this.players.set(item.id, newState);
    } catch (e) {
      console.error(`[AudioPlayer] Failed: ${JSON.stringify(e)}`);
    }
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
              this.AudioItemCard(item)
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

  @Builder
  AudioItemCard(item: AudioItem): void {
    Column() {
      Row() {
        Button() {
          SymbolGlyph(this.isPlayingItem(item.id) ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(24)
            .fontColor([$r('app.color.start_window_background')])
        }
        .width(48)
        .height(48)
        .type(ButtonType.Circle)
        .backgroundColor(this.isPlayingItem(item.id) ? '#FF6B6B' : '#4CAF50')
        .onClick(() => { this.togglePlay(item) })

        Column({ space: 8 }) {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)

          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.speaker_wave_2'))
              .fontSize(14)
              .fontColor([$r('app.color.text_secondary')])
            Slider({ value: this.getVolume(item.id) * 100 })
              .layoutWeight(1)
              .onChange((v: number) => {
                this.onVolumeChange(item, v / 100);
              })
          }
        }
        .layoutWeight(1)
        .padding({ left: 12, right: 12 })

        Button('停止')
          .fontSize(12)
          .onClick(() => { this.stop(item) })
      }
      .width('100%')
      .padding(16)

      if (this.showVolumePanel === item.id) {
        Column() {
          Text(`音量: ${Math.round(this.getVolume(item.id) * 100)}%`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 8 })
        }
        .transition({ type: TransitionType.Insert, opacity: 0, translate: { y: -20 } })
        .transition({ type: TransitionType.Delete, opacity: 0, translate: { y: -20 } })
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(12)
    .onClick(() => {
      this.showVolumePanel = this.showVolumePanel === item.id ? -1 : item.id;
    })
    .animation({ duration: 300 })
  }

  isPlayingItem(id: number): boolean {
    const state = this.players.get(id);
    return state ? state.isPlaying : false;
  }

  getVolume(id: number): number {
    const state = this.players.get(id);
    return state ? state.volume : 0.5;
  }
}