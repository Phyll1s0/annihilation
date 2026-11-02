# 界面资源

当前视觉直接参考作者的 Neutronic：深灰背景、三层滚动点阵、细字重标题、薄荷绿交互、线框图标与透明数字关卡格。

- background/dotgrid-*.webp 复制自原作 frontend/src/assets/dotgrid/JS-dotGrid-{0,1,2}.webp。保留源文件，Godot 导入限制为 2048 像素并生成 mipmap，控制运行时开销与缩小时的闪烁。背景采用对应的 screen 混合、图案尺寸和滚动周期。
- Poppins-ExtraLight.ttf、Poppins-Regular.ttf 和 Electrolize-Regular.ttf 来自 Google Fonts 官方字体仓库。英文标题使用 Poppins 200 字重，步数与完成状态使用 Electrolize；中文回退到系统字体。对应 OFL 文件随资源与导出包保留。
- 线框图标和 GitHub 图标来自原作使用的 Ionicons 7.1.0。将默认图标颜色设为白色，悬停时由 Godot 着色为薄荷绿，许可见 icons/LICENSE.txt。
- toggle-*.svg 与 icon.svg 为 GRAY 的矢量资源。
