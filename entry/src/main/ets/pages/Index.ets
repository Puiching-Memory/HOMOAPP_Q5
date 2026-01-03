import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

class FocusTrack {
  id: number = 0;
  sceneId: number = 0;
  name: string = '';
  audioUrl: string = '';
  defaultVolume: number = 0.5;
}

class FocusScene {
  id: number = 0;
  name: string = '';
  description: string = '';
  coverUrl: string = '';
  atmosphere: string = '';
  tracks: Array<FocusTrack> = [];
}

class PresetTrackRef {
  trackId: number = 0;
  volume: number = 0.5;
}

class Preset {
  id: number = 0;
  name: string = '';
  sceneId: number = 0;
  tracks: Array<PresetTrackRef> = [];
}

class TrackVolumeEntry {
  trackId: number = 0;
  volume: number = 0.5;
}

const DEFAULT_SCENES: Array<FocusScene> = [
  {
    id: 1,
    name: '雨夜',
    description: '潮湿街巷与远处雷声，带来稳态的专注氛围。',
    coverUrl: '',
    atmosphere: '雨声·城市',
    tracks: [
      { id: 11, sceneId: 1, name: '微雨', audioUrl: '', defaultVolume: 0.6 },
      { id: 12, sceneId: 1, name: '雷声', audioUrl: '', defaultVolume: 0.25 },
      { id: 13, sceneId: 1, name: '街灯嗡鸣', audioUrl: '', defaultVolume: 0.35 }
    ]
  },
  {
    id: 2,
    name: '海风',
    description: '浪花与海鸟声交织的开阔感，适合长时间深度任务。',
    coverUrl: '',
    atmosphere: '海岸·风声',
    tracks: [
      { id: 21, sceneId: 2, name: '海浪', audioUrl: '', defaultVolume: 0.55 },
      { id: 22, sceneId: 2, name: '海鸟', audioUrl: '', defaultVolume: 0.25 },
      { id: 23, sceneId: 2, name: '轻风', audioUrl: '', defaultVolume: 0.45 }
    ]
  }
];

const DEFAULT_PRESETS: Array<Preset> = [
  { id: 100, name: '写作模式', sceneId: 1, tracks: [{ trackId: 11, volume: 0.7 }, { trackId: 12, volume: 0.2 }] },
  { id: 101, name: '深度专注', sceneId: 2, tracks: [{ trackId: 21, volume: 0.6 }, { trackId: 23, volume: 0.5 }] }
];

@Entry
@Component
struct Index {
  @State scenes: Array<FocusScene> = [];
  @State presets: Array<Preset> = [];
  @State selectedSceneId: number = 0;
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  @State trackVolumes: Array<TrackVolumeEntry> = [];
  @State timerSeconds: number = 0;
  @State timerRunning: boolean = false;
  @State sessionStatus: string = '准备专注';

  private timerToken?: number;
  // 模拟器访问宿主 IP 用 10.0.2.2；预览器或真机调试请根据实际情况修改
  private readonly BASE_URL: string = 'http://10.0.2.2:8080/api/v1';

  aboutToAppear() {
    console.info('[FocusStudio] Component aboutToAppear, triggering loadContent');
    this.loadContent();
  }

  aboutToDisappear() {
    console.info('[FocusStudio] Component aboutToDisappear, stopping timer');
    this.stopTimer();
  }

  async loadContent() {
    console.info(`[FocusStudio] Starting loadContent from ${this.BASE_URL}`);
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      // 1. 获取场景列表
      console.info('[FocusStudio] Fetching scenes...');
      const scenesResponse = await this.fetchData<Array<FocusScene>>(`${this.BASE_URL}/scenes`);
      this.scenes = scenesResponse;
      console.info(`[FocusStudio] Successfully loaded ${this.scenes.length} scenes`);

      // 2. 获取预设列表
      console.info('[FocusStudio] Fetching presets...');
      const presetsResponse = await this.fetchData<Array<Preset>>(`${this.BASE_URL}/presets`);
      this.presets = presetsResponse;
      console.info(`[FocusStudio] Successfully loaded ${this.presets.length} presets`);

      if (this.scenes.length > 0) {
        // 3. 获取首个场景的详细信息（包含轨道）
        console.info(`[FocusStudio] Fetching details for first scene (ID: ${this.scenes[0].id})...`);
        const firstSceneDetail = await this.fetchData<FocusScene>(`${this.BASE_URL}/scenes/${this.scenes[0].id}`);
        this.scenes[0] = firstSceneDetail;
        this.selectedSceneId = firstSceneDetail.id;
        this.trackVolumes = this.initializeVolumesFor([firstSceneDetail]);
        console.info('[FocusStudio] First scene details loaded successfully');
      }
      
      this.isLoading = false;
    } catch (err) {
      console.error(`[FocusStudio] loadContent failed: ${JSON.stringify(err)}`);
      this.errorMessage = '无法连接到服务器，请检查后端服务是否启动';
      this.isLoading = false;
      // 回退到本地默认数据
      console.warn('[FocusStudio] Falling back to local default data');
      this.scenes = DEFAULT_SCENES;
      this.presets = DEFAULT_PRESETS;
      this.selectedSceneId = DEFAULT_SCENES[0].id;
      this.trackVolumes = this.initializeVolumesFor(DEFAULT_SCENES);
    }
  }

  private async fetchData<T>(url: string): Promise<T> {
    console.info(`[FocusStudio] HTTP Request: GET ${url}`);
    return new Promise((resolve, reject) => {
      let httpRequest = http.createHttp();
      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        expectDataType: http.HttpDataType.OBJECT,
        connectTimeout: 5000, // 增加超时设置
        readTimeout: 5000
      }, (err: BusinessError, data: http.HttpResponse) => {
        if (!err && data.responseCode === http.ResponseCode.OK) {
          console.info(`[FocusStudio] HTTP Success [200]: ${url}`);
          try {
            // 兼容处理：如果结果是字符串则手动解析
            let result: T;
            if (typeof data.result === 'string') {
              console.info('[FocusStudio] Result is string, parsing JSON...');
              result = JSON.parse(data.result) as T;
            } else {
              result = data.result as T;
            }
            resolve(result);
          } catch (parseErr) {
            console.error(`[FocusStudio] JSON Parse Error: ${JSON.stringify(parseErr)}`);
            reject(parseErr);
          }
        } else {
          const errorMsg = err ? `Code: ${err.code}, Message: ${err.message}` : `HTTP Status: ${data.responseCode}`;
          console.error(`[FocusStudio] HTTP Error: ${url} | ${errorMsg}`);
          // 如果是 10.0.2.2 失败且在预览器环境，提醒用户
          if (url.includes('10.0.2.2')) {
            console.warn('[FocusStudio] Hint: If you are using Previewer, please change BASE_URL to localhost');
          }
          reject(err ? err : new Error(`HTTP Error: ${data.responseCode}`));
        }
        httpRequest.destroy();
      });
    });
  }

  initializeVolumesFor(scenes: Array<FocusScene>): Array<TrackVolumeEntry> {
    const volumes: Array<TrackVolumeEntry> = [];
    scenes.forEach((scene: FocusScene) => {
      scene.tracks.forEach((track: FocusTrack) => {
        const entry: TrackVolumeEntry = { trackId: track.id, volume: track.defaultVolume };
        volumes.push(entry);
      });
    });
    return volumes;
  }

  get activeScene(): FocusScene | null {
    const found: FocusScene | undefined = this.scenes.find((scene: FocusScene) => scene.id === this.selectedSceneId);
    if (found) {
      return found;
    }
    if (this.scenes.length > 0) {
      return this.scenes[0];
    }
    return null;
  }

  trackVolume(track: FocusTrack): number {
    const found: TrackVolumeEntry | undefined = this.trackVolumes.find((entry: TrackVolumeEntry) => entry.trackId === track.id);
    if (found) {
      return found.volume;
    }
    return track.defaultVolume;
  }

  setTrackVolume(trackId: number, value: number) {
    const next: Array<TrackVolumeEntry> = this.trackVolumes.map((entry: TrackVolumeEntry) => {
      if (entry.trackId === trackId) {
        return { trackId: entry.trackId, volume: value };
      }
      return entry;
    });
    const exists: boolean = next.some((entry: TrackVolumeEntry) => entry.trackId === trackId);
    if (!exists) {
      next.push({ trackId, volume: value });
    }
    this.trackVolumes = next;
  }

  async selectScene(sceneId: number) {
    this.selectedSceneId = sceneId;
    
    // 尝试从后端获取该场景的详细轨道信息
    try {
      const sceneDetail = await this.fetchData<FocusScene>(`${this.BASE_URL}/scenes/${sceneId}`);
      // 更新本地场景列表中的详细信息
      this.scenes = this.scenes.map(s => s.id === sceneId ? sceneDetail : s);
      
      // 初始化新场景的音量
      const newVolumes = this.initializeVolumesFor([sceneDetail]);
      // 合并音量设置（保留已有的，添加新的）
      newVolumes.forEach(v => {
        if (!this.trackVolumes.some(tv => tv.trackId === v.trackId)) {
          this.trackVolumes.push(v);
        }
      });
    } catch (err) {
      console.error('Failed to fetch scene details', err);
    }

    const sceneName: string = this.activeScene ? this.activeScene.name : '场景';
    this.sessionStatus = `已切换至 ${sceneName}`;
  }

  async applyPreset(preset: Preset) {
    await this.selectScene(preset.sceneId);
    preset.tracks.forEach((trackRef: PresetTrackRef) => {
      this.setTrackVolume(trackRef.trackId, trackRef.volume);
    });
    this.sessionStatus = `应用预设：${preset.name}`;
  }

  adjustTrack(track: FocusTrack, delta: number) {
    const current: number = this.trackVolume(track);
    const next: number = Math.max(0, Math.min(1, current + delta));
    const normalized: number = Math.round(next * 100) / 100;
    this.setTrackVolume(track.id, normalized);
  }

  startTimer(minutes: number) {
    if (!this.activeScene) {
      this.sessionStatus = '请先等待场景加载';
      return;
    }
    this.stopTimer();
    this.timerSeconds = minutes * 60;
    this.timerRunning = true;
    this.sessionStatus = `专注 ${minutes} 分钟`;
    this.timerToken = setInterval(() => {
      this.timerSeconds = Math.max(0, this.timerSeconds - 1);
      if (this.timerSeconds <= 0) {
        this.stopTimer();
        this.sessionStatus = '专注时段完成';
        this.recordSession(minutes);
      }
    }, 1000);
  }

  private async recordSession(minutes: number) {
    try {
      let httpRequest = http.createHttp();
      await httpRequest.request(`${this.BASE_URL}/listening-session`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: {
          sceneId: this.selectedSceneId,
          durationMinutes: minutes
        }
      });
      httpRequest.destroy();
    } catch (err) {
      console.error('Failed to record session', err);
    }
  }

  stopTimer() {
    if (this.timerToken !== undefined) {
      clearInterval(this.timerToken);
      this.timerToken = undefined;
    }
    this.timerRunning = false;
  }

  formatTimer(): string {
    const minutes: number = Math.floor(this.timerSeconds / 60);
    const seconds: number = this.timerSeconds % 60;
    const pad = (value: number) => (value < 10 ? `0${value}` : `${value}`);
    return `${pad(minutes)}:${pad(seconds)}`;
  }

  isSceneActive(scene: FocusScene): boolean {
    return scene.id === this.selectedSceneId;
  }

  volumePercent(track: FocusTrack): string {
    return `${Math.round(this.trackVolume(track) * 100)}%`;
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // Header / Top App Bar
        Row() {
          Column() {
            Text('Focus Studio')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('打造你的专属专注空间')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          // Profile/Settings Placeholder
          Circle({ width: 40, height: 40 })
            .fill($r('app.color.surface_card'))
            .overlay('JD', { align: Alignment.Center, offset: { x: 0, y: 0 } })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 40, bottom: 20 })

        Scroll() {
          Column() {
            if (this.isLoading) {
              Column() {
                LoadingProgress()
                  .width(48)
                  .height(48)
                  .color($r('app.color.primary_accent'))
                Text('正在加载专注空间...')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 16 })
              }
              .width('100%')
              .height(400)
              .justifyContent(FlexAlign.Center)
            } else if (this.errorMessage.length > 0) {
              Column() {
                Text('出错了')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text(this.errorMessage)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 8 })
                Button('重试')
                  .margin({ top: 24 })
                  .onClick(() => this.loadContent())
              }
              .width('100%')
              .height(400)
              .justifyContent(FlexAlign.Center)
            } else {
              // Timer Card (Material 3 Elevated Card)
              Column() {
                Row() {
                  Column() {
                    Text(this.timerRunning ? '正在专注' : '准备就绪')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.primary_accent'))
                      .letterSpacing(1.2)
                    
                    Text(this.timerRunning ? this.formatTimer() : '25:00')
                      .fontSize(56)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                      .margin({ top: 8 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  
                  Blank()
                  
                  if (this.timerRunning) {
                    Button() {
                      SymbolGlyph($r('sys.symbol.pause_fill'))
                        .fontSize(24)
                        .fontColor([Color.White])
                    }
                    .type(ButtonType.Circle)
                    .width(64)
                    .height(64)
                    .backgroundColor('#FF4D4F')
                    .onClick(() => this.stopTimer())
                  } else {
                    Button() {
                      SymbolGlyph($r('sys.symbol.play_fill'))
                        .fontSize(24)
                        .fontColor([$r('app.color.start_window_background')])
                    }
                    .type(ButtonType.Circle)
                    .width(64)
                    .height(64)
                    .backgroundColor($r('app.color.primary_accent'))
                    .onClick(() => this.startTimer(25))
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Text(this.sessionStatus)
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 16 })
                  .width('100%')
              }
              .width('100%')
              .padding(24)
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius(32)
              .margin({ bottom: 24 })

              // Scene Selection (Horizontal List)
              Row() {
                Text('场景氛围')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text('查看全部')
                  .fontSize(14)
                  .fontColor($r('app.color.primary_accent'))
              }
              .width('100%')
              .margin({ bottom: 16, left: 4, right: 4 })

              List({ space: 16 }) {
                ForEach(this.scenes, (scene: FocusScene) => {
                  ListItem() {
                    Column() {
                      Text(scene.name)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.isSceneActive(scene) ? $r('app.color.primary_accent') : $r('app.color.text_primary'))
                      Text(scene.atmosphere)
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ top: 4 })
                    }
                    .width(160)
                    .height(100)
                    .padding(20)
                    .backgroundColor(this.isSceneActive(scene) ? $r('app.color.surface_card_border') : $r('app.color.surface_card'))
                    .borderRadius(24)
                    .border({ 
                      width: this.isSceneActive(scene) ? 2 : 0, 
                      color: $r('app.color.primary_accent') 
                    })
                    .onClick(() => this.selectScene(scene.id))
                    .alignItems(HorizontalAlign.Start)
                    .justifyContent(FlexAlign.End)
                  }
                }, (scene: FocusScene) => `${scene.id}`)
              }
              .listDirection(Axis.Horizontal)
              .height(110)
              .width('100%')
              .margin({ bottom: 32 })

              // Track Mixer
              if (this.activeScene) {
                Text('轨道混音')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
                  .margin({ bottom: 16, left: 4 })

                Column() {
                  ForEach(this.activeScene.tracks, (track: FocusTrack) => {
                    Column() {
                      Row() {
                        Text(track.name)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.text_primary'))
                        Blank()
                        Text(this.volumePercent(track))
                          .fontSize(14)
                          .fontColor($r('app.color.primary_accent'))
                      }
                      .width('100%')
                      .margin({ bottom: 8 })

                      Slider({ value: this.trackVolume(track) * 100, min: 0, max: 100 })
                        .width('100%')
                        .selectedColor($r('app.color.primary_accent'))
                        .trackColor($r('app.color.surface_card_border'))
                        .blockColor($r('app.color.primary_accent'))
                        .onChange((value: number) => {
                          this.setTrackVolume(track.id, value / 100)
                        })
                    }
                    .margin({ bottom: 20 })
                  }, (track: FocusTrack) => `${track.id}`)
                }
                .width('100%')
                .padding(24)
                .backgroundColor($r('app.color.surface_card'))
                .borderRadius(32)
                .margin({ bottom: 32 })
              }

              // Presets (Chips)
              Text('预设模式')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .margin({ bottom: 16, left: 4 })

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.presets, (preset: Preset) => {
                  Button(preset.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .backgroundColor($r('app.color.surface_card'))
                    .padding({ left: 24, right: 24, top: 12, bottom: 12 })
                    .margin({ right: 12, bottom: 12 })
                    .borderRadius(16)
                    .onClick(() => this.applyPreset(preset))
                }, (preset: Preset) => `${preset.id}`)
              }
              .margin({ bottom: 120 })
            }
          }
          .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.start_window_background'))

      // Floating Action Button (M3 Style)
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(28)
          .fontColor([$r('app.color.start_window_background')])
      }
      .width(64)
      .height(64)
      .backgroundColor($r('app.color.primary_accent'))
      .margin({ right: 24, bottom: 32 })
      .shadow({ radius: 20, color: '#60000000', offsetX: 0, offsetY: 8 })
      .onClick(() => {
        // Action for adding custom preset or scene
      })
    }
  }
}