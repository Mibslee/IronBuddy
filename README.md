# 铁伴儿 IronBuddy

> 本地运行的 iOS 健身训练 App，基于 MediaPipe BlazePose 实时识别动作、自动计数并给出纠错建议。

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)](https://developer.apple.com/swiftui/)

## 主要功能

- 🏋️ **本地姿态识别**：MediaPipe Pose Landmarker 33 点骨架，无需联网
- 📊 **四大动作计数**：俯卧撑 / 深蹲 / 硬拉 / 卧推
- 🗣️ **实时纠错**：语音 TTS 播报动作问题（如膝内扣、髋塌陷）
- 🎙️ **离线语音指令**：SFSpeechRecognizer 中文识别 "开始/停止/下一组"
- 📹 **动作回放** (V2.0)：每次 rep 保留骨架慢动作，可 0.25x - 1.0x 回看并查看调整建议
- 🎯 **自适应强度** (V2.0)：分析 rep 时长节奏，自动建议下一组加/减量
- 🤸 **热身引导** (V2.0)：5 个动态拉伸动作，可跳过
- 🧭 **多角度识别** (V2.0)：自动判断正面/侧面/斜角拍摄
- 📱 **HealthKit 同步**：训练数据写入健康 App
- 📈 **本地数据库**：SQLite 保存历史、统计、成就

## 技术栈

| 层 | 技术 |
|----|------|
| UI | SwiftUI + Observation (`@Observable`) |
| 相机 | AVFoundation (`.resizeAspectFill`，`sessionPreset = .high`) |
| 姿态识别 | MediaPipe Tasks Vision 0.10.21 (CocoaPods) |
| 数据库 | SQLite.swift (SPM) |
| 语音 | AVSpeechSynthesizer + SFSpeechRecognizer |
| 健康 | HealthKit (`HKWorkoutBuilder`) |
| 图表 | Swift Charts |

## 运行环境

- Xcode 16+
- iOS 17+ 真机或模拟器（推荐真机，动作识别需要摄像头）
- CocoaPods (`sudo gem install cocoapods`)

## 本地启动

```bash
git clone https://github.com/<your-account>/IronBuddy.git
cd IronBuddy
pod install
open IronBuddy.xcworkspace   # ⚠️ 必须用 .xcworkspace，不要用 .xcodeproj
```

在 Xcode 中选择真机或模拟器（iPhone 15 Pro / iPhone 17 Pro 等），⌘R 运行。

### 注意事项

- **打开方式**：只能 `open IronBuddy.xcworkspace`，单独打开 `.xcodeproj` 会导致 MediaPipe 链接失败 (`framework 'Pods_IronBuddy' not found`)。
- **姿态模型**：`IronBuddy/Resources/pose_landmarker.task`（~5.8 MB，来自 Google 官方 BlazePose Lite float16）。
- **MediaPipe 版本**：固定 `0.10.21`，更高版本在部分 Xcode 下 `-lMediaPipeTasksCommon` 链接失败。

## 项目结构

```
IronBuddy/
├── IronBuddy.xcworkspace/            # 打开这个，不是 .xcodeproj
├── IronBuddy.xcodeproj/
├── Podfile, Podfile.lock
├── IronBuddy/                        # 主 App 源码
│   ├── App/                          # AppState / RootView / IronBuddyApp
│   ├── Models/                       # TrainingPlan / Achievement / ExerciseType
│   ├── Services/
│   │   ├── Camera/                   # AVFoundation 封装
│   │   ├── PoseDetector/             # MediaPipe 引擎 + 多角度检测
│   │   ├── Train/                    # TrainingController (核心)
│   │   ├── Replay/                   # 动作回放录制
│   │   ├── Adaptive/                 # 自适应强度分析
│   │   ├── Database/                 # SQLite 读写
│   │   ├── HealthKit/                # 健康 App 同步
│   │   ├── TTS/                      # 语音播报
│   │   └── Voice/                    # 语音指令
│   ├── Views/
│   │   ├── Home, Select, Prepare, Train, Confirm, Done
│   │   ├── Replay, Warmup, Plan
│   │   ├── Log, Achievement, Settings, Profile
│   │   └── Shared/                   # 通用组件
│   ├── Utilities/                    # Theme / Constants / Calorie
│   ├── Resources/                    # pose_landmarker.task
│   └── Assets.xcassets/
├── IronBuddyHelpers/                 # 本地 SPM：纯 Swift 计数器 (单元测试友好)
└── IronBuddyTests/                   # 姿态计数器单元测试
```

## V2.0 新功能一览

| 功能 | 入口 | 备注 |
|------|------|------|
| 新手/老手模式 | 设置 → 训练水平 | 老手模式只播报高伤病风险警告 |
| 热身引导 | 摄像头准备页顶部按钮 | 可跳过，设置里可全局关闭 |
| 动作回放 | 本组结束确认页 | 慢动作 0.25x-1.0x + 调整建议 |
| 自适应强度 | 本组结束确认页 | 根据 rep 时长推荐加/减量 |
| 多角度识别 | 训练页计数牌下方胶囊 | 自动显示正面/侧面/斜角 |

详情见 [`ironbuddy-dev-progress.md`](./ironbuddy-dev-progress.md)。

## 开发文档

- [作业书 v1.1](./ironbuddy-dev-guide-v1.1.md) — 最初的阶段规划
- [开发进度记录](./ironbuddy-dev-progress.md) — 每一批功能的实现细节、踩坑、交接要点

## 权限说明

App 需要以下权限，已在 Info.plist 声明：

- 📷 相机：实时姿态识别
- 🎙️ 麦克风：语音指令
- 🗣️ 语音识别：离线中文指令识别
- 🏃 HealthKit 读写：训练数据同步到健康 App

## License

MIT © 2026 Shane Studio
