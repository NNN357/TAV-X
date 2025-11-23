# TAV-X
TAV X：安卓终端的赛博酒馆指挥官 —— 一键部署、远程漫游、永不掉线。安卓手机也是云酒馆。

# TAV X - SillyTavern Android Manager

> **By Future404**
>
> *安卓终端的赛博酒馆指挥官 —— 一键部署、远程漫游、永不掉线。*

---

## 📖 简介 | Introduction

**TAV X** 是专为 Android Termux 环境打造的 **SillyTavern (酒馆)** 全能管理工具。
它解决了新手在手机上部署 AI 前端的一系列痛点：复杂的依赖安装、不稳定的后台进程、繁琐的远程穿透配置。

使用 TAV X，你只需要输入一行代码，剩下的交给我们。

## ✨ 核心特性 | Features

*   **🚀 一键全自动部署**：自动检测环境，安装 Node.js, Git, Cloudflared 等所有依赖。
*   **🌌 赛博朋克仪表盘**：集成式 TUI 界面，实时监控服务状态。
*   **🛡️ 进程隔离技术**：采用 `setsid` 守护进程，彻底解决 Termux 下后台服务被误杀的问题。
*   **🌍 零配置远程分享**：内置 Cloudflared 隧道，无需公网 IP，自动生成远程访问链接。
*   **💾 无损智能更新**：独创 Git Stash 保护机制，更新软件时自动保留您的配置文件和聊天记录。
*   **⚡ 自动快捷指令**：安装后自动注入 `st` 命令，下次启动只需输入 `st`。

## 📥 快速开始 | Quick Start

打开 Termux，复制并执行以下命令即可：

```bash
bash <(curl -s -L https://gh-proxy.com/https://raw.githubusercontent.com/[您的GitHub用户名]/TAV-X/main/st.sh)
