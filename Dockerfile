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

# 构建应用
RUN npm run build

# 调试：列出 out 目录的所有文件，帮助我们找到主入口
RUN echo "=== Listing out directory ===" && \
    find out -type f && \
    echo "=== package.json main ===" && \
    node -e "console.log(require('./package.json').main)" && \
    echo "=== Try to locate potential entries ===" && \
    find out -name "index.*" -type f

# 暂时写入占位入口文件（运行时会重新查找）
RUN echo "placeholder" > /app/entry_path.txt

# -------------------------------------------------
# 第二阶段：运行时环境
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

# 动态查找入口文件并运行（在 out 目录下搜索 index.js 或 index.mjs）
CMD ["sh", "-c", "\
  service dbus start 2>/dev/null || true; \
  ENTRY=$(find out -type f \\( -name \"index.js\" -o -name \"index.mjs\" \\) | grep -v node_modules | head -1); \
  if [ -z \"$ENTRY\" ]; then \
    echo 'No entry found. Listing out directory:'; \
    find out -type f; \
    exit 1; \
  fi; \
  echo 'Using entry:' $ENTRY; \
  xvfb-run --auto-servernum npx electron $ENTRY --no-sandbox --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage"]
