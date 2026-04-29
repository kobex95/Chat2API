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

# 构建（产出 out/ 目录）
RUN npm run build

# -------------------------------------------------
# 第二阶段：运行时环境
FROM node:20-slim

# 安装 Electron 运行依赖 + 虚拟显示器 + xauth
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 libasound2 \
    xvfb xauth \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 从构建阶段复制 node_modules（含 electron）和构建输出
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/out ./out
COPY --from=builder /app/package.json ./

EXPOSE 8080

# 自动查找主进程入口，并通过 xvfb 运行 Electron
CMD ["sh", "-c", "MAIN=$(find out/main -type f \\( -name index.js -o -name index.mjs \\) | head -1) && xvfb-run --auto-servernum npx electron $MAIN --no-sandbox"]
