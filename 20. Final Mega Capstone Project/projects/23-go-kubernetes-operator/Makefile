.PHONY: test build manifests install run
test:
	go test ./... -race -cover
build:
	go build ./cmd
manifests:
	kubectl kustomize config >/tmp/environment-operator.yaml
install:
	kubectl apply -k config
run:
	go run ./cmd
