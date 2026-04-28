# 第一阶段：构建应用
FROM node:18-slim AS builder

# 安装 electron-builder 所需系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基础构建工具
    build-essential \
    # electron-builder 依赖的库
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    # 打包 deb/AppImage 可能需要
    fakeroot dpkg \
    # 如果使用 AppImage 需要
    file \
    && rm -rf /var/lib/apt/lists/*

# 禁用签名（容器内无需签名）
ENV CSC_IDENTITY_AUTO_DISCOVERY=false

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# 仅生成解压后的目录，避免创建 .deb/.AppImage 的额外耗时
RUN npx electron-builder --linux dir

# 第二阶段：运行环境（保持不变）
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/release/linux-unpacked /opt/chat2api

EXPOSE 8080
CMD ["xvfb-run", "--auto-servernum", "/opt/chat2api/chat2api", "--no-sandbox"]
