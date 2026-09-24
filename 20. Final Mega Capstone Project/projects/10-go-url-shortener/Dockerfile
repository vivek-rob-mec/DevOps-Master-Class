FROM golang:1.25-alpine AS build
WORKDIR /src
COPY app/go.mod ./
RUN go mod download
COPY app/ ./
RUN CGO_ENABLED=0 go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/shortener .

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/shortener /app/shortener
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app/shortener"]
