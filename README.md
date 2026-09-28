# WorkMode · 模式启动器

一个常驻 macOS 菜单栏的小工具。点一下右上角 ⚡️，选「工作模式」或「娱乐模式」，一键把该模式下的应用全部打开。

## 特性

- **一键启动**：一个模式一次点开所有工作相关应用，不用一个个手动点
- **自动跳过已运行**：已经打开的应用不会重复启动，菜单里用 ✓ 标出
- **单个也能开**：模式里点某个应用就只启动它
- **模式可配置**：自由增删模式、改名字和 emoji 图标，每个模式配自己的应用清单
- **开机自启**：默认开启，首次启动自动加入登录项，菜单里随时关掉
- **不窥探**：首次启动只生成两个空模式，不会去扫描你装了什么软件
- **原生轻量**：Swift + AppKit 写的菜单栏应用，不占 Dock，无 Electron 那类运行时

## 下载安装

到 [Releases](../../releases) 页面下载最新的 `WorkMode-x.y.z.dmg`：

1. 双击打开 dmg，把 `WorkMode.app` 拖到 `Applications`
2. 首次启动会被 macOS 拦截（因为没有付费开发者签名），在 Finder 里**右键 `WorkMode.app` → 打开**即可
3. 右上角出现 ⚡️，点开就能用

更完整的说明见 dmg 里的 `安装说明.md`。

## 从源码构建

只需要 Xcode（或 Command Line Tools），不需要打开 Xcode 工程：

```bash
./build.sh              # 编译 universal 版（arm64 + x86_64）到 dist/
./build.sh --package    # 编译并产出可分发的 dmg
./build.sh --arch=arm64 # 只编一个架构

open dist/WorkMode.app  # 运行
```

其他脚本：

```bash
./Scripts/bump_version.sh 1.1.0   # 升版本号（同时递增 build 号）
./Scripts/reset.sh                # 恢复「刚拿到安装包」的干净状态，方便反复测试
./Scripts/reset.sh --simulate-download  # 连「首次启动被拦截」一起复现
```

命令行开关（方便脚本化）：

```bash
dist/WorkMode.app/Contents/MacOS/WorkMode --autostart-status  # 查开机自启状态
dist/WorkMode.app/Contents/MacOS/WorkMode --autostart-on
dist/WorkMode.app/Contents/MacOS/WorkMode --autostart-off
```

## 目录结构

```
Sources/     Swift 源码（AppKit 菜单栏应用）
  main.swift                 入口 + 命令行开关
  Model.swift                数据模型与默认配置
  ConfigStore.swift          配置读写（JSON）
  Launcher.swift             应用启动与运行状态判断
  MenuBarController.swift    菜单栏菜单
  SettingsViewController.swift / CellViews.swift   设置界面
  LoginItem.swift            开机自启（SMAppService + LaunchAgent 兜底）
Resources/  Info.plist、安装说明
Scripts/    图标生成、版本升级、测试复位脚本
build.sh    编译打包入口
```

## 配置存在哪

`~/Library/Application Support/WorkMode/modes.json`

纯文本 JSON，可以直接编辑、备份、同步。卸载时删掉这个目录即可完全清除。

## 发布新版本

```bash
./Scripts/bump_version.sh 1.1.0
git add -A && git commit -m "chore: bump version to 1.1.0"
git tag v1.1.0
git push && git push --tags
```

打上 `v*` 标签推送后，GitHub Actions 会自动编译 universal 版、打包 dmg 并创建 Release。

## 许可

MIT，见 [LICENSE](LICENSE)。
