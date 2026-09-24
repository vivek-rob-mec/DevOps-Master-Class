FROM node:24-alpine
ENV NODE_ENV=production
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY package*.json .
RUN npm ci --omit=dev --no-audit --no-fund
COPY src ./src
RUN chown -R app:app /app
USER 10001:10001
EXPOSE 3000
CMD ["node","src/index.js"]
