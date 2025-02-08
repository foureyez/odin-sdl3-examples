build:
	odin build .   

build-debug:
	odin build . -debug

build-release:
	odin build . -o:aggressive

check:
	odin strip-semicolon . -collection:deps=deps 
	odin check . -collection:engine=engine

doc:
	odin doc . 

run:
	odin run .
