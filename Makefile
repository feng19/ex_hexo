all: build
.PHONY: build regen_example

build:
	mix escript.build
	cp ex-hexo example

regen_example:
	cd example && ./ex-hexo
