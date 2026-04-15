# 铁伴儿 IronBuddy — V1.1 开发作业书

**出品：Peishen Studio**
**版本：V1.1（本地基础 + Apple Health + 硬拉实时纠错）**
**日期：2026-03-31**
**状态：✅ 讨论终稿

---

## 一、版本定位

### 1.1 V1.0 核心价值

**一句话**：用手机摄像头替代私教，实时识别动作对不对、做多少次，并记录到 Apple Health。

**核心差异化**：V1.0 独有**硬拉实时错误检测 + 受伤风险提示**，这是本软件的核心卖点。

### 1.2 V1.1 核心约束

| 约束项 | 要求 |
|--------|------|
| 运营成本 | ¥0/月（无服务器，无云服务）|
| 网络访问 | ❌ 仅 Apple Health 读写（用户主动授权）|
| 最低支持 | iPhone 15（iOS 17+）|
| 动作识别 | 100% 本地（MediaPipe TFLite，无联网）|
| 语音合成 | 本地 AVSpeechSynthesizer（系统自带）|
| 数据存储 | 本地 SQLite + Apple Health |

### 1.3 V1.1 vs V2.0 vs V3.0

| 版本 | 核心价值 | 技术 |
|------|----------|------|
| **V1.1（本文）** | 动作识别 + 实时纠错 + Apple Health 读写 | MediaPipe + HealthKit |
| **V2.0** | Feishu 导出 + AirPods 心率 | 网络 API |
| **V3.0** | AI 训练规划 | LLM API（运营成本）|

---

## 二、V1.1 功能规格

### 2.1 功能总览

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 俯卧撑识别计数 | P0 | 前置摄像头，状态机计数 |
| 深蹲识别计数 | P0 | 后置摄像头，侧身站立 |
| 硬拉识别计数 + 实时纠错 | P0 | 后置摄像头，四阶段 + 6类错误检测 |
| 受伤风险实时提示 | P0 | 语音+文字双通道提示 |
| 训练后确认重量/次数 | P0 | 每组弹出确认 |
| 训练日志（本地）| P0 | SQLite 持久化 |
| Apple Health 写入 | P0 | 训练写入健康 App |
| Apple Health 读取 | P0 | 读取历史训练 |
| 用户 Profile | P0 | 体重/年龄/性别 |
| 本地 TTS 语音播报 | P1 | AVSpeechSynthesizer |
| App 图标 + 闪屏 | P1 | 基础品牌化 |

### 2.2 V1.1 明确排除

- ❌ 账号体系 / 登录
- ❌ Feishu 文档导出（→ V2.0）
- ❌ AI 个性化训练计划（→ V3.0）
- ❌ AirPods 心率（→ V2.0）
- ❌ 云端同步
- ❌ 社区 / 论坛

---

## 三、技术规格

### 3.1 技术栈

| 类别 | 选型 | 版本 |
|------|------|------|
| 平台 | iOS | ≥iOS 17.0（iPhone 15+）|
| 语言 | Swift | 5.9+ |
| UI | SwiftUI | 最新 |
| 姿态识别 | MediaPipe Pose（TFLite）| Tasks Vision 0.2024.x |
| TTS | AVSpeechSynthesizer | 系统自带 |
| 本地存储 | SQLite.swift | 最新 |
| 健康数据 | HealthKit | 系统自带 |
| 包管理 | SPM（Xcode 内置）| |

### 3.2 依赖包（SPM）

```
MediaPipe Tasks Vision    →  姿态识别
SQLite.swift              →  本地数据库
```

### 3.3 MediaPipe Pose 模型下载地址

**pose_landmarker.task**（~3.5MB，33关键点，TFLite 格式）

```
https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task
```

备用地址：
```
https://github.com/google/mediapipe/tree/master/mediapipe/models#pose-landmark-models
```

**放入项目**：`IronBuddy/Resources/pose_landmarker.task`

**Xcode 配置**：
1. 将 pose_landmarker.task 拖入 Xcode 项目
2. Build Phases → Copy Bundle Resources → 添加 pose_landmarker.task
3. 确保 "Destination: Bundle Resources" 勾选

### 3.4 33 个骨骼关键点索引

```
11: left_shoulder   左肩      13: left_elbow     左肘
12: right_shoulder  右肩      14: right_elbow    右肘
15: left_wrist     左腕      23: left_hip       左髋
16: right_wrist    右腕      24: right_hip      右髋
25: left_knee      左膝      27: left_ankle     左踝
26: right_knee    右膝      28: right_ankle    右踝
29: left_heel     左脚跟    31: left_foot_index  左脚尖
30: right_heel    右脚跟    32: right_foot_index 右脚尖
```

### 3.5 角度计算函数

```swift
/// 计算三个关键点形成的角度（0-180度）
func calculateAngle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
    let vectorBA = CGPoint(x: a.x - b.x, y: a.y - b.y)
    let vectorBC = CGPoint(x: c.x - b.x, y: c.y - b.y)
    let dot = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y
    let magBA = sqrt(vectorBA.x * vectorBA.x + vectorBA.y * vectorBA.y)
    let magBC = sqrt(vectorBC.x * vectorBC.x + vectorBC.y * vectorBC.y)
    let cosAngle = dot / (magBA * magBC)
    let angle = acos(min(max(cosAngle, -1), 1)) * 180 / .pi
    return angle
}
```

### 3.6 俯卧撑计数算法

**前置摄像头，用户正对屏幕**

**状态机**：
```
IDLE → [肘角>170°] → READY
READY → [任一肘角<140°] → DOWN
DOWN → [双肘均>165°] → UP
UP → [等待0.5秒] → 完成++ → IDLE
```

**防误判**：
- DOWN→UP <0.8秒 → 丢弃（太快）
- DOWN→UP >4.0秒 → 丢弃（太慢）
- visibility <0.3 超过2秒 → 重置 IDLE

**肘角参考**：180°=完全伸直、170°=READY触发、140°=DOWN触发（标准底部）、90°=深度不足警告

```swift
class PushupCounter {
    enum State { case idle, ready, down, up }
    var state: State = .idle
    var completedReps: Int = 0
    var lastDownTimestamp: Date?

    func process(landmarks: [NormalizedLandmark]) {
        let elbowAngle = calculateAngle(landmarks[11], landmarks[13], landmarks[15])
        switch state {
        case .idle:
            if elbowAngle > 170 { state = .ready }
        case .ready:
            if elbowAngle < 140 {
                state = .down
                lastDownTimestamp = Date()
            }
        case .down:
            if elbowAngle > 165 {
                let duration = Date().timeIntervalSince(lastDownTimestamp ?? Date())
                state = (duration > 0.8 && duration < 4.0) ? .up : .idle
            }
        case .up:
            state = .idle
            completedReps += 1
            speak("\(completedReps)")
        }
    }
}
```

### 3.7 深蹲计数算法

**后置摄像头，侧身站立**

**状态机**：
```
IDLE → [髋角>160° 且 膝角>160°] → STANDING
STANDING → [膝角<100°] → BOTTOM
BOTTOM → [膝角>150° 且 髋角>140°] → STANDING
STANDING → [持续站立>2秒] → 完成++ → IDLE
```

**膝角参考**：180°=完全伸直、160°=STANDING触发、100°=BOTTOM触发（标准底部）、90°=深度不足警告

### 3.8 硬拉计数算法 + 实时错误检测（核心卖点）

**后置摄像头，侧身站立，髋铰链动作**

**四阶段状态机**：
```
IDLE → [踝角<30° 且 髋角<70°] → START
START → [髋角>100° 且 膝角>80°] → PULL
PULL → [髋角>165° 且 膝角>170°] → LOCK
LOCK → [髋角<165°] → LOWER
LOWER → [踝角<30° 且 髋角<70°] → 完成++ → IDLE
```

**完成触发**：完整经历 START→PULL→LOCK→LOWER→START 一个循环

**6类实时错误检测（V1.1 必须实现）**：

| 错误类型 | 检测条件 | 提示文案 | 受伤风险 |
|----------|----------|----------|----------|
| 腰椎弯曲 | backLinearity > 0.08 | ⚠️ 请挺直背部 | 腰椎间盘损伤 |
| 膝盖内扣 | kneeOffset > ankleOffset × 1.1 | ⚠️ 膝盖朝向脚尖 | 前十字韧带撕裂 |
| 髋主导缺失 | 髋角恢复慢于膝角 | ⚠️ 臀部先发力 | 下背代偿 |
| 铃片磕腿 | 髋位移 > 踝宽 20% | ⚠️ 贴近小腿拉起 | 髋关节撞击 |
| 头部前倾 | 耳屏点相对肩点前移 > 5% | ⚠️ 头部保持中立 | 颈椎压力 |
| 臀位过低启动 | 启动时髋角 < 45° | ⚠️ 臀部稍抬高 | 腰椎过度弯曲 |

```swift
class DeadliftCounter {
    enum Phase { case idle, start, pull, lock, lower }
    var phase: Phase = .idle
    var completedReps: Int = 0

    struct FormWarning {
        let type: String
        let message: String
        let risk: String
    }

    func process(landmarks: [NormalizedLandmark]) -> FormWarning? {
        let hipAngle = calculateAngle(landmarks[11], landmarks[23], landmarks[25])
        let kneeAngle = calculateAngle(landmarks[23], landmarks[25], landmarks[27])
        let ankleAngle = calculateAngle(landmarks[25], landmarks[27], landmarks[31])

        let backLinearity = abs(landmarks[11].y - 2 * landmarks[23].y + landmarks[25].y)
        if backLinearity > 0.08 {
            return FormWarning(type: "back_rounded",
                message: "⚠️ 请挺直背部，避免腰椎损伤",
                risk: "腰椎间盘剪切力过大")
        }

        let kneeOffset = abs(landmarks[26].x - landmarks[28].x)
        let ankleOffset = abs(landmarks[25].x - landmarks[27].x)
        if kneeOffset > ankleOffset * 1.1 {
            return FormWarning(type: "knee_valgus",
                message: "⚠️ 膝盖朝向脚尖，减少膝关节压力",
                risk: "前十字韧带承压过大")
        }

        switch phase {
        case .idle:
            if ankleAngle < 30 && hipAngle < 70 { phase = .start }
        case .start:
            if hipAngle > 100 && kneeAngle > 80 { phase = .pull }
        case .pull:
            if hipAngle > 165 && kneeAngle > 170 { phase = .lock }
        case .lock:
            if hipAngle < 165 { phase = .lower }
        case .lower:
            if ankleAngle < 30 && hipAngle < 70 {
                phase = .start
                completedReps += 1
                speak("\(completedReps)")
            }
        }
        return nil
    }
}
```

### 3.9 MET 卡路里估算

```swift
func estimateCalories(mets: Double, weightKg: Double, durationMinutes: Int) -> Int {
    return Int(mets * weightKg * Double(durationMinutes) / 60.0)
}

let pushupMET = 4.8
let squatMET = 5.0
let deadliftMET = 6.0
```

### 3.10 Apple Health 读写

```swift
import HealthKit

class HealthKitService {
    private let healthStore = HKHealthStore()

    func saveWorkout(type: String, start: Date, end: Date, calories: Double, notes: String) async throws {
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: start, end: end,
            duration: end.timeIntervalSince(start),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            totalDistance: nil,
            metadata: ["ExerciseType": type, "Notes": notes]
        )
        try await healthStore.save(workout)
    }

    func fetchRecentWorkouts(limit: Int = 10) async throws -> [HKWorkout] {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: nil, limit: limit, sortDescriptors: [sort]
            ) { _, results, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: results as? [HKWorkout] ?? []) }
            }
            healthStore.execute(query)
        }
    }
}
```

### 3.11 本地数据库 Schema

```swift
// === profile ===
CREATE TABLE profile (
    id INTEGER PRIMARY KEY,
    weight_kg REAL, age INTEGER, gender TEXT,
    created_at TEXT, updated_at TEXT
);

// === workouts ===
CREATE TABLE workouts (
    id INTEGER PRIMARY KEY,
    exercise_type TEXT,
    camera_mode TEXT,
    started_at TEXT, ended_at TEXT,
    total_sets INTEGER, total_reps INTEGER,
    avg_score REAL, total_calories INTEGER
);

// === workout_sets ===
CREATE TABLE workout_sets (
    id INTEGER PRIMARY KEY,
    workout_id INTEGER REFERENCES workouts(id),
    set_number INTEGER, reps INTEGER, weight_kg REAL, score REAL
);

// === settings ===
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT);
```

---

## 四、界面规格

### 4.1 页面清单（10个）

| 页面 | 说明 |
|------|------|
| 首页 | 快捷开始 + 最近训练 |
| 动作选择 | 俯卧撑/深蹲/硬拉 |
| AI 拍摄引导 | 四状态引导 |
| 训练执行 | 实时计数 + 错误提示 |
| 训练确认 | 每组确认重量/次数 |
| 训练完成 | 总结 + Apple Health |
| 训练日志 | 历史记录 |
| 训练详情 | 单次详情 |
| Profile | 体重/年龄/性别 |
| 设置 | TTS 开关等 |

---

## 五、项目结构

```
IronBuddy/
├── App/
│   ├── IronBuddyApp.swift
│   └── AppState.swift
├── Views/
│   ├── Home/HomeView.swift
│   ├── Select/ActionSelectView.swift
│   ├── Prepare/CameraPrepareView.swift
│   ├── Prepare/PoseOverlayView.swift
│   ├── Train/TrainView.swift
│   ├── Train/CountDisplayView.swift
│   ├── Confirm/SetConfirmSheet.swift
│   ├── Done/DoneView.swift
│   ├── Log/LogListView.swift
│   ├── Log/WorkoutDetailView.swift
│   ├── Profile/ProfileView.swift
│   ├── Settings/SettingsView.swift
│   └── Components/PrimaryButton.swift
├── Models/
│   ├── ExerciseType.swift
│   ├── Workout.swift
│   ├── WorkoutSet.swift
│   └── UserProfile.swift
├── Services/
│   ├── PoseDetector/
│   │   ├── PoseDetector.swift
│   │   ├── PushupCounter.swift
│   │   ├── SquatCounter.swift
│   │   ├── DeadliftCounter.swift
│   │   └── AngleCalculator.swift
│   ├── Camera/CameraService.swift
│   ├── TTS/LocalTTSService.swift
│   ├── Calorie/CalorieEstimator.swift
│   ├── HealthKit/HealthKitService.swift
│   └── Database/DatabaseService.swift
├── Utilities/
│   ├── Constants.swift
│   └── Extensions/Date+Extensions.swift
└── Resources/
    ├── Assets.xcassets/
    └── pose_landmarker.task
```

---

## 六、开发任务（Vibe Coding 版）

### 核心原则

- ❌ 不按「周」划分
- ✅ Todolist 驱动，每个任务有明确验收标准
- ✅ **Phase 边界 = 强制停止点**，必须汇报后继续
- ✅ 遇到关键问题主动暂停，不强行推进

### Phase 0：项目初始化

**目标**：项目可编译，模拟器运行

| # | 任务 | 验收标准 |
|---|------|----------|
| 0.1 | 创建 iOS 项目（Xcode 15+，iPhone 15 模拟器）| 项目创建成功 |
| 0.2 | 添加 SPM：MediaPipe Tasks Vision + SQLite.swift | 包解析成功，无红 |
| 0.3 | 创建目录结构 | 规范 |
| 0.4 | App State + NavigationStack 路由 | 10个页面可跳转 |
| 0.5 | 配置 Info.plist（NSCameraUsageDescription + NSHealthShareUsageDescription + NSHealthUpdateUsageDescription）| 配置完整 |
| 0.6 | **xcodebuild build** | 编译通过 |
| 0.7 | **✅ Phase 0 停止点**：通知用户"项目初始化完成" |

### Phase 1：姿态识别核心

**目标**：三动作计数准确，实时纠错生效

| # | 任务 | 验收标准 |
|---|------|----------|
| 1.1 | CameraService（前置/后置切换）| 双模式预览正常 |
| 1.2 | MediaPipe Pose 实时流集成 | 33关键点稳定输出 |
| 1.3 | AngleCalculator + 单元测试 | 测试通过 |
| 1.4 | PushupCounter 状态机 | 10次误差≤1 |
| 1.5 | SquatCounter 状态机 | 10次误差≤1 |
| 1.6 | **DeadliftCounter + 6类错误检测** | 10次误差≤1，6类提示均触发 |
| 1.7 | LocalTTSService 集成 | 语音播报正常 |
| 1.8 | **xcodebuild build** | 编译通过 |
| 1.9 | **✅ Phase 1 停止点**：通知用户"三动作算法完成"，附测试结果 |

**📌 沟通节点**：硬拉实测误差>1 → 立即停止；膝角阈值需实测微调 → 通知确认

### Phase 2：UI + 训练流程

**目标**：完整闭环，可完整操作一遍

| # | 任务 | 验收标准 |
|---|------|----------|
| 2.1 | AI 拍摄引导（init→partial→good→ready）| 引导正常 |
| 2.2 | PoseOverlayView（骨骼叠加）| 可视化正常 |
| 2.3 | 训练执行页（120pt计数 + 评分 + TTS + 错误提示）| 界面正常 |
| 2.4 | 每组确认弹窗 + SQLite 写入 | 持久化正常 |
| 2.5 | 训练完成页 + Apple Health 写入 | Health App 可见 |
| 2.6 | 训练日志列表页 | 历史正常显示 |
| 2.7 | 训练详情页 | 数据正确 |
| 2.8 | Profile 编辑页 | 保存成功 |
| 2.9 | **完整流程测试**：首页→选择→引导→训练→保存→日志 | 全流程跑通 |
| 2.10 | **xcodebuild build** | 编译通过 |
| 2.11 | **✅ Phase 2 停止点**：通知用户"核心流程完成"，附截图 |

### Phase 3：优化 + 测试 + 上架

**目标**：App Store 可提交

| # | 任务 | 验收标准 |
|---|------|----------|
| 3.1 | 设置页（TTS 开关）| 生效 |
| 3.2 | MET 卡路里估算 | 计算正确 |
| 3.3 | iPhone 15 帧率测试 | ≥30fps |
| 3.4 | 闪屏页 | 体验完整 |
| 3.5 | 端到端复测 | 无崩溃 |
| 3.6 | App Store 截图 + 文案 | 符合规范 |
| 3.7 | 隐私政策页面 | App Store 要求 |
| 3.8 | TestFlight 打包 + 提交 | 提交成功 |
| 3.9 | **✅ Phase 3 停止点**：通知用户"App 已提交审核" |

### 防无限跑机制

**触发「强制停止并汇报」的条件**：

| 触发条件 | 动作 |
|----------|------|
| 单个 Phase 耗时 > 预计 2 倍 | 停止，列出已完成/未完成/问题 |
| 编译错误 > 30 分钟 | 停止，列出错误和尝试的解决 |
| 计数误差 > 3 次 | 停止，等待用户决策 |
| 到达 Phase 边界 | **必须停止**，不自动继续 |
| 用户主动要求 | 立即停止，输出当前进度 |

---

## 七、测试工具

| 工具 | 用途 | 命令 |
|------|------|------|
| xcodebuild | 编译测试 | `xcodebuild build -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 \| tail -20` |
| XCTest | UI 测试 | `xcodebuild test -workspace IronBuddy.xcworkspace -scheme IronBuddy -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 \| grep -E "Test\|FAIL\|PASS"` |
| simcamera | 模拟摄像头 | `simcamera inject --device "iPhone 15" /path/to/video.mp4` |
| Instruments | 帧率/内存 | Xcode → Open Developer Tool → Instruments |

**常见编译错误**：

| 错误 | 解决 |
|------|------|
| Cannot find module 'MediaPipeTasksVision' | Xcode → Packages → Reset Packages |
| Camera permission denied | 添加 NSCameraUsageDescription |
| HealthKit authorization failed | 添加 HealthKit entitlements |
| Thread 1: Fatal error: nil | 用 if let / guard let 替代 ! |

---

## 八、验收标准

| 测试项 | 通过标准 |
|--------|----------|
| 俯卧撑识别 | 10次，误差 ≤1 |
| 深蹲识别 | 10次，误差 ≤1 |
| 硬拉识别 + 6类错误提示 | 10次，误差 ≤1，每类均可触发 |
| 语音播报 | 每组完成有语音 |
| Apple Health 写入 | 健康 App 可见 |
| Apple Health 读取 | 日志页显示历史 |

| 机型 | 帧率 |
|------|------|
| iPhone 15 | ≥30fps |

| 检查项 | 标准 |
|--------|------|
| 网络权限 | Info.plist 不含网络权限 |
| HealthKit | entitlements 已配置 |
| 数据存储 | 100% 本地 SQLite + Apple Health |

---

## 九、里程碑

| 里程碑 | 内容 | 停止点 |
|--------|------|--------|
| M1 | 项目可编译，模拟器运行 | Phase 0 |
| M2 | 三动作计数 + 实时纠错 | Phase 1 |
| M3 | 完整训练流程闭环 | Phase 2 |
| M4 | App Store 提交 | Phase 3 |

---

## 十、开发效率提升建议

### 10.1 测试视频：用 App 自己拍

**工作流程**：

```
Phase 2 AI引导页完成 → Shane 用 App 拍测试视频
                         → 存到工作文件夹
                         → vibe coding 调参用
```

**拍摄要求**：

| 动作 | 数量 | 要求 |
|------|------|------|
| 俯卧撑正确姿势 | 1段1分钟 | 正面，前置摄像头，匀速 |
| 深蹲正确姿势 | 1段1分钟 | 侧身，后置摄像头，匀速 |
| 硬拉正确姿势 | 1段1分钟 | 侧身，后置摄像头，含上拉下放 |
| 硬拉/深蹲/俯卧撑错误姿势 | 各1段 | 驼背/膝盖内扣等 |

### 10.2 先 print 调试，再做骨骼叠加

```swift
func process(landmarks: [NormalizedLandmark]) {
    let elbowAngle = calculateAngle(landmarks[11], landmarks[13], landmarks[15])
    print("DEBUG: 肘角=\(elbowAngle.formatted(.fixed(precision: 1)))° 状态=\(state) 次数=\(completedReps)")
}
```

### 10.3 阈值写成配置文件

```swift
// Utilities/Constants.swift
struct AngleThresholds {
    static let pushup_elbow_ready = 170.0
    static let pushup_elbow_down = 140.0
    static let pushup_elbow_up = 165.0
    static let squat_standing = 160.0
    static let squat_bottom = 100.0
    static let deadlift_start_ankle = 30.0
    static let deadlift_start_hip = 70.0
    static let back_linearity_threshold = 0.08
    static let knee_valgus_ratio = 1.1
}
```

### 10.4 Phase 1 和 Phase 2 可并行

| Agent A（算法）| Agent B（UI 框架）|
|----------------|------------------|
| CameraService | 项目结构搭建 |
| MediaPipe 集成 | NavigationStack |
| Pushup/Squat/Deadlift Counter | HomeView / ActionSelectView |
| → Phase 1 停止点 | → 提供 UI 壳，供 Phase 2 使用 |

### 10.5 HealthKit 提前验证

Phase 2 最开始先测 HealthKit 写入，验证 entitlements 配置正确。

---

## 十一、Phase 工作流程（全貌）

```
开始
  │
  ▼
Phase 0：项目初始化
  └─ 完成 → 通知 Shane 确认
            │
  ▼
Phase 1：姿态识别算法（可与 Phase 2 并行）
  └─ 完成 → 通知 Shane「算法完成，附测试结果」
            │
  ▼
Phase 2：UI + 训练流程
  └─ Shane 用 App 拍测试视频（AI 引导功能实测）
  └─ 完成 → 通知 Shane「核心流程完成，附截图」
            │
  ▼
Phase 3：优化 + 测试 + 上架
  └─ 完成 → 通知 Shane「App 已提交审核」
            │
  ▼
结束
```

---

## 十二、个人化评价系统（V1.1 核心功能）

### 12.1 设计原则

**核心思想**：不跟别人比，只跟自己比。每个用户的柔韧性/关节活动度（ROM）不同，固定角度阈值不适用。

### 12.2 Onboarding 柔韧性测试

**时机**：用户首次进入 App 时（Profile 未建立时），强制进入 Onboarding 流程。

**流程**：3 分钟，完成后数据写入 Profile。

**测试动作（3个）**：俯卧撑、深蹲、硬拉各做3次慢速动作，系统记录个人ROM。

**记录数据**：

```swift
struct PersonalBaseline {
    var pushupElbowMin: Double = 0
    var pushupElbowMax: Double = 0
    var squatKneeMin: Double = 0
    var squatKneeMax: Double = 0
    var deadliftHipMin: Double = 0
    var deadliftHipMax: Double = 0
    var leftShoulderROM: Double = 0
    var rightShoulderROM: Double = 0
    var painPoints: Set<String> = []
    var isCalibrated: Bool = false
}
```

### 12.3 疼痛记录

```swift
struct PainQuestionnaire {
    var questions: [(area: String, question: String)] = [
        ("shoulder", "肩部是否有疼痛或不适？"),
        ("knee", "膝盖是否有疼痛或不适？"),
        ("lower_back", "腰部是否有疼痛或不适？")
    ]
    var answers: [String: Bool] = [:]
}

var deadliftDepthLimit: Double = painPoints.contains("lower_back") ? 80.0 : 45.0
```

### 12.4 动态评价等级

```swift
class MotionEvaluator {
    enum Grade: String {
        case excellent = "极好"    // 深于个人标准 0-5°
        case good = "好"          // 浅于个人标准 5-15°
        case fair = "一般"        // 浅于个人标准 15-25°
        case poor = "差"          // 浅于个人标准 25-40°
        case danger = "⚠️ 危险"   // 浅于个人标准 >40°
    }

    func evaluate(currentAngle: Double, personalBottom: Double) -> Grade {
        let deviation = currentAngle - personalBottom
        switch deviation {
        case ..<5:   return .excellent
        case 5..<15: return .good
        case 15..<25: return .fair
        case 25..<40: return .poor
        default:      return .danger
        }
    }

    func voicePrompt(for grade: Grade) -> String? {
        switch grade {
        case .excellent, .good, .fair: return nil
        case .poor:      return "再深一点"
        case .danger:    return "太浅了，注意安全"
        }
    }
}
```

### 12.5 趋势分析（Session 之间）

```swift
struct WeeklyTrend {
    var exerciseType: String
    var excellentRatio: Double
    var goodRatio: Double
    var warningCount: Int
}
```

**危险信号**：连续 2 周「极好」率下降 >15% → App 内推送"注意：你的动作质量有所下降，可能是疲劳信号"。

### 12.6 分左右侧基准

```swift
struct SideSpecificBaseline {
    var left: Double = 0
    var right: Double = 0
}
```

### 12.7 个人基准更新机制

```swift
func updateBaseline(newAngle: Double, currentBaseline: Double) -> Double {
    let delta = newAngle - currentBaseline
    let maxShift = 2.0
    let clampedDelta = max(-maxShift, min(maxShift, delta))
    return currentBaseline + clampedDelta
}
```

---

## 十三、Vibe Coding 边界定义

### 13.1 Vibe Coding 必须实现的

- ✅ MediaPipe 姿态识别实时流集成
- ✅ 角度计算函数（向量点积）
- ✅ 三个动作的计数状态机（Pushup/Squat/Deadlift）
- ✅ 6类硬拉错误检测逻辑
- ✅ PersonalCalibrator 类（Onboarding 录制+基准建立）
- ✅ MotionEvaluator 类（动态评价等级）
- ✅ 阈值写入 Constants.swift
- ✅ 数据库 Schema（含 PersonalBaseline 字段）
- ✅ Apple Health 读写
- ✅ LocalTTSService
- ✅ 10个页面 UI（SwiftUI Views）
- ✅ xcodebuild 编译验证

### 13.2 Vibe Coding 禁止自行决定的

| 场景 | 原因 | 预期动作 |
|------|------|----------|
| 角度阈值需要调整 >5° | 影响动作识别准确性 | 停止，列出当前值和推荐值，等待确认 |
| 评价等级边界需要修改 | 涉及用户体验和医学判断 | 停止，说明修改理由，等待确认 |
| 新增错误检测类型 | 可能引入误判 | 停止，提供分析，等待确认 |
| 疼痛用户降低标准的幅度 | 医学相关，需专业人士判断 | 停止，建议咨询健身教练或物理治疗师 |
| 算法逻辑变更 | 核心价值，可能影响 V1.0 方向 | 停止，列出变更内容和影响，等待确认 |

### 13.3 强制停止条件

```
⚠️ 强制停止条件（任意一条）：
1. 计数误差连续 >3 次 → 停止，列出误差场景，分析原因
2. 某个动作识别率 <80% → 停止，提供测试数据，等待确认
3. HealthKit 写入失败 >2 次 → 停止，列出错误日志
4. 编译错误 >30 分钟无法解决 → 停止，列出所有尝试的错误
5. 任何人质疑：「这样对吗？」 → 立即停止，不要假设
6. 发现需求文档中没有的功能想法 → 停止，不要自行实现，汇报给 Shane
```

### 13.4 调参边界（Vibe Coding 可自行决定）

| 参数 | 可调整范围 | 调整理由 |
|------|-----------|----------|
| 角度阈值 | ±3° 以内 | 实测微调 |
| 极好/好/一般/差/危险 边界 | ±2° 以内 | 用户反馈微调 |
| TTS 播报触发条件 | .poor 及以上 | 减少噪音 |
| 基准更新步进 | 1-3° | 稳定性调参 |
| 健康提示文案措辞 | 同义替换 | 提升用户体验 |

---

## 十四、个人化评价数据库 Schema

```swift
// === profile 表新增字段 ===
CREATE TABLE profile (
    id INTEGER PRIMARY KEY,
    weight_kg REAL,
    age INTEGER,
    gender TEXT,

    -- Onboarding 柔韧性基准
    is_calibrated INTEGER DEFAULT 0,
    pushup_elbow_min REAL,
    pushup_elbow_max REAL,
    squat_knee_min REAL,
    squat_knee_max REAL,
    deadlift_hip_min REAL,
    deadlift_hip_max REAL,

    -- 分左右侧
    left_elbow_baseline REAL,
    right_elbow_baseline REAL,
    left_knee_baseline REAL,
    right_knee_baseline REAL,

    -- 疼痛记录
    pain_points TEXT,

    created_at TEXT,
    updated_at TEXT
);

// === workout_sets 表新增字段 ===
CREATE TABLE workout_sets (
    id INTEGER PRIMARY KEY,
    workout_id INTEGER REFERENCES workouts(id),
    set_number INTEGER,
    reps INTEGER,
    weight_kg REAL,

    -- 评价数据
    avg_angle REAL,
    avg_grade TEXT,
    danger_count INTEGER DEFAULT 0,
    excellent_count INTEGER DEFAULT 0,
    score REAL
);
```

---

## 十五、进阶功能（V1.1 新增）

### 15.1 实时语音指导（V1.0 核心差异化）

**定位**：比错误警告更进一步，"会说话"的私教。

| 时机 | 内容 | 示例 |
|------|------|------|
| 节奏提示 | 下蹲/起身速度 | "慢一点，2秒下" |
| 呼吸提醒 | 下蹲吸气、起立呼气 | "下蹲，请吸气" |
| 正向激励 | 动作正确时 | "很好，保持这个节奏" |
| 进度提示 | 每隔一定次数 | "第8个了，再来2个" |
| 即将力竭 | 速度明显变慢 | "最后几个了，加油" |

**实现注意**：TTS 播报不打断计数（并行）；同一类型的提示有冷却时间（至少3秒）；差/危险评价时，优先播报警告。

```swift
class VoiceCoach {
    func shouldSpeak(_ guidance: Guidance, lastSpokenAt: Date?) -> Bool {
        let cooldown: TimeInterval = 3.0
        if let last = lastSpokenAt, Date().timeIntervalSince(last) < cooldown {
            return false
        }
        return true
    }
}
```

### 15.2 组间休息计时器

**触发时机**：每组确认完成后自动启动。

**计时规则**：
- 默认 90 秒（可配置 30s/60s/90s/120s）
- 语音播报：启动时"休息60秒" → 剩余30秒"还剩30秒" → 结束"休息结束，准备好了吗"
- **纯语音，不用震动

**UI**：
```
┌─────────────────────────┐
│       组间休息           │
│          0:47            │ ← 大字体
│     "还剩30秒"           │
│  [跳过休息]  [延后30秒]   │
└─────────────────────────┘
```

### 15.3 移出画面处理

**检测**：MediaPipe 关键点 visibility 连续 <0.3 超过 1 秒 → 判定为"离开画面"。

**处理流程**：

```
检测到离开画面
  → 立即语音："检测到你离开了，请回到画面"
  → 计数暂停（不重置次数）
  → 组间倒计时暂停（如在休息中）

回到画面
  → 语音："继续"
  → 从离开前的次数继续计数
  → 组间倒计时继续

超过 30 秒未返回
  → 语音："是否继续训练？"
  → 显示选项：
      [继续当前组]    → 继续，次数保留
      [结束本组]       → 结束，进入确认页
      [放弃训练]       → 确认后保存数据
```

**状态保留**：

```swift
struct SessionState {
    var currentReps: Int = 0
    var currentSet: Int = 1
    var isCountingPaused: Bool = false
    var pauseReason: String? = nil
    var restTimeRemaining: TimeInterval? = nil
}
```

### 15.4 呼吸检测（可选）

**技术可行性**：iOS 的 `AVAudioEngine` 可接入麦克风做简单气流检测（无需特殊权限）。

**功能设计**：
- 硬拉/深蹲时提示"下蹲吸气，起立呼气"
- 检测到憋气 → 提示"请保持呼吸"

**注意**：此功能为可选，技术验证后如不可行可降级为纯视觉检测。

### 15.5 Onboarding 跳过处理

**规则**：用户可跳过 Onboarding，但评价标准降级。

**跳过后的默认标准**（初级保守值）：

| 动作 | 底部角度默认值 |
|------|---------------|
| 俯卧撑 | 肘角 120° |
| 深蹲 | 膝角 110° |
| 硬拉 | 髋角 80° |

**动态调整**：跳过 Onboarding 的用户，训练次数越多，提示完成Onboarding越频繁。

---

## 十六、实现细节附录

### 16.1 MediaPipe Tasks Vision iOS API 调用

**官方文档**：
```
https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
https://github.com/google/mediapipe/tree/master/mediapipe/tasks/ios/vision
```

**核心调用流程**：

```swift
import MediaPipeTasksVision

let modelPath = Bundle.main.path(forResource: "pose_landmarker.task", ofType: nil)!
let options = PoseLandmarkerOptions()
options.baseOptions.modelAssetPath = modelPath
options.runningMode = .liveStream
options.poseLandmarkerCallback = { result, error in
    guard let landmarks = result?.landmarks.first else { return }
    self.counter.process(landmarks: landmarks)
}
let poseLandmarker = try PoseLandmarker(options: options)

func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    frameCount += 1
    if frameCount % 2 == 0 {
        try? poseLandmarker.detectAsync(pixelBuffer, timestampInMs: Int64(frameCount * 33))
    }
}
```

**关键点**：实时流模式（`.liveStream`）；每2帧处理1次；`timestampInMs` 需单调递增。

### 16.2 摄像头配置方案

| 动作 | 默认摄像头 | 说明 |
|------|-----------|------|
| 深蹲 | 后置（侧拍）| 手机固定在侧面支架上 |
| 硬拉 | 后置（侧拍）| 同上，固定后不翻转 |
| 俯卧撑 | 后置（斜前方）| 推荐：用户躺在垫子上看屏幕，斜向下30°拍摄 |

**前置摄像头选项**：用户可主动切换为前置；切换后自动进入 AI 引导，重新校准。

**前置镜像处理**：

```swift
func mirrorLandmarks(_ landmarks: [NormalizedLandmark]) -> [NormalizedLandmark] {
    return landmarks.map { landmark in
        var mirrored = landmark
        mirrored.x = 1.0 - landmark.x
        return mirrored
    }
}
```

### 16.3 TTS 队列管理

```swift
class TTSQueue {
    struct TTSItem {
        let text: String
        let priority: Int        // 0=最高（危险警告），1=高，2=中，3=低
        let canInterrupt: Bool
    }

    func speak(_ text: String, priority: Int = 2, canInterrupt: Bool = false) {
        let item = TTSItem(text: text, priority: priority, canInterrupt: canInterrupt)
        if priority == 0 && isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            queue.removeAll()
            isSpeaking = false
        }
        queue.append(item)
        queue.sort { $0.priority < $1.priority }
        playNext()
    }
}

// 使用
tts.speak("⚠️ 请挺直背部", priority: 0, canInterrupt: true)  // 危险警告，打断一切
tts.speak("第8个", priority: 2)
```

**优先级**：0=危险警告（打断一切），1=提醒，2=正常播报，3=低优先级。

### 16.4 学习模式（Calibration Phase）

- 显示实时倒数（3/5、2/5...）
- 实时显示当前角度和评价
- **5次均计入训练总数**
- 学习期间可随时退出（已录数据有效）

### 16.5 HealthKit 拒绝处理

```swift
func handleHealthKitDenied() {
    showToast("训练数据已保存至本地。\n开启 Apple Health 可将数据同步至健康 App。")
}
```

### 16.6 模拟器测试规范

```swift
let testConfig = PoseDetectorConfig(
    numPoses: 1,
    minPoseDetectionConfidence: 0.5,
    minPosePresenceConfidence: 0.5,
    minTrackingConfidence: 0.5
)
let frameSkip = 2  // 每2帧处理1帧
```

### 16.7 暗光环境检测

```swift
func detectLowLight(from device: AVCaptureDevice) -> Bool {
    let isoRatio = device.iso / device.activeFormat.maxISO
    let exposureRatio = device.exposureDuration.seconds / device.exposureDuration.range.max
    return isoRatio > 0.6 || exposureRatio > 0.5
}

func handleLowLight() {
    showBanner("光线较暗，建议开启补光以提高识别准确性")
    tts.speak("光线较暗", priority: 1)
}
```

### 16.8 数据库版本迁移

```swift
// settings 表
key = "db_version", value = "1"

func migrateIfNeeded() {
    let currentVersion = getSetting("db_version") ?? "0"
    switch currentVersion {
    case "0":
        createV1Schema()
        setSetting("db_version", "1")
    default:
        break
    }
}
```

**迁移原则**：只增字段，不删字段；不改已有字段类型；迁移失败不崩溃。

---

## 十七、四动作风险识别体系

### 17.1 动作清单（V1.1 全部支持）

| 动作 | 摄像头 | 计数状态机 | 风险识别 |
|------|--------|-----------|----------|
| 俯卧撑 | 前置/斜前方 | ✅ 四状态 | ✅ 5类 |
| 深蹲 | 后置侧拍 | ✅ 四状态 | ✅ 3类 |
| 硬拉 | 后置侧拍 | ✅ 四阶段 | ✅ 6类 |
| **卧推** | **后置（头部方向）** | ✅ 四状态 | ✅ **6类** |

### 17.2 卧推计数算法

**摄像头位置**：手机放在卧推凳头部方向，俯视角度拍摄。

```swift
class BenchPressCounter {
    enum State { case idle, ready, down, up }
    var state: State = .idle
    var completedReps: Int = 0

    func process(landmarks: [NormalizedLandmark]) {
        let elbowFlexion = calculateAngle(landmarks[13], landmarks[15], landmarks[11])
        switch state {
        case .idle:
            if elbowFlexion > 150 { state = .ready }
        case .ready:
            if elbowFlexion < 90 {
                state = .down
                lastDownTimestamp = Date()
            }
        case .down:
            if elbowFlexion > 150 {
                let duration = Date().timeIntervalSince(lastDownTimestamp ?? Date())
                if duration < 1.0 {
                    speak("控制下落", priority: 1)
                }
                state = (duration > 0.5) ? .up : .idle
            }
        case .up:
            state = .idle
            completedReps += 1
            speak("\(completedReps)")
        }
    }
}
```

### 17.3 四动作风险识别完整表

#### 俯卧撑（5类）

| 错误类型 | 检测条件 | 提示文案 | 受伤风险 |
|----------|----------|----------|----------|
| 塌腰 | 髋角 <160° | ⚠️ 请收紧腹部，保持身体平直 | 腰椎下塌压力 |
| 肘外翻 | 肘角外展 >30° | ⚠️ 肘部贴近身体，减少肩部压力 | 肩袖肌群损伤 |
| 头部前探 | 头部相对肩膀前移 >10% | ⚠️ 头部保持中立，目视地面 | 颈椎压力 |
| 下落太快 | 单次下落 <1秒 | ⚠️ 控制下落，减少关节冲击 | 肘/肩 冲击伤 |
| 深度不足 | 肘角 <90° | ⚠️ 再深一点 | 肌肉激活不足 |

#### 深蹲（3类）

| 错误类型 | 检测条件 | 提示文案 | 受伤风险 |
|----------|----------|----------|----------|
| 膝盖内扣 | 膝角外偏 >10° | ⚠️ 膝盖朝向脚尖 | 前十字韧带撕裂 |
| 腰椎弯曲 | 背线性度 >0.08 | ⚠️ 请挺直背部 | 腰椎间盘损伤 |
| 腰先动 | 髋角恢复滞后膝角 >15° | ⚠️ 臀部先发力 | 下背代偿 |

#### 硬拉（6类）

| 错误类型 | 检测条件 | 提示文案 | 受伤风险 |
|----------|----------|----------|----------|
| 腰椎弯曲 | backLinearity > 0.08 | ⚠️ 请挺直背部 | 腰椎间盘损伤 |
| 膝盖内扣 | kneeOffset > ankleOffset × 1.1 | ⚠️ 膝盖朝向脚尖 | 前十字韧带撕裂 |
| 髋主导缺失 | 髋角恢复慢于膝角 | ⚠️ 臀部先发力 | 下背代偿 |
| 铃片磕腿 | 髋位移 > 踝宽 20% | ⚠️ 贴近小腿拉起 | 髋关节撞击 |
| 头部前倾 | 耳屏点相对肩点前移 > 5% | ⚠️ 头部保持中立 | 颈椎压力 |
| 臀位过低启动 | 启动时髋角 < 45° | ⚠️ 臀部稍抬高 | 腰椎过度弯曲 |

#### 卧推（6类）

| 错误类型 | 检测条件 | 提示文案 | 受伤风险 |
|----------|----------|----------|----------|
| 肘外展过度 | 肘角外展 >90° | ⚠️ 肘部外展不超90度，保护肩关节 | 肩袖肌群损伤 |
| 腰椎过度拱起 | 肩-髋提升差 >15% 身高 | ⚠️ 腰部适度抬起即可，不要过度拱背 | 腰椎剪切力 |
| 落点偏心 | 杠铃偏向一侧 >5% 肩宽 | ⚠️ 杠铃垂直上下，减少肩部压力 | 肩关节不平衡 |
| 推起时肩缩 | 肩点前移 >10% | ⚠️ 推起时肩胛骨保持收紧 | 肩关节不稳定 |
| 不完全锁定 | 肘角 <160° | ⚠️ 推到顶部完全伸直 | 肌肉激活不足 |
| 速度过快 | 单次 <1秒 | ⚠️ 控制速度，减少关节冲击 | 肘关节冲击伤 |

### 17.4 统一错误提示架构

```swift
struct ExerciseRisk {
    let type: String
    let message: String
    let risk: String
    let severity: Severity  // .critical / .warning / .info
}

enum Severity {
    case critical  // 立即语音警告，打断当前TTS
    case warning   // 显示提示，语音排队
    case info      // 仅显示
}

class RiskDetector {
    func detect(exercise: ExerciseType, landmarks: [NormalizedLandmark]) -> ExerciseRisk? {
        switch exercise {
        case .pushup: return detectPushupRisk(landmarks)
        case .squat: return detectSquatRisk(landmarks)
        case .deadlift: return detectDeadliftRisk(landmarks)
        case .benchPress: return detectBenchPressRisk(landmarks)
        }
    }
}
```

### 17.5 卧推摄像头位置说明

```
卧推凳（俯视图）：

        [手机支架]
           ↓
    ←───  ●  ───→
   脚部   ↑    头部
         拍摄方向
          ↓
      [用户躺在凳上]
```

手机放在凳子头部朝向脚的方向，俯视角度拍摄。手机支架夹在凳子头部，或用落地支架从头部上方45°俯拍。

---

## ⚠️ 第二章「明确排除」修订

~~原文：❌ 卧推等需遮挡处理的动作~~

**修订**：卧推已纳入 V1.1，删除此排除项。

**现行排除清单**：
- ❌ 账号体系 / 登录
- ❌ Feishu 文档导出（→ V2.0）
- ❌ AI 个性化训练计划（→ V3.0）
- ❌ AirPods 心率（→ V2.0）
- ❌ 云端同步
- ❌ 社区 / 论坛

---

*开发作业书出品：Peishen Studio | 版本：V1.1 终稿 | 2026-03-31*
