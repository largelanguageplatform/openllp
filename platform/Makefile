MIX_ENV=dev

.PHONY: build
build:
	mix compile

.PHONY: test
test:
	mix precommit

.PHONY: rel
rel:
	MIX_ENV=$(MIX_ENV) mix assets.build
	MIX_ENV=$(MIX_ENV) mix release --overwrite

.PHONY: docker
docker:
	docker build --build-arg ENV=debug -t openllp/platform:latest .

.PHONY: up
up:
	docker-compose up

.PHONY: up-detached
up-detached:
	docker-compose up -d

.PHONY: down
down:
	docker-compose down

.PHONY: restart
restart:
	docker-compose down
	docker-compose up --build

.PHONY: logs
logs:
	docker-compose logs -f platform
