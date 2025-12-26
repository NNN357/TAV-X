# TAV-X 🌐

**One-click deployment script to turn your Android phone into a personal AI server**

[![GitHub Stars](https://img.shields.io/github/stars/NNN357/TAV-X?style=social)](https://github.com/NNN357/TAV-X/stargazers)
[![GitHub License](https://img.shields.io/github/license/NNN357/TAV-X)](https://github.com/NNN357/TAV-X/blob/main/LICENSE)

---

## 📖 Introduction

TAV-X is a smart installer and management script for deploying [SillyTavern](https://github.com/SillyTavern/SillyTavern) on Android devices via [Termux](https://termux.dev/). It automates environment setup, dependency management, network tunneling, and background process optimization.

### ✨ Key Features

- **One-Click Installation**: Automated SillyTavern deployment with smart mirror selection
- **Cloudflare Tunnel**: Built-in remote access via Cloudflare's free tunneling service
- **ADB Keep-Alive**: Advanced background process protection to prevent Android from killing services
- **Plugin Ecosystem**: Easy installation of community extensions and plugins
- **Multi-Proxy Support**: AI proxy modules including ClewdR, Gemini CLI, AIStudio, and AutoGLM
- **Backup & Restore**: Simple data backup and restoration to external storage
- **Version Management**: Update, rollback, and switch between release/staging channels
- **Beautiful UI**: Rich terminal interface powered by [Gum](https://github.com/charmbracelet/gum)

---

## 🚀 Quick Start

### Prerequisites

1. **Android Device** with Termux installed
   - [Download Termux from F-Droid](https://f-droid.org/packages/com.termux/) (recommended)
   - Do NOT use the Play Store version (outdated)

2. **Storage Permission** (for backups)
   ```bash
   termux-setup-storage
   ```

### Installation

Run this single command in Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/NNN357/TAV-X/main/st.sh | bash
```

Or if you prefer wget:

```bash
wget -qO- https://raw.githubusercontent.com/NNN357/TAV-X/main/st.sh | bash
```

### Usage

After installation, type `st` in Termux to launch the menu:

```bash
st
```

---

## 📱 Main Menu

| Option | Description |
|--------|-------------|
| 🚀 Start Services | Launch SillyTavern locally or with remote tunnel |
| 🔄 Install & Update | Install SillyTavern, update, or rollback versions |
| ⚙️ System Settings | Configure server parameters, memory, ports, etc. |
| 🧩 Plugin Manager | Install community plugins and extensions |
| 🌐 Network Settings | Configure download proxies and mirrors |
| 💾 Backup & Restore | Backup/restore data to external storage |
| 🛠️ Advanced Tools | ADB keep-alive, ClewdR, Gemini proxy, etc. |
| 💡 Help & Support | About page and contact information |

---

## 🛡️ ADB Keep-Alive

Android aggressively kills background processes. TAV-X includes an ADB-based keep-alive system:

1. **Wireless ADB Pairing**: Connect ADB wirelessly without a PC
2. **Universal Keep-Alive**: Safe optimizations for all Android versions
3. **Aggressive Keep-Alive**: Vendor-specific optimizations (Huawei, Xiaomi, OPPO, Vivo)
4. **Audio Heartbeat**: Optional audio-based process elevation

---

## 🔌 AI Proxy Modules

TAV-X includes several AI proxy modules in the Advanced Tools menu:

| Module | Description |
|--------|-------------|
| 🦀 ClewdR | Claude API reverse proxy |
| ♊ Gemini CLI | Google Gemini API proxy with OAuth |
| 🏗️ AIStudio | Baidu AIStudio proxy plugin |
| 🤖 AutoGLM | GLM phone agent automation |

---

## 📂 Directory Structure

```
~/.tav_x/
├── st.sh              # Main entry point
├── core/              # Core scripts
│   ├── main.sh        # Main menu logic
│   ├── ui.sh          # UI components
│   ├── launcher.sh    # Service launcher
│   ├── backup.sh      # Backup functions
│   ├── updater.sh     # Update manager
│   ├── security.sh    # System settings
│   ├── plugins.sh     # Plugin manager
│   └── ...
├── modules/           # Optional tool modules
│   ├── adb_keepalive.sh
│   ├── clewd.sh
│   ├── Gemini_CLI.sh
│   └── ...
├── config/            # Configuration files
└── scripts/           # Helper scripts
```

---

## 💡 Tips & Troubleshooting

### Network Issues

- **Behind Firewall**: Use the mirror selection feature for Chinese users
- **Cloudflare Timeout**: Try toggling VPN on/off and retry
- **GitHub Access**: Configure a proxy in Network Settings

### Performance

- **Memory Tuning**: Adjust in System Settings → Memory Configuration
- **Background Killing**: Enable ADB Keep-Alive in Advanced Tools
- **Slow Startup**: Enable "Lazy Load Characters" in Core Settings

### Common Errors

| Error | Solution |
|-------|----------|
| "Port already in use" | Stop existing services first |
| "Permission denied" | Run `termux-setup-storage` |
| "Dependencies failed" | Try `pkg upgrade` then reinstall |

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [SillyTavern](https://github.com/SillyTavern/SillyTavern) - The core AI frontend
- [Cloudflare](https://www.cloudflare.com/) - Free tunneling service
- [Termux](https://termux.dev/) - Android terminal emulator
- [Gum](https://github.com/charmbracelet/gum) - Terminal UI toolkit

---

## 📞 Contact

- **Author**: berry
- **GitHub**: [NNN357/TAV-X](https://github.com/NNN357/TAV-X)

---

*"Don't let virtual warmth steal the real warmth you deserve in life."*
