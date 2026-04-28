# 第一阶段：构建应用
FROM node:18-slim AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build:linux

# 第二阶段：运行环境
FROM debian:bookworm-slim

# 安装 Electron 运行所需的系统库
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 \
    libasound2 \
    # 用于无头运行（没有显示器）
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# 复制构建好的应用（electron-builder 的 dir 模式输出）
COPY --from=builder /app/release/linux-unpacked /opt/chat2api

# 暴露代理默认端口
EXPOSE 8080

# 启动脚本：在虚拟 X 服务器中运行 Electron 应用
CMD ["xvfb-run", "--auto-servernum", "/opt/chat2api/chat2api", "--no-sandbox"]
