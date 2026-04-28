# 第一阶段：构建应用
FROM node:18 AS builder

# 安装系统依赖（包括开发库）
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Electron 应用运行时库
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    # 打包工具
    fakeroot dpkg file \
    # node-gyp 等工具链需要
    python3 make gcc \
    # 可能被原生模块依赖的开发包（常见）
    libsecret-1-dev libdrm-dev libx11-dev libxcomposite-dev \
    libxdamage-dev libxext-dev libxfixes-dev libxrandr-dev \
    libxcb1-dev libxcb-shm0-dev libxcb-dri2-0-dev libxtst-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 加速 Electron 下载（国内可用镜像）
ENV ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
# 可选：设置 npm 镜像
# ENV npm_config_registry="https://registry.npmmirror.com"

# 禁用代码签名
ENV CSC_IDENTITY_AUTO_DISCOVERY=false

WORKDIR /app
COPY package*.json ./
RUN npm ci

# 检查关键依赖是否存在（便于调试，出现错误时能看到模块列表）
RUN npx electron-vite --version || true
RUN ls node_modules/.bin/electron-vite || echo "electron-vite binary not found"

# 复制代码
COPY . .

# 如果有 postinstall 脚本，我们已经运行过（npm ci 会执行），但如果需要可单独再执行
# RUN npm run postinstall --if-present

# 构建前端和主进程
RUN set -x && npm run build 2>&1

# 打包成解压目录
RUN set -x && npx electron-builder --linux dir 2>&1

# -------------------------------------------------
# 第二阶段：运行环境（不变）
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/release/linux-unpacked /opt/chat2api
EXPOSE 8080
CMD ["xvfb-run", "--auto-servernum", "/opt/chat2api/chat2api", "--no-sandbox"]
