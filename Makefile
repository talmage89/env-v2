IMAGE := dev-env

build:
	./scripts/build.sh

clean:
	-docker rmi $(IMAGE)

rebuild: clean build
