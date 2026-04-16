---
layout: default
title: 隐私政策 · IronBuddy
---

# IronBuddy 隐私政策

**最后更新日期：2026-04-16**

铁伴儿（IronBuddy，以下简称"本 App"）由 Shane Studio 开发和维护。我们尊重并保护所有使用本 App 用户的个人隐私。本政策说明本 App 如何采集、使用、存储和保护您的数据。

## 一、核心原则：本地优先，零上传

**本 App 所有功能完全在您的设备上本地运行。我们不收集、不上传、不分享您的任何个人数据到任何服务器。**

- 没有后端服务器
- 没有用户账户系统
- 没有广告 SDK
- 没有第三方分析 / 崩溃上报
- 没有 Cookie / 追踪标识

## 二、本 App 需要的设备权限及用途

| 权限 | 用途 | 数据是否离开设备 |
|------|------|------------------|
| **相机** | 实时拍摄用户动作，供本地 MediaPipe 姿态识别模型分析骨架关键点，实现动作计数与姿态纠错 | ❌ 不离开设备。画面不保存、不录像、不上传 |
| **麦克风** | 接收语音指令（如"开始""停止""下一组"） | ❌ 不离开设备。识别在设备本地完成 |
| **语音识别** | 使用苹果系统 `SFSpeechRecognizer` 离线模式将语音转为文字指令 | ❌ 强制离线模式（`requiresOnDeviceRecognition = true`） |
| **HealthKit 读写** | 将训练数据（时长、热量、次数）写入 Apple 健康 App，供您在健康 App 中统一查看 | ❌ 数据写入您本机的健康 App，由 Apple 系统管理 |

您可以随时在 iOS 系统"设置 → 隐私与安全性"中撤销以上任一权限。撤销后相应功能会不可用，但不影响其他功能。

## 三、本 App 在设备上存储的内容

以下数据仅保存在您的 iPhone / iPad 本机，并随 App 卸载一同删除：

- **训练历史**：每次训练的动作、次数、组数、时长、估算热量（SQLite 数据库）
- **用户资料**：您在"资料"页填写的身高体重（用于计算热量估算）
- **应用设置**：语音播报开关、外观模式、训练水平（新手/老手）等偏好
- **成就记录**：本地完成的训练徽章统计

**我们不会读取您的：**
- 通讯录、照片、文件、位置
- 剪贴板、日历、提醒事项
- 浏览历史、设备识别码

## 四、儿童隐私

本 App 不针对 13 岁以下儿童设计。我们不会故意收集儿童的个人信息。如果您发现儿童在未经监护人同意的情况下使用本 App，请联系监护人协助管理。

## 五、第三方组件

本 App 使用以下开源 / 官方第三方组件，它们均在本地运行，不进行网络通信：

- **MediaPipe Tasks Vision** (Google, Apache 2.0)：本地姿态识别
- **SQLite.swift** (Stephen Celis, MIT)：本地数据库
- **pose_landmarker.task** (Google BlazePose Lite)：姿态识别模型文件

本 App 不集成任何广告 SDK、分析 SDK（如 Firebase、友盟、Sensors Analytics 等）或社交分享 SDK。

## 六、数据安全

- 本地 SQLite 数据库保存在 iOS 沙盒 `Documents/` 目录，受 iOS 系统沙盒保护
- 通过系统数据保护机制（Data Protection）在设备锁屏时加密
- 卸载 App 时所有本地数据随之删除

## 七、您的权利

您可以随时：

- **查看**：在 App "历史"页查看所有训练记录
- **删除**：卸载 App 即删除所有本地数据；或在健康 App 中删除同步写入的训练记录
- **撤销权限**：在 iOS 系统设置中撤销相机/麦克风/语音识别/健康数据权限

## 八、政策变更

若本政策发生重大变更，我们会在本页面更新"最后更新日期"并在 App 内醒目位置通知您。请您定期查阅本页面以了解最新政策。

## 九、联系我们

如对本政策有任何疑问，请通过以下方式联系：

- **GitHub Issues**：[github.com/Mibslee/IronBuddy/issues](https://github.com/Mibslee/IronBuddy/issues)
- **开发者**：Shane Studio

---

> **English summary**: IronBuddy is a fully on-device iOS fitness app. No data is collected, uploaded, or shared. Camera frames, microphone audio, and voice recognition all process locally; health data is written only to your device's Apple Health. See Chinese version above for full details.
