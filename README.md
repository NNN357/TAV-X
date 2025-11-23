# TAV-X：Termux 自动化安装脚本

## 📱 让闲置安卓机变身“私人云端酒馆”：TAV-X 一键部署方案

**你还在为想随时随地玩 SillyTavern（酒馆）而发愁吗？**
手里有闲置的旧安卓手机在“吃灰”？想用主力 iPhone 畅聊却苦于系统限制？

**TAV-X (Termux Automated Venture-X)** 来了！这就是你一直在寻找的终极解决方案。

无需复杂的 Linux 知识，无需繁琐的网络配置，只需要一条命令，瞬间将你的安卓手机变成一台 24 小时在线的 AI 专属服务器！

### 🌟 为什么选择 TAV-X？

#### ♻️ 变废为宝，旧机新生
不要让旧手机躺在抽屉里贬值！只要能运行 Termux，它就是你最棒的随身服务器。
部署在旧安卓，享受在新手机。甚至可以用平板、电脑、电视浏览器访问，榨干旧设备的每一滴性能！

#### 🍎 安卓部署，苹果畅玩
iOS 用户狂喜！你不需要在 iPhone 上折腾复杂的环境。
将 TAV-X 部署在安卓备用机上，通过生成的专属链接，你的 iPhone/iPad 甚至 PC/Mac 都能通过浏览器无缝接入，体验丝滑的原生酒馆。

#### 🚀 全程“无痛”，告别魔法
受够了为了连接还要开关梯子？
TAV-X 内置 Cloudflare 隧道技术，无需魔法，无需公网 IP。无论你在家里、公司、还是在移动数据网络下，都能随时随地打开链接直达你的酒馆。

#### 🔒 数据私有，安全无忧
所有聊天记录、角色卡片、世界书依然存储在你本地的安卓设备上，数据掌握在自己手中。不用担心云端服务商偷看你的隐私。

#### 👥 成为“馆主”，多人协作
脚本默认开启多用户模式！
你可以作为管理员（Admin）掌控全局，同时创建一个普通账户分享给朋友、或者作为自己的“纯净小号”使用。通过一个链接，实现多人同时在线畅聊。

---

## 🚀 项目简介

**TAV-X** 是一个为安卓 Termux 环境量身定制的傻瓜式一键安装脚本，旨在简化 SillyTavern 的部署和管理流程。它集成了环境配置、依赖安装、隧道穿透和后台保活功能。

## ✨ 项目核心亮点

| 特性 | 描述 |
| :--- | :--- |
| **一键式部署** | 一条命令完成环境依赖安装、项目克隆和配置初始化。 |
| **智能快捷指令** | 自动配置 `st` 命令，配置完成后，下次只需输入 `st` 即可直接唤起菜单。 |
| **TUI 交互式管理** | 提供直观的文本用户界面（TUI）菜单，集成服务状态和实时远程链接显示。 |
| **后台稳定运行** | 使用 `setsid nohup` 启动，并启用 `termux-wake-lock` 锁，确保服务在 Termux 后台和屏幕熄灭时保持稳定不断线。 |
| **跨设备分享** | 利用 Cloudflare 隧道技术（无需额外配置），生成安全链接，实现从任何设备远程访问。 |
| **无损更新** | 自动暂存本地修改，确保核心项目更新后本地文件和数据不受影响。 |

## ⚡ 快速开始

### 准备工作
请确保您已安装并打开了安卓 Termux 终端应用。

### 📥 安装与启动命令

请根据您的网络环境，选择下面**其中一条**命令复制到 Termux 中执行。

#### 🌏 通用/国际线路 (Global)
如果您在非中国大陆地区，或网络环境允许访问 GitHub：
```bash
curl -s -L https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

#### 🚀 国内加速线路 (China Mainland)
如果遇到网络连接问题，请任选以下一条加速命令执行：

**线路 1 (EdgeOne):**
```bash
curl -s -L https://edgeone.gh-proxy.com/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

**线路 2 (HK):**
```bash
curl -s -L https://hk.gh-proxy.com/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

**线路 3 (Generic):**
```bash
curl -s -L https://gh-proxy.com/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

**线路 4 (Likk - 推荐):**
```bash
curl -s -L https://gh.likk.cc/https://raw.githubusercontent.com/Future-404/TAV-X/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

### ⚠️ 重要提示：首次运行操作规范

为了确保快捷指令 `st` 正确生效，请严格按照以下步骤操作：

1.  执行上述安装命令后，脚本会自动进入安装流程并最终显示菜单界面。
2.  **请不要进行任何操作！** 在首次进入菜单界面时，直接输入数字 **`0`** 并回车退出脚本。
3.  退出后，在终端输入 **`st`** 并回车。
4.  此时脚本再次启动，环境配置已完全生效，您可以正常使用所有功能了。

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