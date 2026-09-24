FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /server .
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /server /server
ENV APP_VERSION=dev
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/server"]
