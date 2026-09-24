FROM node:24-bookworm-slim
WORKDIR /app
COPY server.mjs .
ENV NODE_ENV=production APP_VERSION=dev
USER 10001:10001
EXPOSE 8080
CMD ["node", "server.mjs"]
