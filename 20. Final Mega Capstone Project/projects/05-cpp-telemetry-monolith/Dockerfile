FROM node:24-alpine AS frontend
WORKDIR /src
COPY frontend/package*.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

FROM ubuntu:24.04 AS build
RUN apt-get update && apt-get install -y --no-install-recommends cmake g++ libsqlite3-dev ninja-build && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY app/ ./
RUN cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build --parallel

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 app && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build /src/build/telemetry /app/telemetry
COPY --from=frontend /src/dist /app/public
RUN mkdir -p /app/data && chown -R app:app /app
USER 10001:10001
ENV PORT=8080 WEB_ROOT=/app/public DATABASE_PATH=/app/data/telemetry.db
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["/app/telemetry"]
