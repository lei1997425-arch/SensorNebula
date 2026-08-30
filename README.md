# 传感星云 Sensor Nebula

传感星云是一款面向 Apple Silicon Mac 的本地硬件传感器可视化应用。它将 Mac 的运动、环境、触控板和设备状态数据转换为直观的实时界面，并提供与真实姿态同步的 3D MacBook 展示。

## 主要功能

- 实时显示三轴加速度、角速度与微振动波形
- 显示机身前后倾斜、左右倾斜与相对水平转向
- 显示屏幕开合角度并同步驱动 3D MacBook 模型
- 使用 ScreenCaptureKit 将当前桌面实时映射到 3D 模型屏幕
- 可视化 Force Touch 触控板触点、接触面积与相对压力
- 显示环境光、电池、供电方式、热状态和运行时间
- 提供实验性 BCG 心率估算与可信度
- 支持本地数据记录与 CSV 导出
- 深色与日间主题

## 隐私

- 传感器和屏幕数据仅在本机处理
- 不要求账户，不进行云端同步
- 不包含用户追踪或行为分析
- 屏幕画面只用于当前 Mac 上的 3D 实时预览

## 系统要求

- Apple Silicon Mac
- macOS 15 或更高版本
- Xcode 16 或更高版本
- Swift 6

不同 Mac 型号暴露的传感器不同。运动传感器、屏幕角度、Force Touch 与 SMC 等部分能力依赖非公开或机型相关接口，不保证在所有设备和 macOS 版本上可用。

## 本地构建

```bash
swift build -c release
```

触控板辅助程序：

```bash
clang -O2 TouchBridge/touch_bridge.c -o TouchBridge/touch_bridge \
  -framework Foundation -framework CoreFoundation -framework IOKit
```

运动传感器桥接目录通过环境变量配置：

```bash
export SENSOR_NEBULA_BRIDGE_ROOT=/path/to/apple-silicon-accelerometer
```

正式分发需要开发者自行配置 Developer ID、Hardened Runtime 和 Apple Notary Service。仓库不包含任何签名证书、私钥或公证凭据。

## 3D 模型

项目使用的 MacBook 3D 模型来源和许可信息记录在 [`MODEL_CREDITS.txt`](Sources/SensorNebula/Resources/MODEL_CREDITS.txt)。使用或再分发前请自行确认模型许可和 Apple 商标要求。

## 重要声明

传感星云不是医疗设备。心率、压力、姿态及其他推算数据仅用于实验、娱乐和技术研究，不应作为健康诊断、安全判断或专业测量依据。

Copyright © 2026. All rights reserved.
