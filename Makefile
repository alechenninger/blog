.PHONY: build init

build:
	@build_blog

init:
	@pub global activate --source path build/
