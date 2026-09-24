FROM node:24-alpine AS frontend
WORKDIR /src
COPY frontend/package*.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

FROM node:24-alpine AS dependencies
ENV NODE_ENV=production
WORKDIR /app
COPY app/package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM node:24-alpine
ENV NODE_ENV=production PORT=3000 WEB_ROOT=/app/public
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY --from=dependencies --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app app/package.json ./
COPY --chown=app:app app/src ./src
COPY --from=frontend --chown=app:app /src/dist ./public
USER 10001:10001
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD node -e "fetch('http://localhost:3000/health').then(r=>{if(!r.ok)process.exit(1)})"
CMD ["node","src/server.js"]
