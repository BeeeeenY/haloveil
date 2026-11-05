# 安装 HaloVeil · 光幕

[English](INSTALL.md) · [简体中文](INSTALL.zh-CN.md)

## 下载

下载本项目提供的 **[HaloVeil-1.0.0.zip](../downloads/HaloVeil-1.0.0.zip?raw=true)**。如果项目之后创建 GitHub Release，下载其中同名的安装包即可；GitHub 自动生成的「Source code」压缩包是源码。

使用 macOS 的归档实用工具解压，保持 `.saver` 软件包完整，不要进入 Contents 目录单独安装里面的文件。直接安装 `.saver` 不需要 Xcode、Python、网页服务器或 Wallpaper Engine。

## 安装后在 Other 中切换

1. 双击 **HaloVeil.saver**。
2. macOS 提示时选择 **「仅为此用户安装 / Install for this user」**；安装给所有用户可能需要管理员密码。
3. 打开 **「苹果菜单 → 系统设置 → 屏幕保护程序」**。
4. 向下滚动至 **「其他 / Other」**，点击 **HaloVeil** 切换为当前屏保。
5. 如果该 macOS 版本将屏保放在墙纸设置中，路径为 **「系统设置 → 墙纸 → 屏幕保护程序 → 自定 / Custom → 其他 / Other → HaloVeil」**。
6. 点击全屏 **「预览 / Preview」**，或在 **「桌面与程序坞 → 触发角」** 配置启动屏幕保护程序。

**安装文件不等于已经切换屏保，请务必在 Other 中选中 HaloVeil。** 如果之前使用 HALOFLUX，HaloVeil 是独立的新选项，需要主动选择。

启动时先有短暂深色准备画面，再淡入动画。移动鼠标或按键退出，需要密码时按系统提示正常解锁；密码要求与时间仍由 macOS 控制。

## 看不到 HaloVeil

- 完全退出并重新打开系统设置，再滚动到 Other。
- 确认下载并解压的是安装包，而不是源码包。
- 通常的用户安装位置是 `~/Library/Screen Savers/HaloVeil.saver`。在 Finder 中选择 **「前往 → 前往文件夹」**，输入 `~/Library/Screen Savers/`。必要时将完整的 `.saver` 放入该目录，再重开系统设置。

编译目标为 macOS 12 及以上，适配版已在 Sonoma 14.4.1 测试；不同 macOS 版本的设置布局可能不同。可参考 Apple 的[屏保设置说明](https://support.apple.com/en-mn/guide/mac-help/-mchlp1227/mac)及[从墙纸进入屏保的说明](https://support.apple.com/en-my/guide/mac-help/-mchl4b68853d/mac)。

## 系统安全提示

安装包采用本地签名，**未经 Apple 公证**，下载后系统可能要求确认或阻止打开。请根据实际提示核对来源；本项目不要求关闭系统安全保护。

## 更新

退出正在播放的屏保并关闭系统设置，安装新版完整 `.saver`。如果系统提示替换，确认替换后重开设置，并再次选择 **「其他 / Other → HaloVeil」**。不要将不同版本的网页或程序文件混装进同一个包，屏保会检查资源一致性。

网页资源位于屏保包内，移动源码项目不会影响已经安装的副本。

## 卸载

先切换到其他屏保并退出系统设置，在 Finder 中移除 `~/Library/Screen Savers/HaloVeil.saver`。如果安装给了所有用户，文件可能位于 `/Library/Screen Savers/`，移除时可能需要管理员密码。

## 不安装也能预览

打开下载包中的 **HaloVeil Preview.app**，即可在普通窗口运行同一个屏保。关闭窗口或退出 App 即停止。窗口预览不能替代全屏、锁屏环境的性能验证。

## 许可与署名

基于 **HALOFLUX by Ryder191（RYDER CODE / Ms MAIKEBAIs CAT）** 修改 — <https://github.com/Ryder191/haloflux>。

仅限非商业用途，完整条款见 [LICENSE](../LICENSE) 与 [NOTICE](../NOTICE)。
