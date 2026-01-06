@Entry
@Component
export struct SettingsPage {
  @StorageLink('autoPlay') autoPlay: boolean = true;
  @StorageLink('defaultVolume') defaultVolume: number = 0.5;
  @StorageLink('loopPlayback') loopPlayback: boolean = true;
  @State localVolume: number = 0.5;

  aboutToAppear(): void {
    this.localVolume = this.defaultVolume;
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('设置')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 40, bottom: 24 })

      Scroll() {
        Column({ space: 16 }) {
          // 播放设置
          SettingsSectionCard({ title: '播放设置' }) {
            Column() {
              this.SettingsToggle('自动播放', this.autoPlay, (value: boolean): void => {
                this.autoPlay = value;
              })

              this.SettingsToggle('循环播放', this.loopPlayback, (value: boolean): void => {
                this.loopPlayback = value;
              })

              this.SettingsSlider('默认音量', this.localVolume, 0, 1, (value: number): void => {
                this.localVolume = value;
                this.defaultVolume = value;
              })
            }
          }

          // 显示设置
          SettingsSectionCard({ title: '显示设置' }) {
            this.SettingsToggle('深色模式', false, (value: boolean): void => {
              // 模拟深色模式切换逻辑
              this.getUIContext().showAlertDialog({
                title: '提示',
                message: '深色模式切换成功(演示)',
                confirm: { value: '确定', action: () => {} }
              })
            })
          }

          // 关于
          SettingsSectionCard({ title: '关于' }) {
            Column() {
              this.SettingsItem('版本', '1.0.0')
              this.SettingsItem('构建号', '2024')
            }
          }
        }
        .padding(24)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  SettingsToggle(title: string, isOn: boolean, onChange: (value: boolean) => void): void {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
        .selectedColor('#5CD6FF')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  SettingsSlider(title: string, value: number, min: number, max: number, onChange: (value: number) => void): void {
    Column({ space: 8 }) {
      Row() {
        Text(title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(`${Math.round(value * 100)}%`)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }

      Slider({ value: value, min: min, max: max, step: 0.1 })
        .blockColor('#5CD6FF')
        .trackColor('#27518B')
        .selectedColor('#5CD6FF')
        .onChange((v: number) => {
          onChange(v);
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  SettingsItem(title: string, value: string): void {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}

@Component
struct SettingsSectionCard {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.defaultBuilder;

  @Builder
  defaultBuilder(): void {
  }

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_accent'))
        .width('100%')
        .padding({ left: 4, bottom: 8 })

      Column() {
        this.content()
      }
      .padding(16)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(16)
    }
  }
}
