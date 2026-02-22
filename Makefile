IMAGE := dev-env

build:
	docker build -t $(IMAGE) .

clean:
	-docker rmi $(IMAGE)

rebuild: clean build
