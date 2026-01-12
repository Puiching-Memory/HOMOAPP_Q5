import { GlobalMusic } from '../type/GlobalMusic';
import { AppStorageV2 } from '@kit.ArkUI';
import { avPlayerManage } from '../utils/avPlayerMusic';

/**
 * 音乐播放控制条
 * 提供进度显示、控制以及简单的响度可视化动画
 */
@ComponentV2
export struct MusicPlayerBar {
  private globalMusic: GlobalMusic = AppStorageV2.connect(GlobalMusic, 'GlobalMusic', () => new GlobalMusic())!;
  
  // 增加频域可视化的数据点数量
  @Local private barHeights: number[] = new Array(24).fill(6);
  private timerId: number = -1;

  aboutToAppear() {
    this.startAnimation();
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
  }

  // 简单的模拟动画
  private startAnimation() {
    this.timerId = setInterval(() => {
      this.barHeights = this.barHeights.map((_, index) => this.getBarHeight(index));
    }, 120); // 稍微加快刷新率更流畅
  }

  // 获取当前的动态高度
  private getBarHeight(index: number): number {
    // 基础高度 6vp，确保无论如何都能看到一点
    const BASE_H = 6;
    
    if (!this.globalMusic.isPlay && !this.globalMusic.isLoading) {
      return BASE_H;
    }

    // 如果在加载中，显示一种特定的跳动
    if (this.globalMusic.isLoading) {
      return BASE_H + Math.abs(Math.sin(Date.now() / 200 + index)) * 10;
    }

    // 如果有真实的频谱/波形数据
    if (this.globalMusic.waveform && this.globalMusic.waveform.length > 0) {
      const len = this.globalMusic.waveform.length;
      const progress = this.globalMusic.duration > 0 ? (this.globalMusic.time / this.globalMusic.duration) : 0;
      const centerIndex = Math.floor(progress * len);
      
      const offset = index - Math.floor(this.barHeights.length / 2);
      const targetIndex = (centerIndex + offset + len) % len;
      const waveformValue = this.globalMusic.waveform[targetIndex] || 0.1;
      
      const enhancedValue = Math.pow(waveformValue, 1.2);
      const flicker = Math.random() * 4;
      return BASE_H + enhancedValue * 22 + flicker;
    }

    // 回退方案：随机跳动
    return BASE_H + Math.random() * 12;
  }

  // 格式化时间
  private formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      // 整体卡片容器，增加边距和投影
      Column() {
        // 1. 顶部加载/进度指示器 (折叠时显示为极细线条)
        if (this.globalMusic.isBarCollapsed) {
          Progress({
            value: this.globalMusic.time,
            total: this.globalMusic.duration,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(2)
            .color('#5CD6FF')
            .backgroundColor('#1A355E')
            .transition({ type: TransitionType.All, opacity: 0 })
        }

        // 2. 顶部切换手柄，增加交互面积
        Row() {
          Rect()
            .width(32)
            .height(4)
            .radius(2)
            .fill($r('app.color.text_secondary'))
            .opacity(0.3)
        }
        .width('100%')
        .height(20)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.getUIContext()?.animateTo({ duration: 400, curve: Curve.FastOutSlowIn }, () => {
            this.globalMusic.isBarCollapsed = !this.globalMusic.isBarCollapsed;
          })
        })

        // 3. 内容主体
        Row() {
          // 左侧：封面与歌曲信息区域 (占据绝大部分空间)
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              Image(this.globalMusic.img || $r('app.media.startIcon'))
                .width(this.globalMusic.isBarCollapsed ? 42 : 56)
                .height(this.globalMusic.isBarCollapsed ? 42 : 56)
                .borderRadius(this.globalMusic.isBarCollapsed ? 8 : 12)
                .animation({ duration: 400 })
              
              if (this.globalMusic.isLoading) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#5CD6FF')
              }
            }
            
            Column({ space: 4 }) {
              Text(this.globalMusic.name || '未在播放')
                .fontSize(this.globalMusic.isBarCollapsed ? 14 : 17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              
              Text(this.globalMusic.author || '环境白噪音')
                .fontSize(this.globalMusic.isBarCollapsed ? 11 : 13)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1) // 确保文字区域可以自适应撑开
          }
          .layoutWeight(1)

          // 右侧：控制按钮组 (保持固定宽度)
          Row({ space: this.globalMusic.isBarCollapsed ? 8 : 14 }) {
            if (!this.globalMusic.isBarCollapsed) {
              SymbolGlyph($r('sys.symbol.backward_end_fill'))
                .fontSize(22)
                .fontColor(['#5CD6FF'])
                .onClick(() => avPlayerManage.preSong())
                .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.5, y: 0.5 })))
            }

            // 播放/暂停按钮
            Stack() {
              Circle()
                .width(this.globalMusic.isBarCollapsed ? 38 : 44)
                .height(this.globalMusic.isBarCollapsed ? 38 : 44)
                .fill('#1A355E')
                .opacity(0.6)
              
              SymbolGlyph(this.globalMusic.isPlay ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                .fontSize(this.globalMusic.isBarCollapsed ? 22 : 26)
                .fontColor(['#5CD6FF'])
            }
            .onClick(() => avPlayerManage.stopOrContinueSong())

            if (!this.globalMusic.isBarCollapsed) {
              SymbolGlyph($r('sys.symbol.forward_end_fill'))
                .fontSize(22)
                .fontColor(['#5CD6FF'])
                .onClick(() => avPlayerManage.nextSong())
                .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.5, y: 0.5 })))
            }
          }
          .margin({ left: 8 })
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: this.globalMusic.isBarCollapsed ? 12 : 10 })

        // 4. 展开状态下的视觉增强区 (波形图和进度条)
        if (!this.globalMusic.isBarCollapsed) {
          Column() {
            // 将波形图移到这里，居中显示，不干扰文字
            Row({ space: 3 }) {
              ForEach(this.barHeights, (h: number, index: number) => {
                Rect()
                  .width(2.5)
                  .height(h * 0.7) // 稍微调矮一点，作为视觉点缀
                  .fill('#5CD6FF')
                  .opacity(index % 2 === 0 ? 0.5 : 0.3)
                  .radius(1.5)
              }, (h: number, index: number) => `exp_bar_${index}_${h}`)
            }
            .width('100%')
            .height(26)
            .justifyContent(FlexAlign.Center)
            .margin({ top: 4, bottom: 4 })
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.8, y: 0.8 })))

            Slider({
              value: this.globalMusic.time,
              min: 0,
              max: this.globalMusic.duration,
              style: SliderStyle.OutSet
            })
              .width('100%')
              .blockColor('#5CD6FF')
              .selectedColor('#5CD6FF')
              .trackColor('#27518B')
              .trackThickness(4)
              .padding({ left: 10, right: 10 })
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.End) {
                  avPlayerManage.jumpToPlay(value);
                }
              })
            
            Row() {
              Text(this.formatTime(this.globalMusic.time))
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
              Blank()
              Text(this.formatTime(this.globalMusic.duration))
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ left: 14, right: 14, bottom: 12 })
          }
          .padding({ left: 4, right: 4 })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP)),
            TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP))
          ))
        }
      }
      .backgroundColor($r('app.color.surface_card'))
      .backgroundBlurStyle(BlurStyle.Thin)
      .borderRadius(this.globalMusic.isBarCollapsed ? 20 : 32)
      .borderWidth(1)
      .borderColor($r('app.color.surface_card_border'))
      .shadow({
        radius: 20,
        color: 'rgba(0,0,0,0.4)',
        offsetX: 0,
        offsetY: 8
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 8 })
  }
}
