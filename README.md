# Mass

**明日方舟 · 塞壬唱片 桌面音乐播放器** — Qt 6 / QML · Windows

把塞壬唱片的全部专辑搬进桌面：纸质网格底、等宽字标签、直角描边的「莱茵生命终端」风格。
除在线曲库外还支持本地文件、歌单、播放历史、逐行歌词翻译与桌面歌词。

当前版本 **1.3.2**

---

## 界面

| 曲库索引 | 专辑详情 |
| --- | --- |
| ![](docs/screenshots/01-library.png) | ![](docs/screenshots/02-album.png) |

| 全屏播放器（逐行歌词 + 译文） | 音乐检索 |
| --- | --- |
| ![](docs/screenshots/03-player.png) | ![](docs/screenshots/04-search.png) |

| 设置 → 主题色 | 桌面歌词 |
| --- | --- |
| ![](docs/screenshots/05-settings-accent.png) | ![](docs/screenshots/06-desktop-lyric.png) |

托盘菜单同样跟随主题与主题色：

![](docs/screenshots/07-tray.png)

---

## 功能

### 曲库与播放

- **发现音乐**：内置 Monster Siren API 服务，扫描塞壬唱片全量专辑，网格索引 + 专辑详情（曲目表、发行日期、时长）。
- **音乐检索**：按专辑名 / 艺人搜索，接口不可用时自动回退到本地曲库匹配，结果直接进入详情或播放。
- **我的音乐**：自建歌单，可重命名、排序、批量移除；播放队列可从任意页面唤出。
- **本地文件**：导入 `mp3 / flac / wav / m4a / ogg / aac / opus`，读取标签与内嵌封面。
- **播放历史**：按时间倒序记录，支持一键重播与清空。
- **播放模式**：顺序 / 单曲循环 / 列表循环 / 随机。

### 歌词

- 逐行滚动歌词，当前行高亮，前后行按距离衰减；切歌自动对齐时间轴。
- **译文**：优先取官方中文翻译，缺失时走机器翻译（MyMemory 免费，或自填 DeepL Key），可在全屏播放器里用 `T` 单独开关。
- **歌词包**：翻译结果可导出为 JSON 分享，也能导入他人的包；导入后离线可用。
- **桌面歌词**：两种样式可选 —— **终端横条**（贴边细条，`LYRIC` 角标、可拖动锁定）与 **唱片散字**（全屏透明、点击穿透；逐字浮现、金色投影、随机倾斜与轻微抖动，围着一枚缓慢旋转的黑胶散开，参考 Limbuslikelrc 的风格）。

### 外观

- 亮色 / 暗色 / 跟随系统三档主题。
- **主题色**：8 个预设色 + 色相 / 饱和度 / 明度三滑杆 + `#RRGGBB` 直接输入，全站同步（页签、滑杆、播放键、进度条、托盘菜单、桌面歌词）。强调色上的文字颜色按底色亮度自动取黑或白。
- 自定义背景图（放进背景文件夹后自动识别）、界面字号缩放、播放条隐藏触发高度。
- 全屏播放器带鼓点脉冲：实时节拍检测驱动封面缩放与背景提亮。
- 系统托盘菜单同样套用主题与主题色，含播放控制、桌面歌词开关、退出。

### 工程细节

- **单实例**：第二个进程会把已有窗口拉到前台；启动前清理残留的 3000 端口占用。
- **播放缓存**：在线音频下载后经 ffmpeg 转码为 mp3 落盘，封面 / 歌词 / API 响应走 HTTP 磁盘缓存，上限与清空都在设置里。
- 托盘与主窗口共用一套 `Theme` token，切换主题即时重绘，无需重启。

---

## 快捷键

| 按键 | 功能 | 按键 | 功能 |
| --- | --- | --- | --- |
| `Space` | 播放 / 暂停 | `F` | 全屏播放器 |
| `A` / `D` | 上一首 / 下一首 | `G` | 播放队列 |
| `←` / `→` | 后退 / 前进 5 秒 | `Q` | 加入歌单 |
| `↑` / `↓` | 音量 ±5% | `E` | 下载当前曲目 |
| `L` | 歌词开关（全屏） | `T` | 译文开关（全屏） |
| `Ctrl+L` | 桌面歌词开关 | `Esc` | 返回 / 关闭弹层 |

输入框聚焦时，除 `Esc` 外的快捷键均不拦截。

---

## 安装

从 [Releases](../../releases) 下载 `Mass_Setup_<版本>.exe`，双击安装（按用户目录安装，无需管理员权限，可创建桌面快捷方式）。
安装包已内置 Qt 运行时、便携 Node 与 ffmpeg，无需另外配置环境。

> 升级时按 AppId 自动覆盖安装；旧版本的用户数据（设置、缓存）保留。

---

## 从源码构建

### 依赖

| 组件 | 版本 / 说明 |
| --- | --- |
| Qt | 6.11.x，模块 Core / Gui / Widgets / Quick / QuickControls2 / Network / Multimedia / ShaderTools |
| 编译器 | MinGW 13.1（与 Qt 套件同源） |
| CMake | 3.24+ |
| Node.js | 18+，用于构建本地 API 服务 |
| ffmpeg | 单个 `ffmpeg.exe`，用于音频转码与封面处理 |
| Inno Setup | 7.x，仅打包安装程序时需要 |

### 编译

```bash
cmake -S . -B build -G "MinGW Makefiles" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH=C:/Qt/6.11.2/mingw_64
cmake --build build -j 8
```

### 准备随包资源

```bash
# 1) 本地 API 服务（Monster Siren 数据）
cd server
npm install
npm run build          # 产出 server/dist/server.js
# 把便携 node.exe 放到 server/node.exe，运行时由主程序拉起

# 2) ffmpeg
# 把 ffmpeg.exe 放到 build/ffmpeg.exe（打包脚本会复制到 dist 根目录）
```

### 调试用截图钩子

```bash
./build/ArknightsMusicPlayer.exe --snapshot --page=settings --category=appearance --out=shot.png
```

`--page` 可取任意页面名（`siren` / `search` / `playlist` / `local` / `history` / `settings` / `player`），
配合 `--category=`（`appearance` / `playback` / `translate` / `download` / `storage` / `about`）定位设置分区；
另有 `siren-detail` / `player-demo` / `search-demo` / `playlist-demo` 几个带假数据的演示页。该钩子只服务于开发，正式发布可整段移除。

---

## 打包发布

```powershell
# 生成 dist/（windeployqt + 裁剪多余 Qt 样式 + 复制 server / ffmpeg）
.\make-dist.ps1

# 编译安装包 → dist_installer\Mass_Setup_<版本>.exe
& "C:\Program Files\Inno Setup 7\ISCC.exe" setup.iss
```

发版本时三处版本号需同步修改（安装包与文件属性都读这些值）：

1. `CMakeLists.txt` — `APP_VERSION` 与 `APP_VERSION_WIN`
2. `src/Settings.h` — `kCurrentVersion`（关于页与更新检查）
3. `setup.iss` — `MyAppVersion`

安装向导的左栏图与右上角方块标记在 `installer/`，由 `art.qml` 用 Qt 渲染（配色与字距跟主界面同源）：

```bash
qml installer/art.qml --output-dir=installer
for n in wizard-100 wizard-200 wizard-small-100 wizard-small-200; do
  ffmpeg -y -i installer/$n.png -pix_fmt bgr24 installer/$n.bmp
done
```

图里的版本号（`MASS / 1.3.1`）要跟着发版手改 `art.qml`。

应用图标同样由 Qt 渲染（纸底 + 橄榄描边 + 等宽 `M` + 底部色条），7 个尺寸打包成 `icon.ico`：

```bash
qml installer/icon.qml --output-dir=installer
python installer/make-ico.py installer icon.ico
cp icon.ico resources/app.ico
```

改完图标要重编主程序（RC 与 qrc 都会重新嵌入），再重新打包安装程序。

---

## 项目结构

```
ArknightsMusicPlayer/
├─ main.cpp                 应用入口：单实例、拉起 API 服务、注册上下文对象
├─ Main.qml                 全局壳：标题栏 / 页面路由 / 播放条 / 快捷键 / 主题绑定
├─ qml/
│  ├─ Theme.qml             设计 token（配色、字号、间距、强调色派生）
│  ├─ TitleBar.qml          顶部页签导航与窗口按钮
│  ├─ SirenPage.qml         曲库索引与专辑详情
│  ├─ SearchPage.qml        音乐检索
│  ├─ PlaylistPage.qml      歌单与本地文件列表
│  ├─ LocalPage.qml         本地文件导入
│  ├─ HistoryPage.qml       播放历史
│  ├─ SettingsPage.qml      设置（外观 / 播放 / 翻译 / 下载 / 存储 / 关于）
│  ├─ FullPlayer.qml        全屏播放器（歌词舞台）
│  ├─ PlayerBar.qml         底部播放条
│  ├─ DesktopLyric.qml      桌面歌词独立窗口
│  ├─ PlaylistPanel.qml     播放队列
│  ├─ LiquidGlass.qml       液态玻璃着色器封装
│  └─ TechSwitch.qml        直角开关等基础控件
├─ src/
│  ├─ NetworkManager.*      塞壬唱片 API + 网易云搜索 / 歌词
│  ├─ AudioEngine.*         QMediaPlayer 封装、进度、节拍事件
│  ├─ BeatDetector.*        实时采样做节拍检测
│  ├─ StreamAudioPlayer.*   流式播放与缓冲
│  ├─ AudioCache.*          在线音频落盘与 ffmpeg 转码
│  ├─ CoverCache.*          封面缓存
│  ├─ AudioMetadataProbe.*  本地文件标签 / 内嵌封面解析
│  ├─ TranslationService.*  歌词翻译与歌词包导入导出
│  ├─ PlaylistManager.*     歌单持久化
│  ├─ HistoryManager.*      播放历史
│  ├─ SystemTrayManager.*   托盘图标与菜单
│  └─ Settings.*            设置读写、版本检查、目录管理
├─ shaders/                 液态玻璃 GLSL（编译为 .qsb）
└─ server/                  Monster Siren API（Node + TypeScript，便携 node 内嵌）
```

---

## 数据位置

| 内容 | 路径 |
| --- | --- |
| 缓存、下载、背景图、日志 | `%LOCALAPPDATA%\Mass\` |
| 应用设置（主题、音量、播放模式等） | `HKCU\Software\ArknightsMusicPlayer\settings\` |
| 安装目录 | `%LOCALAPPDATA%\Programs\Mass\` |

清理缓存可在「设置 → 存储」中按类型（音频 / 封面与歌词 / 全部）单独清空。

---

## 常见问题

**首次启动白屏或列表加载慢？**
本地 API 服务需要几秒启动。程序会等待服务就绪后再拉取专辑列表，稍等即可，不用重启。

**点歌后一直「加载中」？**
在线音频要先下载再转码，通常 10–15 秒。这段时间拖进度条会打断缓冲，等它自己开始播放。

**翻译没出来？**
先确认网络；再在「设置 → 翻译」里换后端（MyMemory 免费额度每日约 5 千字符，DeepL 需自填 Key）。
已经是官方中译的曲目不会重复翻译。

**换了主题色，托盘菜单没变？**
菜单在每次弹出时按当前设置重新上色，重新打开一次即可。

**和旧版本共存？**
不会。AppId 相同，安装新版本会自动卸载旧版本，用户数据保留。

---

## 致谢与声明

- 曲库数据来自 [MonsterSirenApi](https://github.com/QingXia-Ela/MonsterSirenApi)，本地服务基于该项目构建。
- 界面风格参照 [Rhine-Music-Database](https://github.com/MikeQu223/Rhine-Music-Database) 的「莱茵生命终端」设计语言。
- 基于 Qt 6（LGPLv3）构建；ffmpeg 遵循其各自的许可协议。

本项目仅供学习与个人使用。音乐、封面、歌词的版权归 **塞壬唱片（Monster Siren Records）/ 鹰角网络** 所有，请勿用于任何商业用途。
