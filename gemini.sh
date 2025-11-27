#!/bin/bash

echo "⚡ 正在启动 Gemini CLI..."
echo "-------------------------------------"

echo "📦 [1/3] 正在检查 Node.js..."
if ! command -v node &> /dev/null; then
    pkg install nodejs -y > /dev/null 2>&1
    echo "   ✅ Node.js 安装完毕"
else
    echo "   ✅ Node.js 已存在"
fi

echo "🛠️ [2/3] 正在检查 pnpm..."
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm > /dev/null 2>&1
    echo "   ✅ pnpm 激活完毕"
else
    echo "   ✅ pnpm 已存在"
fi

echo "🤖 [3/3] 正在检查 Gemini CLI..."
pnpm add -g @google/gemini-cli > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "   ✅ Gemini 安装/更新成功"; else echo "   ❌ Gemini 安装失败"; exit 1; fi

echo "-------------------------------------"

echo "🌐【关键配置】请输入您的网络代理地址"
echo "   (Gemini 需要代理才能连接 Google 服务器)"
echo ""
echo "   参考示例:"
echo "   - Clash 默认 HTTP:   http://127.0.0.1:7890"
echo "   - v2ray 默认 SOCKS:  http://127.0.0.1:10808"
echo "   - 远程服务器:        http://192.xxx.x.x:xxxx"
echo ""

read -p "👉 请输入代理地址 (留空则不配置): " USER_PROXY

CONFIG_FILE="$HOME/.bashrc"

if grep -q "alias gemini=" "$CONFIG_FILE"; then
    sed -i '/alias gemini=/d' "$CONFIG_FILE"
    echo "   🧹 已清理旧的代理配置"
fi

if [ -n "$USER_PROXY" ]; then
    NEW_ALIAS="alias gemini='HTTPS_PROXY=$USER_PROXY gemini'"
    
    echo "$NEW_ALIAS" >> "$CONFIG_FILE"
    echo "   ✅ 已写入新代理: $USER_PROXY"
else
    echo "   ⚠️ 您跳过了代理配置 (Gemini 可能无法直连)"
fi

echo "-------------------------------------"
echo "🎉 恢复完成！"
echo "👉 请务必执行: source ~/.bashrc"
echo "👉 然后输入: gemini"
