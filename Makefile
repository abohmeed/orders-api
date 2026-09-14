.PHONY: build test run docker-build

build:
	go build -o bin/orders-api .

test:
	go test -v ./...

run: build
	./bin/orders-api

docker-build:
	docker build -t orders-api:dev .
