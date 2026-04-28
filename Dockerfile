# 第一阶段：构建应用（使用完整 Node 镜像）
FROM node:18 AS builder

# 安装 electron-builder 及构建所需的系统库
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Electron 应用依赖的图形库
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    # 打包工具
    fakeroot dpkg file \
    # node-gyp 需要 python3
    python3 \
    && rm -rf /var/lib/apt/lists/*

# 关闭自动代码签名
ENV CSC_IDENTITY_AUTO_DISCOVERY=false

WORKDIR /app
COPY package*.json ./
RUN npm ci

# 复制所有源代码
COPY . .

# 第一步：构建 Electron 应用（添加 -x 可输出详细命令）
RUN set -x && npm run build

# 第二步：仅打包成解压目录（不生成 .deb/.AppImage）
RUN set -x && npx electron-builder --linux dir

# -------------------------------------------------
# 第二阶段：最小化运行环境
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/release/linux-unpacked /opt/chat2api

EXPOSE 8080
CMD ["xvfb-run", "--auto-servernum", "/opt/chat2api/chat2api", "--no-sandbox"]
