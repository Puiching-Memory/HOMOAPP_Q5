import router from '@ohos.router';

/**
 * 状态卡片组件
 * 展示当前应用状态信息的自定义组件
 */
@Component
export struct StatusCard {
  @Prop title: string = '';
  @Prop status: string = '';
  @Prop icon: Resource = $r('sys.symbol.info_circle');
  @Prop statusColor: ResourceColor = '#5CD6FF';
  @Prop showAction: boolean = false;
  @Prop actionText: string = '查看详情';

  onAction: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      // 图标和标题
      Row({ space: 10 }) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([this.statusColor])
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 状态文本
      Text(this.status)
        .fontSize(14)
        .fontColor(this.statusColor)
        .width('100%')
        .textAlign(TextAlign.Start)

      // 操作按钮
      if (this.showAction) {
        Button(this.actionText)
          .width('100%')
          .height(36)
          .fontSize(14)
          .type(ButtonType.Capsule)
          .backgroundColor('transparent')
          .border({ width: 1, color: this.statusColor })
          .fontColor(this.statusColor)
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(16)
    .border({ width: 1, color: this.statusColor, style: BorderStyle.Dashed })
  }
}

/**
 * 快捷操作卡片组件
 */
@Component
export struct QuickActionCard {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop icon: Resource = $r('sys.symbol.star');
  @Prop badge: string = '';

  onCardClick: () => void = () => {};

  @State private isHovered: boolean = false;

  build() {
    Column({ space: 8 }) {
      // 顶部：图标和徽章
      Stack({ alignContent: Alignment.TopEnd }) {
        SymbolGlyph(this.icon)
          .fontSize(32)
          .fontColor([$r('app.color.primary_accent')])

        if (this.badge) {
          Text(this.badge)
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#FF6B6B')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
        }
      }
      .width('100%')
      .height(40)

      // 标题
      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      // 描述
      Text(this.description)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(16)
    .scale({ x: this.isHovered ? 1.02 : 1.0, y: this.isHovered ? 1.02 : 1.0 })
    .animation({ duration: 200 })
    .onClick(() => this.onCardClick())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isHovered = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isHovered = false;
      }
    })
  }
}