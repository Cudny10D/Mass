# Mass

> 一个基于 Qt 6 + QML 的塞壬唱片（Monster Siren Records）音乐播放器

<p align="center">
  <img src="https://img.shields.io/badge/Qt-6.5%2B-brightgreen?logo=qt" alt="Qt 6">
  <img src="https://img.shields.io/badge/C%2B%2B-17-blue?logo=c%2B%2B" alt="C++17">
  <img src="https://img.shields.io/badge/Platform-Windows-lightgrey?logo=windows" alt="Windows">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License"> </p><p align="center"> <img src="docs/screenshot-main.png" width="720" alt="主界面"> </p>
</p>

---

## ✨ 功能

- 🎵 **在线播放** — 流式加载塞壬唱片全部专辑，无需等待完整下载
- 🎨 **沉浸式界面** — 无边框窗口、磨砂玻璃、圆角卡片，支持深浅色主题
- 🖼️ **专辑浏览** — 专辑网格、歌曲列表、专辑详情
- 🔍 **搜索** — 支持专辑名、艺术家模糊搜索，带搜索历史
- 📜 **歌词** — 逐行滚动歌词，自动翻译（日/英 → 中）
- 💿 **歌单** — 创建、编辑、管理自定义歌单
- 🕘 **播放历史** — 自动记录最近播放
- ⬇️ **下载** — 保存到本地并自动写入封面、艺术家等元数据
- 🎧 **系统托盘** — 关闭到托盘、托盘菜单快速操作
- 🎬 **全屏播放器** — 旋转封面、可滚动歌词、右键分享/复制
- 🌗 **深浅色主题** — 平滑过渡动画
- 🔄 **自动更新** — 检查 GitHub Releases 获取新版本

---

## 📸 截图

| 主界面 | 全屏播放器 |
|:---:|:---:|
| ![主界面]<img width="1231" height="809" alt="QQ_1790847121500" src="https://github.com/user-attachments/assets/8453ab84-1183-4181-8b0c-613f49568784" />
| ![全屏播放器]<img width="1230" height="809" alt="QQ_1790847172701" src="https://github.com/user-attachments/assets/3329c977-ba3c-43a3-b64a-f928eac18f67" />
|

| 搜索 | 歌单 |
|:---:|:---:|
| ![搜索]<img width="1229" height="809" alt="QQ_1790847196376" src="https://github.com/user-attachments/assets/0d905667-d406-417d-9b21-b22d41bd51f1" />
| ![歌单]<img width="1228" height="809" alt="QQ_1790847216302" src="https://github.com/user-attachments/assets/3e6a139f-7d5a-491d-b487-f003cc613396" />
|

---

## 🛠 技术栈

| 层 | 技术 |
|---|---|
| UI | Qt Quick / QML（Basic Style） |
| 后端 | Qt 6（Core / Gui / Quick / QuickControls2 / Network / Multimedia） |
| 音频 | QMediaPlayer（FFmpeg 后端） + 自研 WAV 流式播放器 |
| API | [MonsterSirenApi](https://github.com/QingXia-Ela/MonsterSirenApi)（Node.js + Express） |
| 构建 | CMake 3.24+ / MinGW 13.1 |
| 打包 | windeployqt + Inno Setup |

---

## 📦 依赖

- **Qt 6.5 或更高版本**（建议 6.8+）
  - 模块：`Core` `Gui` `Widgets` `Quick` `QuickControls2` `Network` `Multimedia`
- **CMake 3.24+**
- **MinGW 13.1** 或 MSVC 2022
- **FFmpeg**（用于音频转码和元数据写入）
- **Node.js 便携版**（可选，API 服务）

---

## 🚀 构建

### 1. 克隆仓库

```bash
git clone https://github.com/Cudny/ArknightsMusicPlayer.git
cd ArknightsMusicPlayer
```

### 2. 准备 API 服务

把 [MonsterSirenApi](https://github.com/QingXia-Ela/MonsterSirenApi) 编译好的产物 + Node.js 便携版放到项目根目录的 `server/` 下：

```
server/
├── node.exe              # Node.js 便携版（从 nodejs.org 下载）
├── package.json
├── dist/                 # 编译后的 API 代码
│   └── server.js
└── node_modules/         # 生产依赖
```

### 3. 准备 FFmpeg

下载 [FFmpeg](https://github.com/BtbN/FFmpeg-Builds/releases)，把 `ffmpeg.exe` 放到项目根目录。

### 4. 编译

```bash
mkdir build && cd build
cmake .. -G "MinGW Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="C:/Qt/6.8.0/mingw_64"
cmake --build . -j8
```

### 5. 部署 Qt 依赖

```bash
C:/Qt/6.8.0/mingw_64/bin/windeployqt.exe \
    --release \
    --qmldir ../qml \
    --no-translations \
    ArknightsMusicPlayer.exe
```

### 6. 运行

双击 `build/ArknightsMusicPlayer.exe`，或者用脚本生成完整分发目录：

```powershell
cd ..
powershell -ExecutionPolicy Bypass -File make-dist.ps1
```

---

## 📥 下载安装

从 [Releases](https://github.com/Cudny/ArknightsMusicPlayer/releases) 页面下载最新的 `Mass_Setup_x.y.z.exe`，双击安装。

**系统要求**：Windows 10 / 11 64 位

---

## 📂 项目结构

```
ArknightsMusicPlayer/
├── CMakeLists.txt
├── main.cpp
├── icon.ico
├── resources/
│   └── app.ico
├── src/                    # C++ 后端
│   ├── AudioEngine.*       # 音频引擎（QMediaPlayer + StreamAudioPlayer）
│   ├── StreamAudioPlayer.* # 自研 WAV 流式播放器
│   ├── AudioCache.*        # 音频缓存 / 下载 / 转码
│   ├── AudioMetadataProbe.*# 音频元数据探测
│   ├── CoverCache.*        # 封面缓存
│   ├── NetworkManager.*    # API 请求
│   ├── TranslationService.*# 歌词翻译
│   ├── Settings.*          # 设置持久化
│   ├── HistoryManager.*    # 播放历史
│   ├── PlaylistManager.*   # 歌单管理
│   └── SystemTrayManager.* # 系统托盘
├── qml/                    # QML 前端
│   ├── Main.qml
│   ├── Theme.qml           # 主题单例
│   ├── TitleBar.qml
│   ├── SideBar.qml
│   ├── SirenPage.qml       # 塞壬唱片页
│   ├── SearchPage.qml      # 搜索页
│   ├── HistoryPage.qml     # 历史页
│   ├── PlaylistPage.qml    # 歌单页
│   ├── SettingsPage.qml    # 设置页
│   ├── PlayerBar.qml       # 底部播放栏
│   ├── FullPlayer.qml      # 全屏播放器
│   ├── PlaylistPanel.qml   # 播放列表面板
│   └── PlaylistPickerDialog.qml
├── server/                 # 便携版 Node + API
├── setup.iss               # Inno Setup 安装包脚本
└── make-dist.ps1           # 打包脚本
```

---

## ⚙️ 配置

设置面板中可调整：

- **外观** — 深色/浅色模式、字体大小
- **播放** — 歌词翻译开关
- **下载** — 保存目录
- **关闭设置** — 关闭时最小化到托盘 / 退出应用
- **存储** — 音频缓存、图片缓存大小，一键清空
- **关于** — 检查更新、当前版本

设置保存在 `%LOCALAPPDATA%\ArknightsMusicPlayer\`。

---

## 🐛 反馈

遇到问题？欢迎提 [Issue](https://github.com/Cudny/ArknightsMusicPlayer/issues)，附上：

- 日志文件：`%LOCALAPPDATA%\ArknightsMusicPlayer\player.log`
- 系统版本
- 复现步骤

---

## 🤝 致谢

- [MonsterSirenApi](https://github.com/QingXia-Ela/MonsterSirenApi) — 塞壬唱片 API
- [Qt](https://www.qt.io/) — 跨平台应用框架
- [FFmpeg](https://ffmpeg.org/) — 音视频处理
- [Inno Setup](https://jrsoftware.org/isinfo.php) — 安装包制作

---

## 📄 许可证

MIT License © 2026 [Cudny](https://github.com/Cudny)

本项目仅供学习交流使用。所有音乐版权归 [塞壬唱片 / Monster Siren Records](https://monster-siren.hypergryph.com/) 所有。

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Cudny">Cudny</a>
</p>
```

