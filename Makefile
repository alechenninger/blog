.PHONY: build watch init

build:
	@build_blog build

watch:
	@build_blog watch

init:
	@pub global activate --source path build/
