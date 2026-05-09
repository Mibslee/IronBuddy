# Changelog

## v1.5 (2026-05-09)

### Bug Fixes
- 修复俯卧撑/卧推姿势不标准时静默拒绝计数的问题，改为语音警告
- 修复深蹲计数逻辑：从定时等待改为状态转换即时计数
- 修复硬拉状态机 `.lower` 阶段重置逻辑
- 修复 `AngleCalculator` 共线退化返回 0 改为 `Double.nan`
- 修复 `CalorieEstimator` 四舍五入精度
- 修复 `HealthKitService` 在失败时误写 UserDefaults
- 修复 `LocalTTSService` 中文语音回退
- 修复语音指令服务无限重启循环，加 3 次重试上限 + 指数退避
- 修复 `CameraService.onFrame` 线程安全（NSLock）
- 修复 `AppState.resetTrainingDraftForNewWorkout()` 未清除回放数据

### Counter Improvements
- 俯卧撑/卧推：增加 `repTooFast`/`repTooSlow` 警告类型与严重等级
- 深蹲：从 2 秒定时等待改为 bottom→standing 状态转换即时计数
- 硬拉：`.lower` 阶段回到 `.start` 而非 `.idle`，新增 2 秒静态检测冷却
- 硬拉：髋铰链角度阈值从 2° 提高到 5°
- 所有计数器：魔数移至 `AngleThresholds` 枚举

### UI/UX
- 新增 Theme 语义状态色（successGreen/warningOrange/dangerRed/overlayBlack/subtleOverlayBorder）
- 修复 11 个视图文件 42 处硬编码颜色，全面适配深色/浅色模式
- 统计/成就页面添加空状态引导（ContentUnavailableView）
- 动作回放播放控制添加无障碍标签
- 移除 `UIScreen.main`（iOS 26 废弃 API）

### Code Quality
- 提取 `formatDuration()` 共享函数到 Constants.swift
- ProfileView UserDefaults key 统一使用 `UserDefaultsKeys` 常量
- 修复 4 处 asyncAfter 闭包强引用
- 数据库连接改为共享单例 + NSLock
- 数据库添加 `exercise_records.session_id` 索引
- CSV 导出修复引号转义

### Tests
- 14/14 单元测试全部通过
- 新增 `@Suite(.serialized)` 确保测试隔离
- FormWarning 使用 WarningType 枚举替代字符串

---

## v1.0 (Initial Release)

- 四大复合动作：俯卧撑 / 深蹲 / 硬拉 / 卧推实时识别与计数
- V2.0 智能辅助：热身引导、动作慢放回看、自适应强度建议
- 预置训练计划：新手入门、上肢力量、下肢爆发、全身训练
- HealthKit 同步训练时长与热量
- 离线语音播报与语音指令
- 完全本地运行，零数据上传
