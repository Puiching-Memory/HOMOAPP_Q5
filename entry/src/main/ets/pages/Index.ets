import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import media from '@ohos.multimedia.media';
import { AudioItem, PlaybackState, Scene, Banner, Recommendation, Moment } from '../model/AudioModel';
import { AudioCard } from '../components/AudioCard';
import { StatusCard, QuickActionCard } from '../components/StatusCard';
import { AboutPage } from './AboutPage';
import { SettingsPage } from './SettingsPage';
import { avPlayerManage } from '../utils/avPlayerMusic';
import { GlobalMusic } from '../type/GlobalMusic';
import { SongItemType } from '../type/SongItemType';
import { AppStorageV2 } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State audioList: Array<AudioItem> = [];
  @State sceneList: Array<Scene> = [];
  @State banners: Array<Banner> = [];
  @State recommendations: Array<Recommendation> = [];
  @State moments: Array<Moment> = [];
  @State isLoading: boolean = true;
  @State isRefreshing: boolean = false;
  @State sessionStatus: string = '选择要播放的音频';
  @State activeAudioId: number = -1;
  @State timerRemaining: number = 0; // 秒
  private timerId: number = -1;

  private globalMusic: GlobalMusic = AppStorageV2.connect(GlobalMusic, 'GlobalMusic', () => new GlobalMusic())!;

  @StorageLink('defaultVolume') defaultVolume: number = 0.5;
  @StorageLink('loopPlayback') loopPlayback: boolean = true;

  private readonly BASE_URL: string = 'http://10.0.2.2:8080/api/v1';
  private readonly BASE_ASSET_URL: string = 'http://10.0.2.2:8080';

  getAssetUrl(url: string | undefined): string {
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${this.BASE_ASSET_URL}${url.startsWith('/') ? '' : '/'}${url}`;
  }

  aboutToAppear(): void {
    avPlayerManage.init();
    this.loadData();
  }

  aboutToDisappear(): void {
    this.stopAll();
  }

  private toSong(item: AudioItem): SongItemType {
    return {
      id: item.id.toString(),
      name: item.name,
      author: item.artist,
      img: this.getAssetUrl(item.cover_url),
      url: this.getAssetUrl(item.url)
    };
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

  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const results_audio = await this.fetchData<Array<AudioItem>>(`${this.BASE_URL}/audio`);
      const results_scenes = await this.fetchData<Array<Scene>>(`${this.BASE_URL}/scenes`);
      const results_banners = await this.fetchData<Array<Banner>>(`${this.BASE_URL}/banners`);
      const results_recs = await this.fetchData<Array<Recommendation>>(`${this.BASE_URL}/recommendations`);
      const results_moments = await this.fetchData<Array<Moment>>(`${this.BASE_URL}/moments`);
      
      this.audioList = results_audio || [];
      this.sceneList = results_scenes || [];
      this.banners = results_banners || [];
      this.recommendations = results_recs || [];
      this.moments = results_moments || [];
    } catch (e) {
      console.error(`[AudioPlayer] Load failed: ${JSON.stringify(e)}`);
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
        this.activeAudioId = item.id;
      }
      this.sessionStatus = this.globalMusic.isPlay ? `正在播放: ${item.name}` : `已暂停: ${item.name}`;
    } catch (e) {
      console.error(`[AudioPlayer] Toggle error: ${JSON.stringify(e)}`);
    }
  }

  async stop(item: AudioItem): Promise<void> {
    try {
      if (this.globalMusic.url === this.getAssetUrl(item.url)) {
        await avPlayerManage.stop();
        this.activeAudioId = -1;
        this.sessionStatus = `已停止: ${item.name}`;
      }
    } catch (e) {
      console.error(`[AudioPlayer] Stop error: ${JSON.stringify(e)}`);
    }
  }

  async stopAll(): Promise<void> {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
      this.timerRemaining = 0;
    }
    await avPlayerManage.stop();
    this.activeAudioId = -1;
    this.sessionStatus = '已停止全部';
  }

  onVolumeChange(item: AudioItem, value: number): void {
    avPlayerManage.setVolume(value);
    this.sessionStatus = `音量 ${Math.round(value * 100)}%`;
  }

  startSleepTimer(minutes: number): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
    this.timerRemaining = minutes * 60;
    this.sessionStatus = `定时关闭: ${minutes} 分钟后`;
    this.timerId = setInterval(() => {
      this.timerRemaining--;
      if (this.timerRemaining <= 0) {
        this.stopAll();
        this.sessionStatus = '已通过定时器停止';
      }
    }, 1000);
  }

  showTimerSelection(): void {
    this.getUIContext().showTextPickerDialog({
      range: ['15分钟', '30分钟', '45分钟', '60分钟', '取消定时'],
      onAccept: (result: TextPickerResult) => {
        if (result.index === 4) {
          if (this.timerId !== -1) {
            clearInterval(this.timerId);
            this.timerId = -1;
            this.timerRemaining = 0;
            this.sessionStatus = '已取消定时关闭';
          }
        } else {
          const minutes = [15, 30, 45, 60][result.index as number];
          this.startSleepTimer(minutes);
        }
      }
    })
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
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
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
        Text('发现')
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

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            // 轮播图
            if (this.banners.length > 0) {
            Swiper() {
              ForEach(this.banners, (banner: Banner) => {
                Image(this.getAssetUrl(banner.url))
                  .width('100%')
                  .height(180)
                  .borderRadius(16)
                  .objectFit(ImageFit.Cover)
              })
            }
            .autoPlay(true)
            .interval(4000)
            .indicator(true)
            .margin({ left: 24, right: 24, bottom: 24 })
          }

          // 推荐列表
          if (this.recommendations.length > 0) {
            Text('精选推荐')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ left: 24, right: 24, bottom: 16 })

            Column({ space: 12 }) {
              ForEach(this.recommendations, (item: Recommendation) => {
                Row({ space: 12 }) {
                  Image(this.getAssetUrl(item.img))
                    .width(90)
                    .height(90)
                    .borderRadius(12)
                  Column() {
                    Text(item.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row() {
                      SymbolGlyph($r('sys.symbol.play_circle'))
                        .fontSize(14)
                        .fontColor([$r('app.color.text_secondary')])
                      Text(`${item.count} 听过`)
                        .fontSize(13)
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ left: 4 })
                    }
                    .margin({ top: 8 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.surface_card'))
                .borderRadius(16)
              })
            }
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 24 })
          }

          // 快捷操作
          Text('快速入口')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 16 })

          Row({ space: 12 }) {
            QuickActionCard({
              title: '全部停止',
              description: '管理所有音频项',
              icon: $r('sys.symbol.stop_circle'),
              onCardClick: () => { this.stopAll(); }
            }).layoutWeight(1)

            QuickActionCard({
              title: '定时器',
              description: this.timerRemaining > 0 ? `剩${Math.floor(this.timerRemaining/60)}分` : '点击设置',
              icon: $r('sys.symbol.clock'),
              badge: this.timerRemaining > 0 ? 'ON' : '',
              onCardClick: () => { this.showTimerSelection(); }
            }).layoutWeight(1)
          }
          .padding({ left: 24, right: 24, bottom: 12 })

          // 场景推荐
          Text('环境场景')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 16, top: 12 })

          if (this.sceneList.length > 0) {
            List({ space: 12 }) {
              ForEach(this.sceneList, (scene: Scene) => {
                ListItem() {
                  this.SceneCard(scene)
                }
              }, (scene: Scene) => `${scene.id}`)
            }
            .listDirection(Axis.Horizontal)
            .height(160)
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 24 })
            .scrollBar(BarState.Off)
          }

          // 社区动态
          if (this.moments.length > 0) {
            Text('社区心声')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ left: 24, right: 24, bottom: 16 })

            Column({ space: 16 }) {
              ForEach(this.moments, (moment: Moment) => {
                Column() {
                  Row({ space: 12 }) {
                    Image(this.getAssetUrl(moment.avatar))
                      .width(40).height(40).borderRadius(20)
                    Text(moment.author)
                      .fontSize(16).fontWeight(FontWeight.Medium)
                  }
                  .width('100%')
                  .margin({ bottom: 8 })

                  Text(moment.content)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .margin({ bottom: 12 })

                  Row() {
                    SymbolGlyph($r('sys.symbol.heart'))
                      .fontSize(14).fontColor([$r('app.color.text_secondary')])
                    Text(`${moment.like}`).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 4, right: 16 })
                    SymbolGlyph($r('sys.symbol.message'))
                      .fontSize(14).fontColor([$r('app.color.text_secondary')])
                    Text(`${moment.comment}`).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 4 })
                  }
                }
                .padding(16)
                .backgroundColor($r('app.color.surface_card'))
                .borderRadius(16)
              })
            }
            .padding({ left: 24, right: 24, bottom: 40 })
          }
        }
      }
    }
      .onRefreshing(() => {
        this.loadData().then(() => {
          this.isRefreshing = false;
        });
      })
      .layoutWeight(1)
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
                state: this.getItemState(item.id),
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
  SceneCard(scene: Scene): void {
    Column() {
      Image(this.getAssetUrl(scene.coverUrl))
        .width('100%')
        .height(80)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)
        .margin({ bottom: 8 })
      Text(scene.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(scene.description)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(160)
    .padding(10)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(16)
    .onClick((): void => {
      if (scene.tracks && scene.tracks.length > 0) {
        this.togglePlay(scene.tracks[0]);
      }
    })
  }

  @Builder
  QuickAudioItem(item: AudioItem): void {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph(this.getItemState(item.id) === PlaybackState.PLAYING ? $r('sys.symbol.pause_fill') : 
          (this.getItemState(item.id) === PlaybackState.LOADING ? $r('sys.symbol.arrow_clockwise') : $r('sys.symbol.play_fill')))
          .fontSize(18)
          .fontColor([$r('app.color.start_window_background')])
          .rotate({ angle: this.getItemState(item.id) === PlaybackState.LOADING ? 360 : 0 })
          .animation(this.getItemState(item.id) === PlaybackState.LOADING ? {
            duration: 1000,
            iterations: -1,
            curve: Curve.Linear
          } : { duration: 0 })
      }
      .width(36)
      .height(36)
      .type(ButtonType.Circle)
      .backgroundColor(this.getItemState(item.id) === PlaybackState.PLAYING ? '#FF6B6B' : 
        (this.getItemState(item.id) === PlaybackState.LOADING ? '#FFD93D' : '#4CAF50'))
      .onClick((): void => { this.togglePlay(item) })

      Text(item.name)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      if (this.getItemState(item.id) === PlaybackState.PLAYING) {
        SymbolGlyph($r('sys.symbol.waveform'))
          .fontSize(16)
          .fontColor(['#4CAF50'])
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
}