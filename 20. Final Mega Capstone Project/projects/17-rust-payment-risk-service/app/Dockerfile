FROM rust:1.97-slim AS build
WORKDIR /src
COPY Cargo.toml ./
COPY src ./src
COPY tests ./tests
RUN cargo test && cargo build --release
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/* && groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
ENV RUST_LOG=info LISTEN_ADDRESS=0.0.0.0:8080
COPY --from=build --chown=10001:10001 /src/target/release/payment-risk /usr/local/bin/payment-risk
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["payment-risk"]
