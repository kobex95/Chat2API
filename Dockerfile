# 第一阶段：构建应用
FROM node:20 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make gcc ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
ENV CSC_IDENTITY_AUTO_DISCOVERY=false

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .

# 修复 PostCSS 模块语法
RUN node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.type='module';fs.writeFileSync('package.json',JSON.stringify(p,null,2))"

# 构建应用，并找出主进程入口文件，保存到临时文件
RUN npm run build && \
    MAIN_FILE=$(find out/main -type f \( -name "index.js" -o -name "index.mjs" \) | head -1) && \
    if [ -z "$MAIN_FILE" ]; then echo "ERROR: No entry file found!"; find out/main -type f; exit 1; fi && \
    echo "Found entry: $MAIN_FILE" && \
    echo "$MAIN_FILE" > /app/entry_path.txt

# -------------------------------------------------
# 第二阶段：运行时环境
FROM node:20-slim

# 安装 Electron 运行依赖 + 虚拟显示器 + xauth + dbus
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb xauth dbus \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制 node_modules、构建输出、入口文件路径
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/out ./out
COPY --from=builder /app/package.json ./
COPY --from=builder /app/entry_path.txt ./

EXPOSE 8080

# 启动脚本：先启动 dbus，再通过 xvfb 运行 Electron
CMD ["sh", "-c", "\
  service dbus start 2>/dev/null || true; \
  ENTRY=$(cat /app/entry_path.txt); \
  echo 'Using entry:' $ENTRY; \
  xvfb-run --auto-servernum npx electron $ENTRY --no-sandbox --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage"]
