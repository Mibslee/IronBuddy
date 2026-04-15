# IronBuddy 开发进度记录

**日期**：2026-03-31  
**用途**：交接给次日继续开发；与作业书同目录：`ironbuddy-dev-guide-v1.1.md`  
**工程根目录**：`IronBuddy/IronBuddy/`（含 `IronBuddy.xcworkspace`）

---

## 1. 当前阶段判断

| 作业书阶段 | 状态 | 说明 |
|-----------|------|------|
| Phase 0 工程骨架 | 基本完成 | SwiftUI 路由、模型/工具桩、权限文案、iOS 17、Workspace + CocoaPods |
| Phase 1 姿态管线 | 代码已落地 | 模型、引擎、计数器、相机、训练页、TTS；**尚未按作业书做「10 次误差 ≤1」实机验证** |
| Phase 2 数据与健康 | 已基本完成 | SQLite、`RestTimerView`、`CompletionView`、HealthKit 写入、历史列表与详情；见文末 2026-04-02 |

---

## 2. 环境与打开方式（必读）

- **必须用** `IronBuddy.xcworkspace` 打开并编译；单独打开 `.xcodeproj` 会导致 MediaPipe 链接失败（如 `MediaPipeTasksCommon` / `XCFrameworkIntermediates` 找不到）。
- **命令行示例**：
  ```bash
  cd /path/to/IronBuddy/IronBuddy
  xcodebuild -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'generic/platform=iOS Simulator' build
  ```
- **MediaPipe**：作业书写 SPM，实际采用 **CocoaPods**，`Podfile` 中 **`MediaPipeTasksVision` 固定 `0.10.21`**（更高版本在部分 Xcode 下 `-lMediaPipeTasksCommon` 失败）。
- **姿态模型**：`IronBuddy/Resources/pose_landmarker.task`（约 5.8MB，来自 Google 官方 lite float16）。若需纳入 Git，团队可评估 **Git LFS**。

---

## 3. Phase 0 已落实要点

- SwiftUI **10 条路由**（`AppRoute`）、`AppState`、`RootView` + `NavigationStack`。
- **SQLite.swift**：SPM 远程依赖。
- **HealthKit** 能力 + Info.plist 相机/健康用途说明；**HealthKit 写入**：`HealthKitService` 使用 **`HKWorkoutBuilder`**（`beginCollection` / `addMetadata` / `addSamples` / `finishWorkout`），**不要**在 `finishWorkout` 后再 `healthStore.save` 同一条 workout。
- **`DatabaseService`**：显式使用 **`SQLite.Connection`**，避免与 HealthKit 等模块的 `Connection` 歧义。
- **导航**：`NavigationPath` 对 `AppRoute` 使用 **`AppRoute.*` 显式类型**，避免 Swift 推断问题。
- **工程**：`FRAMEWORK_SEARCH_PATHS` 对 simulator / device 指向 Pods 内 `.xcframework` slice，缓解 DerivedData 下缺少 `XCFrameworkIntermediates` 时的链接问题。

---

## 4. Phase 1 已实现内容（代码层面）

### 4.1 MediaPipe 接入方式

- 已 **移除 Bridging Header**（曾导致测试/依赖扫描找不到 `MediaPipeTasksVision.h`）。
- 在需使用类型的 Swift 文件中使用 **`import MediaPipeTasksVision`**（引擎、代理、数学辅助、三动作计数器、`TrainingController` 等）。

### 4.2 姿态管线

- **`PoseDetectionEngine`**：`PoseLandmarker` 直播模式；**每 2 帧推理 1 次**；`MPImage(pixelBuffer:orientation:)` + `detectAsync`；从 `result.landmarks` 解析为 `[NormalizedLandmark]`。
- **`PoseStreamDelegateProxy`**：`NSObject` + `PoseLandmarkerLiveStreamDelegate`。
- **`PoseLandmarkMath` / `PoseIndex`**：归一化坐标 → `CGPoint`、可见度、角度；俯卧撑前置摄像头 **mirror-X**。
- **俯卧撑计数**：肘角状态机；过渡条件使用 **`elbowMin = min(左肘角, 右肘角)`**（与作业书「双肘/任一」一致）；低可见度重置逻辑。

### 4.3 深蹲 / 硬拉

- **`SquatCounter`**、**`DeadliftCounter`**：按作业书状态机思路实现。
- **硬拉**：6 类警告（背挺直线性、膝内扣、杠路径/髋漂移启发、头前伸、拉阶段髋铰链 vs 膝主导、起始髋过低等，含起始位低频节流）。

### 4.4 相机与训练 UI

- **`CameraService`**：`AVCaptureSession`，BGRA，`applyCameraPosition`，竖屏；俯卧撑前摄、深蹲/硬拉后摄；可切换前摄。
- **`TrainingController`**：`@Observable` + `@MainActor`；启动相机与引擎；按 `ExerciseType` 分发给对应计数器；**完成次数与硬拉警告** 走 **`LocalTTSService`**；**`UserDefaults` 键 `ttsEnabled`** 与设置一致（默认开启）。
- **`CameraPreviewView`**、**`TrainView`**：预览、次数、动作提示/风险文案、模型缺失与相机拒绝状态、切换摄像头、离开页面停止会话。
- **`AppState.trainingExercise`**；**`ActionSelectView`** 在进入训练前设置动作类型。

### 4.5 可选未完成（作业书 / 体验）

- **`PoseOverlayView` 骨架绘制**：尚未实现。
- 作业书 **§17 卧推**：当前 **`ExerciseType` / 动作列表** 中 **未包含**。

---

## 5. 测试与模块化（2026-03-31 晚）

### 5.1 问题

- `IronBuddyTests` 使用 `@testable import IronBuddy` 时，Swift 显式模块依赖会拉入 **MediaPipe**；若在测试 Target 再 **pod 一份 MediaPipe**，宿主 App 启动可能出现 **absl / MediaPipe 初始化崩溃**（测试报 `Early unexpected exit` / `absl::log_internal::LogMessage::FailWithoutStackTrace`）。

### 5.2 解决方案

- **`IronBuddyTests` 的 Podfile**：仅 **`inherit! :search_paths`**，**不要**在测试 Target 声明 `MediaPipeTasksVision`。
- 新增 **本地 Swift Package `IronBuddyHelpers`**（路径：`IronBuddy/IronBuddyHelpers/`，与 `IronBuddy.xcodeproj` 同级）：
  - `AngleCalculator`、`CalorieEstimator`（`public`）迁至此包。
  - 主 App 的 `PoseLandmarkMath`：`import IronBuddyHelpers`。
  - **`IronBuddyTests`**：`import IronBuddyHelpers` + `import Testing`，**不再** `@testable import IronBuddy`。

### 5.3 验证结果（当日）

- `xcodebuild -workspace … -scheme IronBuddy` **BUILD SUCCEEDED**。
- `test -only-testing:IronBuddyTests`：**3 个用例全部通过**（角度计算 ×2、卡路里公式 ×1）。

---

## 6. 明日建议工作顺序

1. **Phase 1 停止点（作业书）**：真机或模拟器上分别对俯卧撑 / 深蹲 / 硬拉做 **10 次重复计数**，记录 **误差是否 ≤ 1**；硬拉逐项验证 **6 类警告可触发**；把结论补记在本文件或新段落。
2. **可选**：实现 `PoseOverlayView` 骨架叠加，便于调参。
3. **Phase 2**：SQLite 训练记录闭环、从 UI 写入/读取 HealthKit、组间确认与完成页数据流。
4. 若产品需要：扩展 **`ExerciseType`** 与路由，增加 **卧推**（按作业书 §17）。

---

## 7. 关键路径速查

| 类别 | 路径或名称 |
|------|------------|
| Workspace | `IronBuddy/IronBuddy.xcworkspace` |
| 作业书 | `IronBuddy/../ironbuddy-dev-guide-v1.1.md`（与 `IronBuddy` 文件夹同级） |
| 本记录 | `IronBuddy/../ironbuddy-dev-progress-2026-03-31.md` |
| 本地 SPM（无 MediaPipe） | `IronBuddy/IronBuddyHelpers/` |
| 姿态模型 | `IronBuddy/IronBuddy/Resources/pose_landmarker.task` |
| CocoaPods | `IronBuddy/Podfile` |

---

*本文件由开发会话整理，便于次日接续；若当日另有提交，可在文末追加「修订」小节。*

---

### 2026-04-02 Phase 1 停止点验证

**环境说明（当次自动化会话）**：命令行 `xcodebuild`（`iPhone 16` / `generic/platform=iOS Simulator` / `-sdk iphonesimulator`）均失败：`Unable to find a destination` 或 `Supported platforms for the buildables in the current scheme is empty`；可见真机亦需 **iOS 26.4** 平台（Xcode → Settings → Components）。**下表须在本机装好 Simulator 或设备 SDK 后人工补测**，将「待验证」改为实测。

| 动作 | 测试次数 | 误差 | 是否通过 |
|------|---------|------|---------|
| 俯卧撑 | 10 | 待验证 | 待验证 |
| 深蹲   | 10 | 待验证 | 待验证 |
| 硬拉   | 10 | 待验证 | 待验证 |

硬拉警告触发测试（作业书 6 类，对应 `DeadliftCounter` 的 `type`：`back_rounded` / `knee_valgus` / `bar_path` / `head_forward` / `hips_too_low` / `hip_hinge`）：

| 警告类型 | 是否可触发 |
|---------|---------|
| 背不直 | 待验证 |
| 膝内扣 | 待验证 |
| 杠铃路径 | 待验证 |
| 头前伸 | 待验证 |
| 起始髋低 | 待验证 |
| 拉阶段髋铰链（膝主导提示） | 待验证 |

**编译**：当次无法在终端完成构建；请本地用 `IronBuddy.xcworkspace` 执行 **Product → Build**，或安装缺失组件后重试 `xcodebuild`。

---

### 2026-04-02 Phase 2 完成情况

| 子项 | 状态 | 说明 |
|------|------|------|
| SQLite `training_sessions` / `exercise_records` + CRUD | ✅ | `DatabaseService`：路径为 `DatabasePath.sqliteFileURL()`（App Group 优先 + `IronBuddy.sqlite`）；新增 `loadSession(id:)` |
| 组间休息 `RestTimerView` | ✅ | 可配置秒数（设置 `UserDefaultsKeys.restSecondsBetweenSets`，默认 60）、TTS + 震动、可跳过 |
| 完成页 + 写入 DB / HealthKit | ✅ | `CompletionView` 挂至路由 `.done`；保存备注、`HealthKitService.saveWorkout` 失败不阻塞 |
| HealthKit 首次授权 | ✅ | `IronBuddyApp` 中在尚未请求过时调用 `requestWorkoutWriteAuthorizationIfNeeded()` |
| 训练历史页 | ✅ | `HistoryView`（原列表文件 `LogListView.swift`）：按结束时间倒序、左滑删除、`WorkoutDetailView` 展示单次详情与各组明细 |
| 训练闭环补丁 | ✅ | 进入 `.done` 前在 `TrainView` 写入 `lastSetRepCount`；`ActionSelectView` 新训练前 `resetTrainingDraftForNewWorkout()`；`TrainView` 首次出现时记录 `trainingSessionStart`；**组间休息后** `trainingResumeCount` 驱动 `.task(id:)` 重启相机与计数（2026-04-02 修补） |

未做（仍为可选）：`PoseOverlayView` 骨架叠加、卧推（§17）。

**修改文件清单（2026-04-02）**

- `IronBuddy/App/RootView.swift` — `.done` → `CompletionView()`；`.history` → `HistoryView()`
- `IronBuddy/IronBuddyApp.swift` — HealthKit 首次授权 `task`
- `IronBuddy/Services/Database/DatabaseService.swift` — `loadSession(id:)`
- `IronBuddy/Services/HealthKit/HealthKitService.swift` — `HKWorkoutBuilder`、品牌 metadata、`basalEnergyBurned` 样本
- `IronBuddy/Services/Train/TrainingController.swift` — （Phase 1）训练控制
- `IronBuddy/Views/Select/ActionSelectView.swift` — 选动作前重置草稿
- `IronBuddy/Views/Train/TrainView.swift` — 会话开始时间、`lastSetRepCount`、`.task(id: trainingResumeCount)` 组间返回后重启管线
- `IronBuddy/Views/Train/RestTimerView.swift` — 倒计时、TTS、震动、跳过
- `IronBuddy/Views/Confirm/SetConfirmSheet.swift` — 组确认、休息、草稿组写入
- `IronBuddy/Views/Done/CompletionView.swift` — 备注写入 DB/HK
- `IronBuddy/Views/Home/HomeView.swift` — 训练历史路由、`workoutDetail(Int64)`
- `IronBuddy/Views/Done/DoneView.swift` — 路由修正（文件已不再挂主流程，仅供保留预览/自检参考时可删）
- `IronBuddy/Views/Log/LogListView.swift` — 实现为 `HistoryView`
- `IronBuddy/Views/Log/WorkoutDetailView.swift` — `Int64` + SQLite 详情
- `IronBuddy/Utilities/DatabasePath.swift` — App Group + `IronBuddy.sqlite`
- `IronBuddy/Utilities/Constants.swift` — `UserDefaultsKeys.restSecondsBetweenSets` 等
- `IronBuddy/Views/Settings/SettingsView.swift` — 组间休息秒数 Stepper（30…300，步进 15）

---

## 2026-04-03 凌晨补录（Jarvis 执行）

### iOS SDK / 模拟器修复
- Xcode iOS 26.4 平台下载安装完成（自动触发）
- iPhone 17 Pro 模拟器就绪

### HealthKitService 编译错误修复
- `HKMetadataKey.workoutBrandName.rawValue` → 改为 `HKMetadataKeyWorkoutBrandName`（Swift 端正确写法）
  - 原因：`HKMetadataKey` 在 Swift 中不是类型，而是 NSString 常量名前缀，直接用 `HKMetadataKeyWorkoutBrandName`（值为 `"HKWorkoutBrandName"`）

### 构建结果
| 命令 | 结果 |
|------|------|
| xcodebuild (iPhone 17 Pro 模拟器) | ✅ **BUILD SUCCEEDED** |

### 修改文件
- `IronBuddy/IronBuddy/Services/HealthKit/HealthKitService.swift`（1行修复）

### Cursor Agent Session 汇总（2026-04-02 晚）
- 任务 ID: `ironbuddy-ironbuddy-phase2-xcodebuild-20260402-210912`
- 修改文件:
  - `IronBuddy/IronBuddy/Views/Train/TrainView.swift`（`.task(id:)` 驱动相机重启）
  - `IronBuddy/IronBuddy/Views/Train/RestTimerView.swift`（@State 修正）
  - `IronBuddy/IronBuddy/Views/Settings/SettingsView.swift`（休息秒数 Stepper）
  - `ironbuddy-dev-progress-2026-03-31.md`（Phase 1 验证说明、硬拉 6 类表）
- Phase 1 验证：待真机/模拟器手动测试（自动化环境限制）
- Phase 2 代码层面：全部完成


---

## 2026-04-02/03 Cursor Agent Phase 2 开发（第二轮）

**日期**：2026-04-02 19:57 启动 → 2026-04-03 01:39 编译通过
**xcodebuild**：iOS 26.4 / iPhone 17 Pro Simulator → **BUILD SUCCEEDED**
**会话 ID**：ironbuddy-ironbuddy-phase2-xcodebuild-20260402-210912

### Cursor Agent 开发成果

| 模块 | 文件 | 说明 |
|------|------|------|
| DatabaseService | Services/Database/DatabaseService.swift | SQLite CRUD（training_sessions / exercise_records） |
| HealthKitService | Services/HealthKit/HealthKitService.swift | HKWorkoutBuilder 写入，basalEnergyBurned |
| RestTimerView | Views/Train/RestTimerView.swift | 组间休息倒计时（30s 提醒、结束震动+TTS） |
| CompletionView | Views/Done/CompletionView.swift | 训练完成页（保存DB + HealthKit + 汇总显示） |
| HistoryView | Views/Log/LogListView.swift | 历史训练列表（下拉刷新、左滑删除） |
| WorkoutDetailView | Views/Log/WorkoutDetailView.swift | 单次训练详情 |
| SettingsView | Views/Settings/SettingsView.swift | 新增组间休息秒数 Stepper（30-300s） |
| TrainView | Views/Train/TrainView.swift | `.task(id: trainingResumeCount)` 组间休息后相机重启 |
| DatabasePath | Utilities/DatabasePath.swift | App Group 容器优先，回退 Application Support |
| AppState | App/AppState.swift | 新增 accumulatedSessionNotes，重置时清空 |
| RootView | App/RootView.swift | done → CompletionView 路由 |
| IronBuddyApp | IronBuddyApp.swift | 启动时请求 HealthKit 写入授权 |

### 关键修复
- `SetConfirmSheet`：重量备注改为"组X 重量 Y kg"格式，累积到 accumulatedSessionNotes
- RestTimerView：关闭按钮 toolbar，避免 sheet 无法关闭
- 编译验证：iOS 26.4 SDK + iPhone 17 Pro Simulator ✅

### 仍需手动验证
- Phase 1 停止点：实机 10 次误差 ≤1（模拟器无摄像头）
- 硬拉 6 类警告触发测试

---

## 2026-04-03 IronBuddy 1.0 UI + 测试基线（Cursor Agent）

### 设计 / UI
- 新增 `Theme.swift`（主色、渐变、文字层次）；`ExerciseType` 扩展英文名、SF Symbol、训练部位文案。
- **HomeView**：去掉 Phase 0 路由自检；品牌区（哑铃图标 + 副标题）+ 渐变「开始训练」主卡片 + `NavCard` 历史 / 资料 / 设置；大标题导航「铁伴儿」。
- **ActionSelectView**：`LazyVGrid` 两列 + `ExerciseCard`；主导航隐藏系统返回键，工具栏「返回」（便于 Maestro）。
- **TrainView**：`CountDisplayView` 字号 96；姿态提示条 `ultraThinMaterial` 圆角背景。
- **HistoryView**：每条左侧动作 SF Symbol（`ExerciseType.symbolName`）。
- **SettingsView**：Section 标题「语音播报」「训练设置」；Toggle/Stepper `tint(Theme.accent)`；工具栏「返回」+ 隐藏系统返回。
- **PrimaryButton**：橙红渐变 + 半粗体；**NavCard**、**ExerciseCard** 新组件。

### 逻辑复用
- **RestTimerDisplay** 迁入 **`IronBuddyHelpers`**（`RestTimerDisplay.swift`），`RestTimerView` `import IronBuddyHelpers`；单测覆盖时钟字符串、提示文案、`normalizedTotalSeconds`。

### 单测说明（计数器 / 数据库）
- `@testable import IronBuddy` 会经计数器依赖 **MediaPipe**；若在 `IronBuddyTests` 再 pod 同名 MediaPipe，运行单测时宿主曾出现 **absl / Early unexpected exit**（与 §5.2 一致）。
- 当前 **未** 在测试 Target 增加 MediaPipe；俯卧撑/深蹲/硬拉计数器与 `DatabaseService` 的自动化用例**未合入**，待将来拆分存储模块或独立集成测后再加。

### Maestro
- 新增 `IronBuddy/maestro_tests/flow.yaml`（`appId: com.ShaneStudio.IronBuddy`）。本机若未配置 `maestro` CLI，可用 GUI 或按官方文档安装 CLI 后执行：  
  `maestro test maestro_tests/flow.yaml`（于 `IronBuddy/` 目录）。

### 构建与测试（本环境）
- `xcodebuild -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → **BUILD SUCCEEDED**
- 同上 `test` → **TEST SUCCEEDED**；单元测试含：角度 ×2、卡路里 ×1、**RestTimerDisplay ×1**（共 4）；UI 测试 6 项通过。

### 修改 / 新增文件清单（本批次）
| 路径 |
|------|
| `IronBuddy/IronBuddy/Utilities/Theme.swift`（新） |
| `IronBuddy/IronBuddy/Models/ExerciseType.swift` |
| `IronBuddy/IronBuddy/Views/Components/NavCard.swift`（新） |
| `IronBuddy/IronBuddy/Views/Components/ExerciseCard.swift`（新） |
| `IronBuddy/IronBuddy/Views/Components/PrimaryButton.swift` |
| `IronBuddy/IronBuddy/Views/Home/HomeView.swift` |
| `IronBuddy/IronBuddy/Views/Select/ActionSelectView.swift` |
| `IronBuddy/IronBuddy/Views/Train/TrainView.swift` |
| `IronBuddy/IronBuddy/Views/Train/CountDisplayView.swift` |
| `IronBuddy/IronBuddy/Views/Train/RestTimerView.swift` |
| `IronBuddy/IronBuddy/Views/Log/LogListView.swift` |
| `IronBuddy/IronBuddy/Views/Settings/SettingsView.swift` |
| `IronBuddy/IronBuddyHelpers/Sources/IronBuddyHelpers/RestTimerDisplay.swift`（新） |
| `IronBuddy/IronBuddyTests/IronBuddyTests.swift` |
| `IronBuddy/maestro_tests/flow.yaml`（新） |
| `ironbuddy-dev-progress-2026-03-31.md` |

---

## 2026-04-03 Phase 1 停止点验证（自动化会话）

**编译**：`xcodebuild -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'generic/platform=iOS Simulator,name=iPhone 16' build` → **BUILD SUCCEEDED**。

**说明**：计数误差与硬拉 6 类警告须 **真人 + 相机** 在模拟器或真机上完成；本环境无法代替。请在下表填写实测后勾选通过情况。

| 动作 | 测试次数 | 误差 | 是否通过 |
|------|---------|------|---------|
| 俯卧撑 | 10 | 待填写 | 待填写 |
| 深蹲   | 10 | 待填写 | 待填写 |
| 硬拉   | 10 | 待填写 | 待填写 |

硬拉警告触发测试（作业书 6 类；与 `DeadliftCounter` 对应）：

| 警告类型 | 是否可触发 |
|---------|---------|
| 背不直   | 待填写 |
| 膝内扣   | 待填写 |
| 杠铃路径 | 待填写 |
| 头前伸   | 待填写 |
| 起始髋低 | 待填写 |
| 拉阶段髋铰链（膝主导） | 待填写 |

**单元测试**：`destination='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -only-testing:IronBuddyTests` → **TEST SUCCEEDED**（4 例）。*当前 Xcode 设备列表中无 iPhone 16 模拟器时，可用本 destination 或 `xcodebuild -showdestinations` 选择本机可用机种。*

---

## 2026-04-03 Phase 2 / 可选项增量（骨架叠加 + 卧推计数）

| 子项 | 状态 | 说明 |
|------|------|------|
| `PoseOverlayView` | ✅ | BlazePose 33 点连线 + 关节点；`TrainingController` 每帧写入归一化点与可见度；`TrainView` 叠在预览上 |
| 卧推 `ExerciseType` + 计数 | ✅ | `BenchPressCounter`（§17.2 状态机，双肘取 min）；默认 **后置** 摄像头；MET 5.0；**未**实现 §17.3 卧推 6 类风险提示（仍为后续项） |
| Maestro / 首页文案 | ✅ | `flow.yaml` 断言「卧推」；`HomeView` 副标题含卧推 |

**本批次修改文件清单**

- `IronBuddy/IronBuddy/Services/PoseDetector/BenchPressCounter.swift`（新）
- `IronBuddy/IronBuddy/Services/Train/TrainingController.swift` — 骨架数据、`BenchPressCounter`、相机/镜像用 `ExerciseType` 扩展属性
- `IronBuddy/IronBuddy/Views/Prepare/PoseOverlayView.swift` — Canvas 绘制骨架
- `IronBuddy/IronBuddy/Views/Train/TrainView.swift` — 叠加层
- `IronBuddy/IronBuddy/Models/ExerciseType.swift` — `benchPress`、`mirrorLandmarksForPose`、`usesFrontCameraByDefault`
- `IronBuddy/IronBuddy/Utilities/Constants.swift` — `bench*` 角度阈、`METValues.benchPress`
- `IronBuddy/IronBuddy/Views/Home/HomeView.swift` — 文案
- `IronBuddy/maestro_tests/flow.yaml` — 卧推可见性

---

## 2026-04-09 测试加固 + 静态走查（Claude 会话）

**目标**：为长期欠账的「计数器 / DB 单元测试缺失」补底，并清理几处真 bug。

### A. 计数器单元测试补全（解决 §5.2 / 第 263 行 TODO）

**架构改动**：把 4 个 Counter 的实现迁出主 App、迁入 `IronBuddyHelpers`，彻底脱离 MediaPipe，从而测试 Target 可以直接 `import IronBuddyHelpers` 驱动状态机，避免 absl / Early unexpected exit 风险。

- **新增**：`IronBuddyHelpers/Sources/IronBuddyHelpers/PoseCounters.swift`
  - `public struct PoseLandmarkData { x, y, visibility }`（纯 Swift，不依赖 MediaPipe）
  - `public enum PoseIndex`（从 app 端 `PoseLandmarkMath.swift` 迁入）
  - `public enum AngleThresholds`（从 `Constants.swift` 迁入）
  - `public enum PoseLandmarkMath`（point/visibility/angleDegrees）
  - `public final class PushupCounter / SquatCounter / DeadliftCounter / BenchPressCounter`
  - 各 `process(...)` 接受 `now: Date = Date()`，便于在测试里注入虚拟时间。
- **App 端清理**：
  - `Services/PoseDetector/{Pushup,Squat,Deadlift,BenchPress}Counter.swift` 全部清空为占位注释（Xcode 工程引用保留，零内容）。
  - `Services/PoseDetector/PoseLandmarkMath.swift` 改为只导出 `PoseLandmarkBridge.toPoseData(_:)` —— 把 `[NormalizedLandmark]` 一次性转为 `[PoseLandmarkData]`。
  - `Utilities/Constants.swift` 删除 `AngleThresholds`。
  - `Services/Train/TrainingController.swift`：
    - 显式 `import IronBuddyHelpers`。
    - `handle(landmarks:)` 中先 bridge 一次，counter 与 `PoseOverlayView` 共用同一份纯数据（避免重复转换）。
    - 4 个 counter 字段类型变成 helpers 中的 public class。
- **测试新增**（`IronBuddyTests/IronBuddyTests.swift`）：
  - PushupCounter：`pushup_completesOneRep`、`pushup_tooFastIsRejected`（< 0.8s 视为无效）、`pushup_lowVisibilityResets`（关键关节遮挡 > 2s 复位）、`pushup_resetClearsState`
  - SquatCounter：`squat_fullCycleProducesRep`、`squat_resetClears`
  - DeadliftCounter：`deadlift_fullCycleProducesRep`、`deadlift_backRoundedWarningTriggers`、`deadlift_resetClears`
  - BenchPressCounter：`benchPress_completesOneRep`
  - 所有 fixture 用合成 33 点坐标，**只验证状态机和角度阈值**，不需要真实人体姿态。

### C. 静态走查 + 真 bug 修复

让 Explore agent 跑了一遍 Services / Views / App / Utilities，列了 15 项嫌疑。逐项核实后，**11 项是假阳性**（CameraPreviewView 强转是 Apple 标准用法、`session.startRunning()` 在后台队列是官方推荐、`Connection.deinit` 自动 `sqlite3_close` 无泄漏、HK 失败不阻塞是设计意图、等等）。**真正修复的 4 项**：

| # | 文件 | 问题 | 修复 |
|---|------|------|------|
| 1 | `Services/TTS/LocalTTSService.swift` + `Views/Settings/SettingsView.swift` | `"ttsEnabled"` 字面量散落两处，靠 DRY 巧合一致 | 新增 `UserDefaultsKeys.ttsEnabled`，两处统一引用 |
| 2 | `Views/Train/RestTimerView.swift` | `startTimer()` 在 `onAppear` 重入时旧 `Timer` 不被 invalidate 直接被覆盖→泄漏 + 倒计时 2× 速率 | `startTimer()` 起手先 `stopTimer()`；同时把 `LocalTTSService` 提升为 `@State`，避免每次启动都创建新合成器 |
| 3 | `Views/Log/LogListView.swift` | `deleteSessions(at:)` 用 `try?` 静默吞错误 | 改为 `do/catch`，把错误信息暂存后在 `reload()` 之后写回 `loadError`，UI 可见 |
| 4 | `Services/Database/DatabaseService.swift` | 每次 CRUD 都重跑 `migrate()`（CREATE TABLE IF NOT EXISTS）—— 安全但浪费 | 静态 `didMigrate` flag + `NSLock`，每个进程只迁移一次 |

### 测试结果（本会话最终）

| 命令 | 结果 |
|------|------|
| `xcodebuild ... build` (iPhone 17 Pro / iOS 26.4) | ✅ BUILD SUCCEEDED |
| `xcodebuild ... test`  | ✅ TEST SUCCEEDED |

| 套件 | 计数 |
|------|------|
| 单元测试（IronBuddyTests） | 14 通过（基线 4 + 计数器新增 10） |
| UI 测试（IronBuddyUITests + LaunchTests） | 6 通过 |

### 仍需真机/真人验证（依旧）

- Phase 1 停止点：俯卧撑 / 深蹲 / 硬拉 / 卧推各 10 次重复，误差 ≤ 1。
- 硬拉 6 类警告（`back_rounded` / `knee_valgus` / `bar_path` / `head_forward` / `hips_too_low` / `hip_hinge`）的真人触发测试。**注**：本会话单测只覆盖了 `back_rounded`，其余 5 类的"形状"分支已脱钩 MediaPipe，理论上后续可继续在 Helpers 上加合成 fixture。
- 卧推 §17.3 的 6 类风险提示（仍未实现，可选项）。

### 修改 / 新增文件清单（本批次）

| 路径 | 状态 |
|------|------|
| `IronBuddy/IronBuddyHelpers/Sources/IronBuddyHelpers/PoseCounters.swift` | 新 |
| `IronBuddy/IronBuddy/Services/PoseDetector/PushupCounter.swift` | 清空（占位注释） |
| `IronBuddy/IronBuddy/Services/PoseDetector/SquatCounter.swift` | 清空 |
| `IronBuddy/IronBuddy/Services/PoseDetector/DeadliftCounter.swift` | 清空 |
| `IronBuddy/IronBuddy/Services/PoseDetector/BenchPressCounter.swift` | 清空 |
| `IronBuddy/IronBuddy/Services/PoseDetector/PoseLandmarkMath.swift` | 重写为 `PoseLandmarkBridge` |
| `IronBuddy/IronBuddy/Services/Train/TrainingController.swift` | bridge + helpers counters |
| `IronBuddy/IronBuddy/Services/Database/DatabaseService.swift` | migrate 单次化 |
| `IronBuddy/IronBuddy/Services/TTS/LocalTTSService.swift` | 用 `UserDefaultsKeys.ttsEnabled` |
| `IronBuddy/IronBuddy/Utilities/Constants.swift` | 删 `AngleThresholds`，加 `ttsEnabled` 键 |
| `IronBuddy/IronBuddy/Views/Settings/SettingsView.swift` | 用 `UserDefaultsKeys.ttsEnabled` |
| `IronBuddy/IronBuddy/Views/Train/RestTimerView.swift` | Timer 重入防护 + TTS 单实例 |
| `IronBuddy/IronBuddy/Views/Log/LogListView.swift` | 删除错误回写 UI |
| `IronBuddy/IronBuddyTests/IronBuddyTests.swift` | 新增 10 条计数器测试 + PoseFixtures |

---

## 2026-04-14 V1.1 体验大版本升级（11 项优化功能）

**日期**：2026-04-14
**编译**：`xcodebuild -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**
**执行方式**：3 个并行子任务（Agent）+ 主线程直接开发

---

### A. 功能完成总览

| # | 功能 | 状态 | 实现要点 |
|---|------|------|----------|
| 1 | 全屏沉浸式训练界面 | ✅ | TrainView 重写为 ZStack 全屏；相机+骨架 ignoresSafeArea；浮动 UI 使用 ultraThinMaterial；隐藏导航栏和状态栏 |
| 2 | 四动作实时姿态纠正 | ✅ | FormWarning 提升为公共类型；PushupCounter 3 类（深度不足/臀部下沉/臀部过高）、SquatCounter 3 类（膝内扣/深度不足/前倾）、BenchPressCounter 2 类（深度不足/两侧不均）；DeadliftCounter 原有 6 类保持 |
| 3 | 训练数据可视化 | ✅ | StatsView：Swift Charts 柱状图（按运动类型着色）、时间范围选择器（7/30/90天）、四张汇总卡片（训练次数/总次数/总卡路里/连续天数） |
| 4 | 智能休息计时 | ✅ | ExerciseType 增加 recommendedRestSeconds（俯卧撑60s/深蹲120s/硬拉180s/卧推120s）和 restAdvice 文案；SetConfirmSheet 优先使用运动类型推荐值；RestTimerView 展示建议卡片 |
| 5 | 训练计划模板 | ✅ | TrainingPlan 模型 + 4 套预设（上肢力量/下肢爆发/全身训练/新手入门）；TrainingPlanView 展示计划详情，一键开始首个动作 |
| 6 | 触觉反馈 | ✅ | TrainView 中 onChange(of: repCount) 触发 UIImpactFeedbackGenerator(.light)；formWarningText 变化触发 UINotificationFeedbackGenerator(.warning) |
| 7 | 离线语音指令 | ✅ | VoiceCommandService：SFSpeechRecognizer 离线中文识别；支持"停止""下一组""跳过"等指令；TrainView 顶栏麦克风按钮切换 |
| 8 | 成就系统 | ✅ | Achievement 模型 + 8 个成就定义；AchievementView 2 列网格展示，已解锁高亮 + 发光边框，未解锁灰显 |
| 9 | 深色/浅色主题切换 | ✅ | AppStorage appearanceMode（0=跟随系统/1=深色/2=浅色）；IronBuddyApp 中 preferredColorScheme 动态切换；SettingsView 分段选择器 |
| 10 | 训练数据导出 | ✅ | StatsView 随 Agent 实现 CSV 导出功能 |
| 11 | 科技感深色 UI 主题 | ✅ | Theme.swift 全面重写；所有页面统一深色背景 + 科技蓝/橙色渐变；PoseOverlayView 蓝色发光骨架；CountDisplayView 双层阴影发光 |

---

### B. 深色科技 UI 重构（本批次之前会话完成，本次沿用）

- **Theme.swift**：bgPrimary(#0F1219) / bgCard(#191C29) / techCyan(#00D9FF) / accent(orange) / primaryGradient(橙→红)
- **所有 View** 统一深色主题：HomeView / ActionSelectView / TrainView / SetConfirmSheet / RestTimerView / CompletionView / HistoryView / WorkoutDetailView / ProfileView / SettingsView / FlexibilityTestView / CameraPrepareView
- **ExerciseCard**：minHeight 130 等高、科技边框
- **PoseOverlayView**：双层描边（粗线0.25透明度 + 细线0.9透明度）产生发光效果
- **CountDisplayView**：112pt 圆角数字 + 双层 techCyan 阴影
- **PrimaryButton**：白色边框 + 橙色 shadow glow
- **IronBuddyApp**：`.preferredColorScheme(.dark)` 强制深色（现改为动态可切换）

---

### C. 动作纠正详情

**FormWarning**（`IronBuddyHelpers/PoseCounters.swift`）从 DeadliftCounter 内部提升为顶级公共结构体，包含 `type`（标识符）、`message`（用户可见中文+emoji）、`risk`（风险说明）。

**PushupCounter 新增警告**：
| type | 触发条件 | 消息 |
|------|---------|------|
| `insufficient_depth` | down 状态下肘角 > 110° | 再往下一点，手肘弯曲不够 |
| `hips_sagging` | down/ready 状态下髋角 < 150° | 收紧核心，臀部不要下沉 |
| `hips_too_high` | 髋角 > 175° 且肩 Y > 髋 Y | 臀部不要翘太高 |

**SquatCounter 新增警告**：
| type | 触发条件 | 消息 |
|------|---------|------|
| `knee_valgus` | 膝盖 X 偏移 > 脚踝宽度 × 1.1 | 膝盖朝向脚尖方向 |
| `not_deep_enough` | bottom 状态下膝角 > 110° | 再蹲深一些 |
| `forward_lean` | 肩 X 与踝 X 偏差 > 0.08 | 上身保持直立 |

**BenchPressCounter 新增警告**：
| type | 触发条件 | 消息 |
|------|---------|------|
| `insufficient_depth` | down 状态下肘角 > 100° | 再往下放一点 |
| `asymmetric_press` | 左右肘角差 > 25° | 两侧用力不均匀 |

**TrainingController.wireCounters()**：统一 `handleWarning` 闭包绑定到全部 4 个 counter 的 `onFormWarning`，触发时更新 `formWarningText` + `formRiskText` + TTS 语音播报。

---

### D. 首页结构变化

HomeView 新增入口：
- **训练计划** 卡片（绿色 list.clipboard.fill 图标，样式与体态评估一致）
- 底部导航从 HStack 改为 LazyVGrid 3 列，新增 **统计** 和 **成就** 入口

AppRoute 新增：`.trainingPlan` / `.stats` / `.achievements`

---

### E. 语音指令技术实现

`VoiceCommandService`（`Services/Voice/VoiceCommandService.swift`）：
- `SFSpeechRecognizer(locale: "zh-CN")`，`requiresOnDeviceRecognition = true`
- `AVAudioEngine` 实时录音 → `SFSpeechAudioBufferRecognitionRequest` → 部分结果回调
- 识别关键词匹配：开始/停止/结束/下一组/跳过
- 去重：`lastParsedSuffix` 避免同一词重复触发
- 自动重启：识别结束或出错后 `restartListening()`
- TrainView 集成：顶栏 mic 按钮；onDisappear 自动 stopListening

**权限需求**：Info.plist 需增加 `NSSpeechRecognitionUsageDescription` 和 `NSMicrophoneUsageDescription`（后者训练页原已需要录音权限则已有）。

---

### F. 成就系统设计

8 个成就（`Models/Achievement.swift`），基于 `[TrainingSessionRecord]` 动态计算解锁状态：

| ID | 名称 | 条件 |
|----|------|------|
| `first_workout` | 初出茅庐 | ≥ 1 次训练 |
| `ten_workouts` | 持之以恒 | ≥ 10 次训练 |
| `fifty_workouts` | 铁人精神 | ≥ 50 次训练 |
| `hundred_reps` | 百次突破 | 单次训练 ≥ 100 次动作 |
| `all_exercises` | 全面发展 | 4 种运动均尝试过 |
| `streak_7` | 一周不断 | 连续 7 天训练 |
| `streak_30` | 月度坚持 | 连续 30 天训练 |
| `calories_1000` | 千卡燃烧 | 累计消耗 ≥ 1000 kcal |

AchievementView 从 `DatabaseService.loadSessionsInRange(days: 9999)` 加载全部记录，实时判定解锁。

---

### G. 训练计划模板

`TrainingPlan` + `TrainingPlanStep`（`Models/TrainingPlan.swift`）：

| 计划 | 难度 | 内容 |
|------|------|------|
| 上肢力量 | 入门 | 俯卧撑 3×15 + 卧推 3×10 |
| 下肢爆发 | 进阶 | 深蹲 4×12 + 硬拉 3×8 |
| 全身训练 | 高级 | 俯卧撑 3×20 + 深蹲 3×15 + 硬拉 3×8 + 卧推 3×10 |
| 新手入门 | 入门 | 俯卧撑 2×10 + 深蹲 2×10 |

当前点击"开始训练"会取计划第一个动作进入 cameraPrepare 流程。**TODO**：支持按计划顺序自动流转下一个动作。

---

### H. 修改 / 新增文件清单

| 路径 | 状态 | 说明 |
|------|------|------|
| `IronBuddyHelpers/Sources/IronBuddyHelpers/PoseCounters.swift` | 修改 | FormWarning 提升为顶级类型；PushupCounter/SquatCounter/BenchPressCounter 增加 onFormWarning + 纠正逻辑 |
| `IronBuddy/Models/TrainingPlan.swift` | **新** | 训练计划模型 + 4 套预设 |
| `IronBuddy/Models/Achievement.swift` | **新** | 成就定义 + 8 个成就 |
| `IronBuddy/Models/ExerciseType.swift` | 修改 | recommendedRestSeconds、restAdvice 属性 |
| `IronBuddy/Services/Voice/VoiceCommandService.swift` | **新** | SFSpeechRecognizer 离线语音指令 |
| `IronBuddy/Services/Train/TrainingController.swift` | 修改 | 统一 onFormWarning 接线 |
| `IronBuddy/Views/Plan/TrainingPlanView.swift` | **新** | 训练计划浏览+开始页 |
| `IronBuddy/Views/Achievement/AchievementView.swift` | **新** | 成就展示页 |
| `IronBuddy/Views/Log/StatsView.swift` | **新** | Swift Charts 数据可视化 |
| `IronBuddy/Views/Train/TrainView.swift` | 修改 | 全屏重构 + 触觉反馈 + 语音指令集成 |
| `IronBuddy/Views/Train/CountDisplayView.swift` | 修改 | 112pt + 双层 techCyan glow |
| `IronBuddy/Views/Train/RestTimerView.swift` | 修改 | restAdvice 展示卡片 |
| `IronBuddy/Views/Confirm/SetConfirmSheet.swift` | 修改 | 按运动类型智能推荐休息时长 |
| `IronBuddy/Views/Home/HomeView.swift` | 修改 | 新增训练计划入口 + 统计/成就导航 |
| `IronBuddy/Views/Settings/SettingsView.swift` | 修改 | 外观模式选择器 |
| `IronBuddy/Views/Components/ExerciseCard.swift` | 修改 | 深色主题 + 等高 |
| `IronBuddy/Views/Components/NavCard.swift` | 修改 | 深色主题 |
| `IronBuddy/Views/Components/PrimaryButton.swift` | 修改 | glow 边框 |
| `IronBuddy/Views/Prepare/PoseOverlayView.swift` | 修改 | 蓝色发光骨架 |
| `IronBuddy/Views/Prepare/CameraPrepareView.swift` | 修改 | AI 引导拍摄 + 深色主题 |
| `IronBuddy/Views/Prepare/FlexibilityTestView.swift` | 修改 | 真实评分 + 自动流转 + 深色主题 |
| `IronBuddy/Utilities/Theme.swift` | 修改 | 全面重写科技深色主题 |
| `IronBuddy/Utilities/Constants.swift` | 修改 | appearanceMode 键 |
| `IronBuddy/App/AppState.swift` | 修改 | 新增 trainingPlan/stats/achievements 路由 |
| `IronBuddy/App/RootView.swift` | 修改 | 新增路由绑定 |
| `IronBuddy/IronBuddyApp.swift` | 修改 | preferredColorScheme 动态化 |
| 其余 Views（Profile/Done/Log/Select 等） | 修改 | 统一深色主题适配 |

---

### I. 已知待办 / TODO

1. ~~**训练计划多动作流转**~~：✅ 已完成。AppState 新增 `activePlan` + `activePlanStepIndex`，CompletionView 显示"下一动作"按钮。
2. ~~**语音指令 Info.plist**~~：✅ 已在 project.pbxproj 添加 `NSMicrophoneUsageDescription` 和 `NSSpeechRecognitionUsageDescription`。
3. **StatsView CSV 导出**：需验证导出文件格式与系统分享功能。
4. **Phase 1 停止点验证**：俯卧撑/深蹲/硬拉/卧推的计数误差与纠正警告仍需真机真人测试。
5. ~~**浅色模式适配**~~：✅ Theme.swift 改用 `UIColor { traits in }` 动态颜色，深色/浅色自动适配。

---

## 2026-04-14 Bug 修复与待办项处理（第二批次）

**编译**：`xcodebuild -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**

### Bug 1：体态评分过于宽松

**问题**：评分映射范围太宽松，用户轻松获得满分。

**修复**（`FlexibilityTestView.swift`）：
- 肩部伸展：`40-150` → `80-170`（需要手臂真正展开到接近 170° 才满分）
- 髋部灵活性：`10-90` → `20-100`（需要更高的腿部抬起角度）
- 脊柱旋转：`3-25` → `5-30`（拉大区分度）
- 体前屈：`10-80` → `20-100`（需要更深的前屈才满分）
- 合格门槛：从 `score >= 5` 提高到 `score >= 10`（满分 25），动作不到位不开始计时

### Bug 2：运动中警告声音太频繁 + 准备阶段误报

**问题**：每帧都可能触发警告语音播报；用户摆手机或还未开始做动作时就不断提示。

**修复**（`TrainingController.swift`）：
- 新增 `warningGracePeriod = 5.0` 秒——训练开始后前 5 秒不发任何警告，给用户摆好姿势
- 新增状态检查：只在计数器处于非 idle 状态（用户已进入动作模式）时才发警告
- 新增冷却机制：同类型警告间隔至少 **5 秒**，不同类型间隔至少 **3 秒**
- 冷却期内仍更新文字显示但 **不触发语音播报**

### Bug 3：运动中熄屏/亮度降低

**问题**：训练过程中屏幕可能变暗或熄灭。

**修复**：
- `SetConfirmSheet.swift`：onAppear 中增加 `UIApplication.shared.isIdleTimerDisabled = true`（此前该页面缺失）
- `TrainView.swift`：onAppear 时保存当前亮度并设置最低 0.6 亮度（`UIScreen.main.brightness = max(savedBrightness, 0.6)`），onDisappear 恢复原始亮度

### 待办项处理

| 待办 | 状态 | 说明 |
|------|------|------|
| 训练计划多动作流转 | ✅ | AppState 新增 `activePlan`/`activePlanStepIndex`/`hasNextPlanStep`/`advancePlanStep()`；TrainingPlanView 启动时设置活动计划；CompletionView 显示"下一动作"按钮 |
| 语音指令 Info.plist | ✅ | project.pbxproj Debug/Release 双配置均添加 `INFOPLIST_KEY_NSMicrophoneUsageDescription` 和 `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription` |
| 浅色模式适配 | ✅ | Theme.swift 全部基础色改为 `Color(UIColor { traits in ... })` 动态颜色：bgPrimary/bgCard/bgCardElevated 在浅色模式下使用 systemGroupedBackground 系列；primaryText/secondaryText/tertiaryText 使用 label/secondaryLabel/tertiaryLabel；subtleBorder 使用 separator |

### 修改文件清单

| 路径 | 说明 |
|------|------|
| `IronBuddy/Views/Prepare/FlexibilityTestView.swift` | 评分阈值收紧 + 合格门槛提高 |
| `IronBuddy/Services/Train/TrainingController.swift` | 警告冷却 + 静默期 + 状态检查 |
| `IronBuddy/Views/Train/TrainView.swift` | 亮度保持 |
| `IronBuddy/Views/Confirm/SetConfirmSheet.swift` | 新增 isIdleTimerDisabled |
| `IronBuddy/Utilities/Theme.swift` | 动态颜色适配深色/浅色 |
| `IronBuddy/App/AppState.swift` | activePlan + 流转方法 |
| `IronBuddy/Views/Plan/TrainingPlanView.swift` | 启动时设置活动计划 |
| `IronBuddy/Views/Done/CompletionView.swift` | "下一动作"按钮 |
| `IronBuddy.xcodeproj/project.pbxproj` | 新增麦克风+语音识别权限描述 |

---

## 2026-04-15 体验优化（第三批次）

**编译**：`xcodebuild -workspace IronBuddy.xcworkspace ... build` → **BUILD SUCCEEDED**

### Fix 1：AI 扫描场地居中参考线

**问题**：CameraPrepareView 中画面中间有一条虚线竖线，用户不理解其作用。
**修复**：移除 `CameraPrepareView.swift` 第 91-97 行的 `Rectangle().strokeBorder(style: StrokeStyle(...))` 居中参考线。引导功能由语音和文字提示完成，无需视觉辅助线。

### Fix 2：运动启动时骨架胡乱识别

**问题**：进入训练页面后姿态识别立刻启动，骨架点在用户还未就位时就乱跳，体验不好。
**修复**：
- `TrainingController.swift`：新增 `isPaused` 属性（默认 `true`）和 `resume()` 方法。`handle(landmarks:)` 在 `isPaused` 时直接 return，不更新骨架也不计数。
- `TrainView.swift`：新增 `countdown` 状态。`.task` 中先启动相机，然后显示 **3-2-1 倒计时覆盖层**（黑色半透明背景 + 120pt 粗体数字 + techCyan 发光），倒计时结束后调用 `training.resume()` 开始识别。
- 倒计时数字使用 `contentTransition(.numericText())` 动画过渡。

### Fix 3：导航黄色三角形问题

**问题**：统计/成就/历史/资料/设置等按钮偶发显示黄色三角形无法进入。
**修复**（上一批次）：
- `StatsView.swift`：移除 body 内嵌套的 `NavigationStack`（与 RootView 的外层栈冲突）
- `SettingsView.swift`：移除 `navigationBarBackButtonHidden(true)` + 自定义 `path.removeLast()` 返回按钮，改用系统默认返回
- `ActionSelectView.swift`：同上

### 修改文件清单

| 路径 | 说明 |
|------|------|
| `IronBuddy/Views/Prepare/CameraPrepareView.swift` | 移除居中虚线参考线 |
| `IronBuddy/Services/Train/TrainingController.swift` | 新增 isPaused + resume() |
| `IronBuddy/Views/Train/TrainView.swift` | 3-2-1 倒计时覆盖层 |
| `IronBuddy/Views/Log/StatsView.swift` | 移除嵌套 NavigationStack |
| `IronBuddy/Views/Settings/SettingsView.swift` | 移除自定义返回按钮 |
| `IronBuddy/Views/Select/ActionSelectView.swift` | 移除自定义返回按钮 |

---

## 2026-04-15 V2.0 第一批功能落地

**编译**：`xcodebuild -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → **BUILD SUCCEEDED**

**用户 V2.0 指令**：骨架 100% 对齐 + 热身引导（可跳过）+ 动作回放（高优先级，慢动作 + 调整建议）+ 自适应强度建议 + 新手/老手模式开关 + 多角度识别。"直接向 2.0 出发吧，有问题随时停下来跟我沟通。"

### V2.0-1：骨架识别点位 100% 对齐 ✅

**问题根因**：`CameraPreviewView` 使用 `videoGravity = .resizeAspectFill`（等比放大视频直到完全覆盖视图，多余裁剪）；`PoseOverlayView` 却直接使用 `p.x * size.width, p.y * size.height`（假设视频与视图比例一致、无裁剪）。视频为 1080×1920 竖屏（9:16），iPhone 屏幕常为 ~9:19.5，导致骨架点位整体横向压缩错位。

**修复**（`Views/Prepare/PoseOverlayView.swift`）：新增 `videoAspectRatio: CGFloat = 9.0/16.0` 参数。在 Canvas 内计算 AspectFill 变换：

```swift
let viewAspect = size.width / size.height
let displayedW, displayedH: CGFloat
if videoAspectRatio > viewAspect {
    displayedH = size.height
    displayedW = size.height * videoAspectRatio   // 宽度超出，两侧裁剪
} else {
    displayedW = size.width
    displayedH = size.width / videoAspectRatio     // 高度超出，上下裁剪
}
let offsetX = (displayedW - size.width) / 2
let offsetY = (displayedH - size.height) / 2
toScreen = { p in CGPoint(x: p.x * displayedW - offsetX, y: p.y * displayedH - offsetY) }
```

与 `CameraPreviewView` 的 AspectFill 行为精确匹配；`TrainView`（全屏）和 `CameraPrepareView`（420pt 固定高度）两处使用都能正确对齐。

### V2.0-2：新手/老手模式 ✅

**动机**：老手觉得新手引导过于啰嗦/菜鸟。

**落地**：
- `Utilities/Constants.swift`：新增 `enum UserLevel { case beginner, expert }` + 4 个 UserDefaults 键（`userLevel` / `warmupEnabled` / `replayEnabled` / `adaptiveIntensityEnabled`）
- `Views/Settings/SettingsView.swift`：新增 "训练水平" 分段 Picker（含说明 footer）+ "智能辅助 (V2.0)" 开关区块
- `Services/Train/TrainingController.swift`：`handleFormWarning` 前置判断，若 `userLevel == .expert` 且 `w.risk` 不含 "伤"/"严重" 且 `w.type` 不含 `hips_sagging`/`knee_valgus`（髋塌陷 / 膝内扣这两类高伤病风险），则仅更新屏幕文字，**不语音播报**

### V2.0-3：热身/拉伸引导（可跳过）✅

**新文件**：
- `Views/Warmup/WarmupGuideView.swift`：5 个预设热身动作（颈部环绕 20s / 肩胛活动 30s / 髋部环绕 30s / 动态深蹲 40s / 侧弓步 40s），每个动作有 SF Symbol 大图标 + 标题 + 说明 + 倒计时 + 暂停/下一个按钮 + 全局跳过按钮。Timer 使用 `Timer.publish` + `onReceive`（需 `import Combine`）
- 入口：`Views/Prepare/CameraPrepareView.swift` 顶部新增 "训练前热身（可跳过）" 按钮（读取 `@AppStorage warmupEnabled`）
- 路由：`AppState.AppRoute` 新增 `.warmup`；`RootView.swift` 路由表映射到 `WarmupGuideView()`

### V2.0-4：动作回放（高优先级）✅

**核心架构**：
- `Services/Replay/RepRecording.swift`：
  - `RepKeyframe` = 时间戳 + 33 个归一化点 + visibilities
  - `RepRecording` = rep 序号 + 起始时间 + 时长 + `[RepKeyframe]` + `[ReplayWarning]`。计算属性 `adjustmentTips` 聚合警告 + 基于时长的节奏反馈（>4.5s 过慢 / <1.2s 过快）
- `Services/Replay/RepReplayRecorder.swift`：滚动窗口（2.5s、上限 60 帧），`appendFrame` 持续喂帧、`recordWarning` 收集当前窗口内警告、`commitRep(index:)` 打包并追加到 `recordings`。`appendFrame` 会按时间戳修剪超出窗口的旧帧。

**TrainingController 集成**：
- 新增 `let replayRecorder = RepReplayRecorder()`、`repDurations: [TimeInterval]` 数组、`lastRepTime`
- `wireCounters` 统一 `handleRep`：所有计数器（4 个）共享同一闭包，内部累加时长、调用 `replayRecorder.commitRep(index: n)`
- `updatePoseOverlay` 末尾调用 `replayRecorder.appendFrame(...)`
- `handleFormWarning` 末尾调用 `replayRecorder.recordWarning(...)`（语音播报的警告才进入回放）

**AppState 转存**：新增 `lastSetReplayRecordings: [RepRecording]` + `lastSetRepDurations: [TimeInterval]` + `nextSetSuggestion: IntensitySuggestion?`。`TrainView` 的 `stashReplayAndDurations()` 在 "本组结束" 和语音 `.stop/.nextSet` 时写入。

**回放 UI**（`Views/Replay/ActionReplayView.swift`）：
- 顶部水平 ScrollView 的 rep 选择器（胶囊：#序号 + 时长）
- 中部 9:16 播放区域，使用 `PoseOverlayView` 渲染当前帧（按时间戳选择最近帧）；左上角显示 "t / total"，右上角显示播放速度
- 控制栏：回到起点 / 暂停-播放 / 速度切换（1.0x → 0.75x → 0.5x → 0.25x 循环）+ 可拖动进度 Slider（拖动自动暂停）
- 底部 "调整建议" 区块展示 `adjustmentTips`
- 用 `Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()` 驱动 `currentTime += dt * playbackSpeed`（循环播放）

**入口**：`Views/Confirm/SetConfirmSheet.swift` 新增 "查看本组动作回放" 按钮（条件：`lastSetReplayRecordings` 非空 && `replayEnabled`）。路由 `.actionReplay` 在 `RootView` 映射到 `ActionReplayView(recordings: appState.lastSetReplayRecordings)`。

### V2.0-5：自适应强度建议 ✅

**新文件** `Services/Adaptive/IntensitySuggestion.swift`：
- `enum IntensityLevel { tooLight / moderate / tooHard }`
- `struct IntensitySuggestion { level, title, detail, suggestion }`
- `AdaptiveIntensityAnalyzer.analyze(repDurations:)` 算法：
  - 需要 ≥ 3 次 rep 才给建议
  - 取前半段均值 `avg1` 与后半段均值 `avg2`，计算疲劳比 `fatigueRatio = avg2 / avg1`
  - `fatigueRatio > 1.4` 或 `overall > 3.5s` → `.tooHard`（建议 -2 次或 -2.5 kg）
  - `overall < 1.5s` 且 `fatigueRatio < 1.15` → `.tooLight`（建议 +2 次或 +2.5 kg）
  - 其它 → `.moderate`（保持）

**入口**：`SetConfirmSheet` 显示一个卡片（图标 + 标题 + 详情 + 建议 + 可点 "忽略此建议"）。`TrainView.stashReplayAndDurations` 在组结束时调用分析器并写入 `appState.nextSetSuggestion`。受 `adaptiveIntensityEnabled` 开关控制。

### V2.0-6：多角度姿态识别 ✅

**新文件** `Services/PoseDetector/CameraAngleDetector.swift`：
- `enum CameraAngle { frontal / side / diagonal / unknown }`，每个 case 有 `.tip` 文案（正面推荐深蹲/俯卧撑、侧面推荐硬拉/卧推、斜角通用）
- 算法：取双侧肩髋的 min visibility，差值 > 0.35 判为 side（另一侧被遮挡）；否则用 `shoulderSpread / torsoHeight` 比例，<0.35 为 side、>0.75 为 frontal、中间为 diagonal

**TrainingController 集成**：新增 `var detectedAngle: CameraAngle = .unknown`（Observable），`handle(landmarks:)` 在 `updatePoseOverlay` 后调用 `CameraAngleDetector.detect(...)` 更新。

**UI**：`TrainView` 在计数牌下方显示一个 `.ultraThinMaterial` 胶囊，内容 = `angle.rawValue + " · " + angle.tip`。

### V2.0 新增文件树

```
IronBuddy/IronBuddy/
├── Services/
│   ├── Adaptive/
│   │   └── IntensitySuggestion.swift         # 强度分析器
│   ├── PoseDetector/
│   │   └── CameraAngleDetector.swift         # 多角度检测
│   └── Replay/
│       ├── RepRecording.swift                # 回放数据模型
│       └── RepReplayRecorder.swift           # 滚动窗口录制
└── Views/
    ├── Replay/
    │   └── ActionReplayView.swift            # 慢动作回放 UI
    └── Warmup/
        └── WarmupGuideView.swift             # 热身引导 UI
```

### 修改文件清单

| 路径 | 说明 |
|------|------|
| `IronBuddy/Views/Prepare/PoseOverlayView.swift` | AspectFill 坐标变换，骨架 100% 对齐 |
| `IronBuddy/Utilities/Constants.swift` | UserLevel enum + 4 个 V2.0 UserDefaults 键 |
| `IronBuddy/Views/Settings/SettingsView.swift` | 训练水平 Picker + 智能辅助开关区块 |
| `IronBuddy/Services/Train/TrainingController.swift` | 回放录制集成 + repDurations + detectedAngle + 老手模式警告降噪 |
| `IronBuddy/App/AppState.swift` | 新增 `.actionReplay` / `.warmup` 路由 + lastSet 回放/时长/建议字段 |
| `IronBuddy/App/RootView.swift` | 新路由映射 |
| `IronBuddy/Views/Train/TrainView.swift` | stashReplayAndDurations + 多角度提示胶囊 |
| `IronBuddy/Views/Confirm/SetConfirmSheet.swift` | 回放入口按钮 + 强度建议卡片 |
| `IronBuddy/Views/Prepare/CameraPrepareView.swift` | 顶部热身入口按钮 |

### 构建踩坑

- `ActionReplayView.swift` / `WarmupGuideView.swift` 使用 `Timer.publish().autoconnect()` 必须 `import Combine`，否则报 `autoconnect()` not available。
- 项目使用 **Xcode 16 文件系统同步 group**（`PBXFileSystemSynchronizedRootGroup`），新增 Swift 文件无需手工编辑 `project.pbxproj`，自动纳入编译。

### 尚未处理的 V2.0 深水区（后续可继续）

1. **回放帧持久化**：目前 `lastSetReplayRecordings` 仅在内存中，一旦离开 `CompletionView` 或重启 App 即丢失。持久化方案可考虑 SQLite BLOB（压缩后的骨架帧）或独立 `.json` 文件。
2. **多角度信号注入计数器**：当前 `detectedAngle` 仅作 UI 提示，未真正改变 `PoseCounters` 的阈值/取侧逻辑。要做到"侧面拍摄时自动切换到用可见侧的数据"需深度改造四个 counter。
3. **热身姿态评估**：当前 `WarmupGuideView` 仅定时器，未接姿态识别做动作质量打分。
4. **CompletionView 的回放入口**：目前只在 `SetConfirmSheet`（每组结束后）展示，训练结束页没有整次训练回放汇总。

### 交接要点

- **运行环境**：iPhone 17 Pro Simulator（iOS 26.4）编译通过。其它机型同样 OK，只需替换 destination 参数。
- **设置入口**：V2.0 所有新功能都有独立开关，默认全开；"老手模式" 默认关（`UserLevel.beginner.rawValue = 0`）。
- **数据流**：训练 → 组结束 → `TrainView.stashReplayAndDurations` 写 AppState → `SetConfirmSheet` 展示回放入口 & 强度建议 → 点回放走 `.actionReplay` 路由 → 用户返回后可继续下一组。

