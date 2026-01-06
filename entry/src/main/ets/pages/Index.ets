import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import media from '@ohos.multimedia.media';
import { AudioItem, PlayerState } from '../model/AudioModel';
import { AudioCard } from '../components/AudioCard';
import { StatusCard, QuickActionCard } from '../components/StatusCard';
import { AboutPage } from './AboutPage';
import { SettingsPage } from './SettingsPage';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State audioList: Array<AudioItem> = [];
  @State isLoading: boolean = true;
  @State sessionStatus: string = '选择要播放的音频';
  @State activeAudioId: number = -1;

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
      this.activeAudioId = -1;
      this.sessionStatus = `已暂停: ${item.name}`;
    } else {
      if (state && state.player) {
        await state.player.play();
        state.isPlaying = true;
        this.activeAudioId = item.id;
      } else {
        await this.createPlayer(item);
        this.activeAudioId = item.id;
      }
      this.sessionStatus = `正在播放: ${item.name}`;
    }
  }

  async stop(item: AudioItem): Promise<void> {
    const state = this.players.get(item.id);
    if (state && state.player) {
      await state.player.stop();
      await state.player.release();
      this.players.delete(item.id);
      if (this.activeAudioId === item.id) {
        this.activeAudioId = -1;
      }
      this.sessionStatus = `已停止: ${item.name}`;
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
        console.error(`[AudioPlayer] Stop error: ${e}`);
      }
      result = entries.next();
    }
    this.players.clear();
    this.activeAudioId = -1;
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
    Tabs({ barPosition: BarPosition.End }) {
      // Tab 1: 首页
      TabContent() {
        this.HomeTab()
      }
      .tabBar(this.TabBarItem('首页', $r('sys.symbol.house'), 0))

      // Tab 2: 音频播放
      TabContent() {
        this.AudioTab()
      }
      .tabBar(this.TabBarItem('播放', $r('sys.symbol.music'), 1))

      // Tab 3: 设置
      TabContent() {
        SettingsPage()
      }
      .tabBar(this.TabBarItem('设置', $r('sys.symbol.gearshape'), 2))

      // Tab 4: 关于
      TabContent() {
        AboutPage()
      }
      .tabBar(this.TabBarItem('关于', $r('sys.symbol.info_circle'), 3))
    }
    .barWidth('100%')
    .barHeight(56)
    .barBackgroundColor($r('app.color.surface_card'))
    .onChange((index: number): void => {
      this.currentTab = index;
    })
    .animationDuration(300)
  }

  @Builder
  HomeTab(): void {
    Column() {
      // 顶部标题
      Row() {
        Text('白噪音')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button('停止全部')
          .onClick(() => { this.stopAll() })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 40, bottom: 16 })

      // 状态卡片
      StatusCard({
        title: '播放状态',
        status: this.sessionStatus,
        icon: $r('sys.symbol.music'),
        statusColor: this.activeAudioId >= 0 ? '#4CAF50' : '#A2B9D8',
        showAction: true,
        actionText: '管理播放',
        onAction: () => {
          this.currentTab = 1;
        }
      })
      .padding({ left: 24, right: 24, bottom: 16 })

      // 快捷操作
      Text('快捷操作')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 12 })

      Row({ space: 12 }) {
        QuickActionCard({
          title: '全部暂停',
          description: '暂停所有正在播放的音频',
          icon: $r('sys.symbol.pause_circle'),
          onCardClick: () => {
            this.stopAll();
          }
        })
        .layoutWeight(1)

        QuickActionCard({
          title: '随机播放',
          description: '随机选择一个音频播放',
          icon: $r('sys.symbol.shuffle'),
          badge: 'New',
          onCardClick: () => {
            if (this.audioList.length > 0) {
              const randomIndex = Math.floor(Math.random() * this.audioList.length);
              this.togglePlay(this.audioList[randomIndex]);
            }
          }
        })
        .layoutWeight(1)
      }
      .padding({ left: 24, right: 24, bottom: 16 })
      .width('100%')

      // 音频列表预览
      Text('已加载音频')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 12 })

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.audioList.slice(0, 5), (item: AudioItem): void => {
              this.QuickAudioItem(item)
            }, (item: AudioItem): string => `${item.id}`)
          }
          .padding(24)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  AudioTab(): void {
    Column() {
      Row() {
        Text('音频播放')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button('停止全部')
          .onClick(() => { this.stopAll() })
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
            ForEach(this.audioList, (item: AudioItem): void => {
              AudioCard({
                item: item,
                isPlaying: this.activeAudioId === item.id,
                volume: this.getVolume(item.id),
                onPlay: (): void => { this.togglePlay(item) },
                onStop: (): void => { this.stop(item) },
                onVolumeChange: (value: number): void => { this.onVolumeChange(item, value) }
              })
            }, (item: AudioItem): string => `${item.id}`)
          }
          .padding(24)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  QuickAudioItem(item: AudioItem): void {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(18)
          .fontColor([$r('app.color.start_window_background')])
      }
      .width(36)
      .height(36)
      .type(ButtonType.Circle)
      .backgroundColor('#4CAF50')
      .onClick(() => { this.togglePlay(item) })

      Text(item.name)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      if (this.activeAudioId === item.id) {
        SymbolGlyph($r('sys.symbol.pause_fill'))
          .fontSize(16)
          .fontColor(['#4CAF50'])
          .animation({ duration: 500, iterations: -1 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(12)
  }

  @Builder
  TabBarItem(title: string, icon: Resource, index: number): void {
    Column({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor(this.currentTab === index ? ['#5CD6FF'] : ['#A2B9D8'])
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTab === index ? '#5CD6FF' : '#A2B9D8')
    }
    .padding({ top: 8, bottom: 8 })
    .animation({ duration: 200 })
  }

  getVolume(id: number): number {
    const state = this.players.get(id);
    return state ? state.volume : 0.5;
  }
}