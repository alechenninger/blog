.PHONY: build watch init

build:
	@blog build

watch:
	@blog watch

init:
	@pub global activate --source path build/
