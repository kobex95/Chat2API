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

# 添加 type: module
RUN node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.type='module';fs.writeFileSync('package.json',JSON.stringify(p,null,2))"

# 构建 Electron 应用
RUN set -x && npm run build 2>&1

# 自动查找主进程入口文件（可能是 index.js 或 index.mjs），并写入 package.json
RUN set -x && \
    MAIN_FILE=$(find out/main -type f \( -name "index.js" -o -name "index.mjs" \) | head -1) && \
    echo "Found main entry: $MAIN_FILE" && \
    node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.main='$MAIN_FILE';fs.writeFileSync('package.json',JSON.stringify(p,null,2))"

# 确认修改后的 main 字段（可选调试）
RUN node -e "console.log('Updated main:', require('./package.json').main)"

# 打包成解压目录，禁用 asar
RUN set -x && npx electron-builder --linux dir --config.asar=false 2>&1

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
