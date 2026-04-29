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

RUN npm run build

# -------------------------------------------------
# 第二阶段：运行环境
FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb xauth dbus \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/out ./out
COPY --from=builder /app/package.json ./

EXPOSE 8080

# 启动：只搜索 out/main 下的主进程文件
CMD ["sh", "-c", "\
  service dbus start 2>/dev/null || true; \
  MAIN_ENTRY=$(find out/main -type f \\( -name index.js -o -name index.mjs \\) | head -1); \
  if [ -z \"$MAIN_ENTRY\" ]; then \
    echo 'ERROR: Main process entry not found in out/main/'; \
    echo 'Files in out/main:'; \
    ls -la out/main/ || true; \
    exit 1; \
  fi; \
  echo 'Using main entry:' $MAIN_ENTRY; \
  exec xvfb-run --auto-servernum npx electron $MAIN_ENTRY \
    --no-sandbox \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-dev-shm-usage"]
