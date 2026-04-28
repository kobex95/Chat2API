# 第一阶段：构建应用
FROM node:20 AS builder

# 安装 electron-builder 及构建所需的系统库
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    fakeroot dpkg file \
    python3 \
    libsecret-1-dev libdrm-dev libx11-dev libxcomposite-dev \
    libxdamage-dev libxext-dev libxfixes-dev libxrandr-dev \
    libxcb1-dev libxcb-shm0-dev libxcb-dri2-0-dev libxtst-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
ENV CSC_IDENTITY_AUTO_DISCOVERY=false

WORKDIR /app
COPY package*.json ./
RUN npm ci

# 复制源码
COPY . .

# 修复 package.json：添加 type: module，同时指定正确的入口文件
RUN node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.type='module';p.main='dist/main/index.js';fs.writeFileSync('package.json',JSON.stringify(p,null,2))"

# 构建
RUN set -x && npm run build 2>&1

# 打包（此时入口文件匹配）
RUN set -x && npx electron-builder --linux dir 2>&1

# 第二阶段：运行
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/release/linux-unpacked /opt/chat2api

EXPOSE 8080
CMD ["xvfb-run", "--auto-servernum", "/opt/chat2api/chat2api", "--no-sandbox"]
