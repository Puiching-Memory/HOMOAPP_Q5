import { AudioItem, PlaybackState } from '../model/AudioModel';

/**
 * 自定义音频卡片组件
 * 封装音频项的展示和交互逻辑
 */
@Component
export struct AudioCard {
  // 音频数据
  @Prop item: AudioItem = new AudioItem();
  // 播放状态
  @Prop state: PlaybackState = PlaybackState.IDLE;

  // 事件回调
  onPlay: () => void = () => {};
  onStop: () => void = () => {};

  // 内部状态
  @State private expanded: boolean = false;

  // 获取按钮背景色
  private getButtonColor(): string {
    switch (this.state) {
      case PlaybackState.PLAYING:
        return '#FF6B6B'; // 红色表示播放中
      case PlaybackState.LOADING:
        return '#FFD93D'; // 黄色表示加载中
      case PlaybackState.PAUSED:
        return '#4CAF50'; // 绿色表示暂停
      default:
        return '#4CAF50'; // 默认绿色
    }
  }

  // 获取按钮图标
  private getButtonIcon(): Resource {
    switch (this.state) {
      case PlaybackState.PLAYING:
        return $r('sys.symbol.pause_fill');
      case PlaybackState.LOADING:
        return $r('sys.symbol.arrow_clockwise');
      default:
        return $r('sys.symbol.play_fill');
    }
  }

  build() {
    Column() {
      // 主行：播放按钮和名称
      Row({ space: 12 }) {
        // 播放/暂停按钮
        Button() {
          SymbolGlyph(this.getButtonIcon())
            .fontSize(22)
            .fontColor([$r('app.color.start_window_background')])
            // 为加载状态添加选择动画
            .rotate({ angle: this.state === PlaybackState.LOADING ? 360 : 0 })
            .animation(this.state === PlaybackState.LOADING ? {
              duration: 1000,
              iterations: -1,
              curve: Curve.Linear
            } : { duration: 0 })
        }
        .width(44)
        .height(44)
        .type(ButtonType.Circle)
        .backgroundColor(this.getButtonColor())
        .onClick(() => {
          this.getUIContext()?.animateTo({ duration: 300 }, () => {
            this.onPlay();
          });
        })
        // 添加缩放动画
        .scale({ 
          x: this.state === PlaybackState.PLAYING ? 1.1 : 1.0, 
          y: this.state === PlaybackState.PLAYING ? 1.1 : 1.0 
        })
        .shadow(this.state === PlaybackState.PLAYING ? {
          radius: 10,
          color: '#40FF6B6B',
          offsetX: 0,
          offsetY: 4
        } : { radius: 0 })
        .animation({ duration: 200 })

        // 名称和音量指示
        Column({ space: 4 }) {
          Text(this.item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          
          Text(this.item.artist || '环境白噪音')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Start)
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

      // 展开面板：停止按钮
      if (this.expanded) {
        Column({ space: 12 }) {
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
}