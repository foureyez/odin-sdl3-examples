build:
	odin build . -out:app

build-debug:
	odin build . -debug -out:app_debug

build-release:
	odin build . -o:aggressive -out:app

check:
	odin strip-semicolon . -collection:deps=deps 
	odin check . -collection:engine=engine

doc:
	odin doc . 

run:
	odin run . -out:app
