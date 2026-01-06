import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import media from '@ohos.multimedia.media';
import { AudioItem, PlayerState, PlaybackState } from '../model/AudioModel';
import { AudioCard } from '../components/AudioCard';

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
    try {
      if (state && state.state === PlaybackState.PLAYING && state.player) {
        await state.player.pause();
        state.state = PlaybackState.PAUSED;
        state.isPlaying = false;
        this.sessionStatus = `已暂停: ${item.name}`;
      } else if (state && state.state === PlaybackState.PAUSED && state.player) {
        await state.player.play();
        state.state = PlaybackState.PLAYING;
        state.isPlaying = true;
        this.sessionStatus = `正在播放: ${item.name}`;
      } else if (!state || state.state === PlaybackState.IDLE) {
        await this.createPlayer(item);
        this.sessionStatus = `正在加载: ${item.name}`;
      }
    } catch (e) {
      console.error(`[AudioPlayer] Toggle error: ${JSON.stringify(e)}`);
    }
  }

  async stop(item: AudioItem): Promise<void> {
    const state = this.players.get(item.id);
    try {
      if (state && state.player) {
        await state.player.stop();
        await state.player.release();
        this.players.delete(item.id);
        this.sessionStatus = `已停止: ${item.name}`;
      }
    } catch (e) {
      console.error(`[AudioPlayer] Stop error: ${JSON.stringify(e)}`);
    }
  }

  async stopAll(): Promise<void> {
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
        console.error(`[AudioPlayer] Stop all error: ${JSON.stringify(e)}`);
      }
      result = entries.next();
    }
    this.players.clear();
    this.sessionStatus = '已停止全部';
  }

  onVolumeChange(item: AudioItem, value: number): void {
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

      const playerState = new PlayerState();
      playerState.player = avPlayer;
      playerState.state = PlaybackState.LOADING;
      playerState.isPlaying = false;
      playerState.volume = 0.5;
      this.players.set(item.id, playerState);

      avPlayer.on('stateChange', (state: media.AVPlayerState): void => {
        if (state === 'prepared') {
          avPlayer.play();
          playerState.state = PlaybackState.PLAYING;
          playerState.isPlaying = true;
          this.sessionStatus = `正在播放: ${item.name}`;
        }
      });

      avPlayer.on('error', (err: BusinessError): void => {
        console.error(`[AudioPlayer] ${item.name} error: ${JSON.stringify(err)}`);
        this.players.delete(item.id);
      });

      avPlayer.url = url;
      avPlayer.loop = true;
      avPlayer.setVolume(0.5);

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
    const state = this.players.get(id);
    return state ? state.state : PlaybackState.IDLE;
  }

  getVolume(id: number): number {
    const state = this.players.get(id);
    return state ? state.volume : 0.5;
  }
}