@Entry
@Component
export struct AboutPage {
  @StorageLink('versionName') versionName: string = '1.0.0';
  @StorageLink('buildInfo') buildInfo: string = '2024';

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('关于')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 40, bottom: 24 })

      // 应用图标和名称
      Column({ space: 16 }) {
        Image($r('app.media.startIcon'))
          .width(80)
          .height(80)
          .borderRadius(16)
          .shadow({ radius: 20, color: '#5CD6FF', offsetY: 5 })

        Text('白噪音')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text(`版本 ${this.versionName}`)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .padding({ top: 40, bottom: 40 })

      // 功能特性列表
      Column({ space: 16 }) {
        this.FeatureItem('自定义ArkUI组件', $r('sys.symbol.square_grid_2x2'))
        this.FeatureItem('页面路由与导航', $r('sys.symbol.pin'))
        this.FeatureItem('动画效果', $r('sys.symbol.circle_fill'))
        this.FeatureItem('网络请求', $r('sys.symbol.wifi'))
        this.FeatureItem('JSON数据解析', $r('sys.symbol.doc_text'))
        this.FeatureItem('音频播放', $r('sys.symbol.music'))
      }
      .padding(24)
      .alignItems(HorizontalAlign.Start)

      // 底部信息
      Column({ space: 8 }) {
        Text('HarmonyOS 白噪音应用')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text(`构建时间: ${this.buildInfo}`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .padding({ top: 60, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  FeatureItem(name: string, icon: Resource) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([$r('app.color.primary_accent')])
      Text(name)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(12)
  }
}