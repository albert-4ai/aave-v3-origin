#!/bin/bash
# WSL 中安装 Node.js 的脚本

echo "🚀 开始在 WSL 中安装 Node.js..."

# 1. 加载 nvm
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
    echo "✅ nvm 已加载"
else
    echo "❌ nvm.sh 文件不存在"
    exit 1
fi

if [ -s "$NVM_DIR/bash_completion" ]; then
    \. "$NVM_DIR/bash_completion"
fi

# 2. 检查 nvm 是否可用
if ! command -v nvm &> /dev/null && ! type nvm &> /dev/null; then
    echo "❌ nvm 命令不可用，尝试重新安装..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || {
        echo "❌ nvm 安装失败"
        exit 1
    }
    
    # 重新加载 nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# 检查 nvm 是否可用
if command -v nvm &> /dev/null || type nvm &> /dev/null; then
    echo "✅ nvm 版本: $(nvm --version 2>&1)"
else
    echo "❌ nvm 仍然不可用"
    exit 1
fi

# 3. 安装 Node.js 20 LTS
echo "📦 正在安装 Node.js 20 LTS..."
nvm install 20

# 4. 设置为默认版本
echo "🔧 设置 Node.js 20 为默认版本..."
nvm use 20
nvm alias default 20

# 5. 验证安装
echo "✅ 验证安装..."
node --version
npm --version

echo ""
echo "🎉 Node.js 安装完成！"
echo ""
echo "当前版本:"
echo "  Node.js: $(node --version)"
echo "  npm: $(npm --version)"
echo ""
echo "💡 提示: 如果在新终端中 node 命令不可用，请运行:"
echo "  source ~/.bashrc"
echo "  或"
echo "  export NVM_DIR=\"\$HOME/.nvm\""
echo "  [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\""

