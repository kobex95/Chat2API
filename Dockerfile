# 第一阶段：构建应用
FROM node:18-slim AS builder

# 安装 electron-builder 及 node-gyp 所需的一切依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基础构建工具
    build-essential \
    # electron-builder 打包工具链
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    fakeroot dpkg file \
    # node-gyp 编译需要的 Python 等
    python3 make gcc \
    # 下载 Electron 二进制文件可能需要
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 禁用代码签名
ENV CSC_IDENTITY_AUTO_DISCOVERY=false

WORKDIR /app
COPY package*.json ./
RUN npm ci

# 复制全部源码
COPY . .

# 第一步：构建前端与主进程代码 (electron-vite build)
RUN npm run build

# 第二步：打包成解压目录（linux-unpacked）
RUN npx electron-builder --linux dir --verbose

# -------------------------------------------------
# 第二阶段：运行环境
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/release/linux-unpacked /opt/chat2api

EXPOSE 8080
CMD ["xvfb-run", "--auto-servernum", "/opt/chat2api/chat2api", "--no-sandbox"]
