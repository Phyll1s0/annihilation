# 界面资源

当前视觉以黑白消融和空位为主题。首页标记通过原生矢量绘制生成：两颗黑白圆形交叠，交集为灰色；开始入口悬停时略微靠拢。背景为静态着色器暗场，没有纹理或持续滚动。

- scripts/ui/merge_mark.gd 与 icon.svg 为 GRAY 的标记，前者支持缩放与减少动态效果设置。
- Poppins-ExtraLight.ttf、Poppins-Regular.ttf 来自 Google Fonts 官方字体仓库。字标与数字使用常规字重，章节标题使用轻字重；中文回退到系统字体。OFL 文件随资源与导出包保留。
- 通用线框图标来自 Ionicons 7.1.0，由 Godot 以灰白色着色，许可见 icons/LICENSE.txt。
- toggle-*.svg 为 GRAY 的矢量开关资源。
