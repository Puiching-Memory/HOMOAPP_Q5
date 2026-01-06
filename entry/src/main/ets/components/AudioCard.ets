import { AudioItem } from '../model/AudioModel';

/**
 * 自定义音频卡片组件
 * 封装音频项的展示和交互逻辑
 */
@Component
export struct AudioCard {
  // 音频数据
  @Prop item: AudioItem = new AudioItem();
  // 播放状态
  @Prop isPlaying: boolean = false;
  // 音量
  @Prop volume: number = 0.5;

  // 事件回调
  onPlay: () => void = () => {};
  onStop: () => void = () => {};
  onVolumeChange: (value: number) => void = () => {};

  // 内部状态
  @State private expanded: boolean = false;
  @State private localVolume: number = 0.5;

  aboutToAppear() {
    this.localVolume = this.volume;
  }

  build() {
    Column() {
      // 主行：播放按钮和名称
      Row({ space: 12 }) {
        // 播放/暂停按钮
        Button() {
          SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.start_window_background')])
        }
        .width(44)
        .height(44)
        .type(ButtonType.Circle)
        .backgroundColor(this.isPlaying ? '#FF6B6B' : '#4CAF50')
        .onClick(() => this.onPlay())
        // 添加缩放动画
        .scale({ x: this.isPlaying ? 1.1 : 1.0, y: this.isPlaying ? 1.1 : 1.0 })
        .animation({ duration: 200 })

        // 名称和音量指示
        Column({ space: 6 }) {
          Text(this.item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)

          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.speaker_wave_2'))
              .fontSize(12)
              .fontColor([this.getVolumeColor()])
            Text(`${Math.round(this.volume * 100)}%`)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 展开/收起按钮
        Button() {
          SymbolGlyph(this.expanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width(32)
        .height(32)
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.expanded = !this.expanded;
        })
      }
      .width('100%')
      .padding(14)

      // 展开面板：音量控制和停止按钮
      if (this.expanded) {
        Column({ space: 12 }) {
          // 音量滑块
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.speaker_wave_2'))
              .fontSize(16)
              .fontColor([$r('app.color.text_secondary')])
            Slider({
              value: this.localVolume * 100,
              min: 0,
              max: 100,
              step: 1
            })
              .layoutWeight(1)
              .blockColor('#5CD6FF')
              .trackColor('#27518B')
              .selectedColor('#5CD6FF')
              .onChange((value: number) => {
                this.localVolume = value / 100;
                this.onVolumeChange(this.localVolume);
              })
          }

          // 停止按钮
          Button('停止播放')
            .width('100%')
            .height(36)
            .fontSize(14)
            .backgroundColor('#FF6B6B')
            .fontColor(Color.White)
            .onClick(() => this.onStop())
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 14 })
        // 展开动画
        .transition({ type: TransitionType.Insert, opacity: 0, translate: { y: -10 } })
        .transition({ type: TransitionType.Delete, opacity: 0, translate: { y: -10 } })
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(16)
    .clip(true)
    .animation({ duration: 300 })
  }

  private getVolumeColor(): ResourceColor {
    if (this.volume === 0) {
      return $r('app.color.text_secondary');
    } else if (this.volume < 0.5) {
      return '#4CAF50';
    } else {
      return '#5CD6FF';
    }
  }
}