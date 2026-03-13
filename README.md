# DockPin

Pin your macOS Dock to a single display — no more Dock jumping between screens.

---

## Table of Contents / 目录

- [English Tutorial](#english-tutorial)
- [中文教程](#中文教程)

---

## English Tutorial

### What is DockPin?

DockPin is a lightweight command-line tool that pins your macOS Dock to one specific display. On multi-monitor setups, macOS moves the Dock to whichever screen you drag your mouse to the bottom of. DockPin monitors this and moves the Dock back automatically.

### Prerequisites

1. **macOS 13 (Ventura) or later**
2. **Swift compiler** — comes with Xcode Command Line Tools. Install with:
   ```bash
   xcode-select --install
   ```
3. **Screen Recording permission** — DockPin needs to read window information. Go to:
   **System Settings > Privacy & Security > Screen Recording**, and enable your terminal app (e.g. Terminal, iTerm2, Warp).

### Build

```bash
cd ~/Projects/DockPin
swiftc -o dockpin Sources/main.swift -framework AppKit -framework CoreGraphics
```

### Usage

#### 1. List your displays

```bash
./dockpin list
```

Output example:

```
Available displays:
  1: 1512x982 (main) [ID: 1]
  2: 2560x1440 [ID: 3]
```

Each display is assigned a number. `(main)` indicates your primary display.

#### 2. Check where the Dock is now

```bash
./dockpin status
```

Output example:

```
Dock is on display 1: 1512x982 (main) [ID: 1]
```

#### 3. Pin the Dock to a display

```bash
./dockpin pin 2
```

This pins the Dock to display 2. The tool runs in the foreground and monitors continuously. Whenever the Dock moves away, it automatically moves it back.

Output example:

```
Pinning Dock to display 2: 2560x1440
Press Ctrl+C to stop.

[14:32:07] Dock drifted — moving back to display 2
```

#### 4. Stop pinning

Press **Ctrl+C** in the terminal to stop DockPin. The Dock will resume normal behavior.

### Optional: Install to PATH

To run `dockpin` from anywhere:

```bash
sudo cp ./dockpin /usr/local/bin/
```

Then use it simply as:

```bash
dockpin list
dockpin pin 2
```

### Optional: Run in the background

```bash
nohup ./dockpin pin 2 > /tmp/dockpin.log 2>&1 &
```

To stop it later:

```bash
pkill dockpin
```

### Troubleshooting

| Problem | Solution |
|---|---|
| `Could not determine Dock's current display` | Grant Screen Recording permission to your terminal app, then restart the terminal. |
| Dock doesn't move back | Make sure "Displays have separate Spaces" is **OFF** in System Settings > Desktop & Dock. DockPin is designed for this mode. |
| Display numbers changed | Reconnect your monitors and run `dockpin list` again. Display numbers may change when monitors are plugged/unplugged. |

---

## 中文教程

### DockPin 是什么？

DockPin 是一个轻量级命令行工具，用于将 macOS 的 Dock 栏固定在指定的显示器上。在多显示器环境下，macOS 会在你把鼠标移到另一块屏幕底部时自动将 Dock 移过去。DockPin 会持续监控并自动将 Dock 移回你指定的屏幕。

### 前置要求

1. **macOS 13 (Ventura) 或更高版本**
2. **Swift 编译器** — 随 Xcode 命令行工具安装。运行以下命令安装：
   ```bash
   xcode-select --install
   ```
3. **屏幕录制权限** — DockPin 需要读取窗口信息。前往：
   **系统设置 > 隐私与安全性 > 屏幕录制**，开启你使用的终端应用（如 Terminal、iTerm2、Warp）的权限。

### 编译

```bash
cd ~/Projects/DockPin
swiftc -o dockpin Sources/main.swift -framework AppKit -framework CoreGraphics
```

### 使用方法

#### 1. 查看所有显示器

```bash
./dockpin list
```

输出示例：

```
Available displays:
  1: 1512x982 (main) [ID: 1]
  2: 2560x1440 [ID: 3]
```

每个显示器会分配一个编号。`(main)` 表示主显示器。

#### 2. 查看 Dock 当前在哪个屏幕

```bash
./dockpin status
```

输出示例：

```
Dock is on display 1: 1512x982 (main) [ID: 1]
```

#### 3. 将 Dock 固定到指定显示器

```bash
./dockpin pin 2
```

这会将 Dock 固定到显示器 2。程序会在前台持续运行并监控 Dock 的位置。一旦 Dock 被移走，会自动移回目标屏幕。

输出示例：

```
Pinning Dock to display 2: 2560x1440
Press Ctrl+C to stop.

[14:32:07] Dock drifted — moving back to display 2
```

#### 4. 停止固定

在终端中按 **Ctrl+C** 即可停止 DockPin。Dock 将恢复正常行为。

### 可选：安装到系统路径

将 `dockpin` 安装到系统路径，方便在任意位置使用：

```bash
sudo cp ./dockpin /usr/local/bin/
```

之后可以直接运行：

```bash
dockpin list
dockpin pin 2
```

### 可选：后台运行

```bash
nohup ./dockpin pin 2 > /tmp/dockpin.log 2>&1 &
```

停止后台进程：

```bash
pkill dockpin
```

### 常见问题

| 问题 | 解决方法 |
|---|---|
| 提示 `Could not determine Dock's current display` | 在系统设置中为你的终端应用开启「屏幕录制」权限，然后重启终端。 |
| Dock 没有被移回来 | 确认「系统设置 > 桌面与程序坞」中的「显示器具有单独的空间」选项已**关闭**。DockPin 适用于此模式。 |
| 显示器编号变了 | 重新连接显示器后运行 `dockpin list` 查看最新编号。插拔显示器可能导致编号变化。 |
