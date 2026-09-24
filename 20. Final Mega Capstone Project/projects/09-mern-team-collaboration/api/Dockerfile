FROM node:24-alpine
ENV NODE_ENV=production PORT=4000
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY --chown=app:app src ./src
USER 10001:10001
EXPOSE 4000
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD node -e "fetch('http://localhost:4000/health').then(r=>{if(!r.ok)process.exit(1)})"
CMD ["node","src/server.js"]
