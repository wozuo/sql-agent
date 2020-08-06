IMAGE_NAME := dbhi/sql-agent
PROG_NAME := sql-agent
CMD_PATH := "."

GIT_SHA := $(or $(shell git log -1 --pretty=format:"%h"), "latest")
GIT_TAG := $(shell git describe --tags --exact-match 2>/dev/null)
GIT_BRANCH := $(shell git symbolic-ref -q --short HEAD)
GIT_VERSION := $(shell git log -1 --pretty=format:"%h (%ci)" .)

build:
	go build \
		-o $(GOPATH)/bin/sql-agent \
		./cmd/sql-agent

dist-build:
	mkdir -p dist

	cd cmd/sql-agent && gox -output="../../dist/{{.OS}}-{{.Arch}}/"$(PROG_NAME)"" \
		-ldflags "-X \"main.buildVersion=$(GIT_VERSION)\"" \
		-os "windows linux darwin" \
		-arch "amd64" $(CMD_PATH)

dist-pkg:
	cd dist && tar -czvf $(PROG_NAME)-darwin-amd64.tar.gz darwin-amd64/*
	cd dist && tar -czvf $(PROG_NAME)-linux-amd64.tar.gz linux-amd64/*
	cd dist && zip $(PROG_NAME)-windows-amd64.zip windows-amd64/*

clean:
	go clean ./...

doc:
	godoc -http=:6060

install:
	go get github.com/jmoiron/sqlx

dist:
	rm -f .dockerignore
	ln -s .dockerignore.build .dockerignore
	docker build -f Dockerfile.build -t dbhi/sql-agent-builder .
	docker run --rm -it \
		-v ${PWD}/dist/linux-amd64:/go/src/app/dist/linux-amd64 \
		dbhi/sql-agent-builder

test-install: install
	go get golang.org/x/tools/cmd/cover
	go get github.com/mattn/goveralls
	go get github.com/lib/pq
	go get github.com/denisenkom/go-mssqldb
	go get github.com/go-sql-driver/mysql
	go get github.com/mattn/go-sqlite3
	go get github.com/mattn/go-oci8
	go get github.com/alexbrainman/odbc

docker:
	rm -f .dockerignore
	ln -s .dockerignore.dist .dockerignore

	docker build -t ${IMAGE_NAME}:${GIT_SHA} .

	docker tag ${IMAGE_NAME}:${GIT_SHA} ${IMAGE_NAME}:${GIT_BRANCH}

	if [ -n "${GIT_TAG}" ] ; then \
		docker tag ${IMAGE_NAME}:${GIT_SHA} ${IMAGE_NAME}:${GIT_TAG} ; \
  fi;

	if [ "${GIT_BRANCH}" == "master" ]; then \
		docker tag ${IMAGE_NAME}:${GIT_SHA} ${IMAGE_NAME}:latest ; \
	fi;

test-travis:
	./test-cover.sh

bench:
	go test -run=none -bench=. -benchmem ./...

docker-push:
	docker push ${IMAGE_NAME}:${GIT_SHA}
	docker push ${IMAGE_NAME}:${GIT_BRANCH}

	if [ -n "${GIT_TAG}" ]; then \
		docker push ${IMAGE_NAME}:${GIT_TAG} ; \
  fi;

	if [ "${GIT_BRANCH}" == "master" ]; then \
		docker push ${IMAGE_NAME}:latest ; \
	fi;

fmt:
	go vet ./...
	go fmt ./...

lint:
	golint ./...

.PHONY: build dist
