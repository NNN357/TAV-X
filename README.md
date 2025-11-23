# TAV-X：Termux 自动化安装脚本

## 🚀 项目简介

**TAV-X (Termux Automated Venture-X)** 是一个为安卓 Termux 环境量身定制的傻瓜式一键安装脚本，旨在简化 SillyTavern 的部署和管理流程。无论您是想在本地使用，还是通过安全隧道跨设备远程访问您的“酒馆”，TAV-X 都能助您一臂之力，让您在安卓手机上随时随地进入您的专属 AI 聊天环境。

## ✨ 项目核心亮点

| 特性 | 描述 |
| :--- | :--- |
| **一键式部署** | 一条命令完成环境依赖安装、项目克隆和配置初始化。 |
| **智能快捷指令** | **脚本首次运行会自动配置 `st` 命令**。配置完成后，下次只需在终端输入 `st` 即可直接唤起菜单。 |
| **TUI 交互式管理** | 提供直观的文本用户界面（TUI）菜单，集成服务状态和实时远程链接显示。 |
| **后台稳定运行** | 使用 `setsid nohup` 启动，并启用 `termux-wake-lock` 锁，确保服务在 Termux 后台和屏幕熄灭时保持稳定不断线。 |
| **跨设备分享** | 利用 Cloudflare 隧道技术（无需额外配置），生成安全链接，实现从任何设备远程访问。 |
| **多用户模式** | 自动开启多用户功能，可添加多个用户，通过分享链接实现协作。 |
| **安卓部署优势** | 专为 Termux 优化，实现在安卓手机部署，跨设备随时进入酒馆的便捷体验。 |
| **无损更新** | 自动暂存本地修改，确保核心项目更新后本地文件和数据不受影响。 |

## ⚡ 快速开始

### 准备工作
请确保您已安装并打开了安卓 Termux 终端应用。

### 安装与启动
请根据您的网络环境，选择下面**其中一条**命令复制到 Termux 中执行。
*(该命令会自动下载脚本、赋予执行权限并启动安装程序)*

#### 🌏 通用/国际线路 (Global)
如果您在非中国大陆地区，或网络环境允许访问 GitHub：
```bash
curl -L https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh
```

#### 🚀 国内加速线路 (China Mainland)
如果遇到网络连接问题，请任选以下一条加速命令执行：

**线路 1 (EdgeOne):**
```bash
curl -L https://edgeone.gh-proxy.com/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh
```

**线路 2 (HK):**
```bash
curl -L https://hk.gh-proxy.com/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh
```

**线路 3 (Generic):**
```bash
curl -L https://gh-proxy.com/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh
```

**线路 4 (Likk - 推荐):**
```bash
curl -L https://gh.likk.cc/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh
```

> **💡 提示**：脚本首次成功运行后，会自动在您的系统中创建快捷指令。以后您只需输入 **`st`** 并回车，即可随时打开管理菜单，无需重复输入下载命令。

## 🛡️ 安全与多用户设置

为了保障您的数据安全和实现跨设备协作，请务必注意以下关键信息：

*   **多用户模式已开启**：本脚本已自动在配置文件中开启了多用户（User Accounts）和谨慎登录（Discreet Login）功能。
*   **首次登录安全提醒**：
    *   **默认管理员用户名**：`default-user`
    *   **首次登录无密码**：由于安全考虑，首次运行后 `default-user` 没有默认密码。
    *   **立即设置密码**：您必须在登录后，前往管理员设置页面自行设置一个强密码。请务必妥善保管您的密码。
*   **分享与协作**：脚本启动远程分享后会生成一个 Cloudflare 隧道链接，您可以将此链接和您创建的用户账号分享给他人，实现多用户同时访问。

---

感谢您对 TAV-X 的支持！在使用过程中如遇到任何问题，欢迎到项目 GitHub 仓库 提交 Issue。