FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm ci --no-audit --no-fund
COPY src ./src
RUN npm run build
FROM node:24-alpine
ENV NODE_ENV=production PORT=3000
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY --from=build --chown=app:app /app/dist ./dist
USER 10001:10001
EXPOSE 3000
CMD ["node","dist/main.js"]
