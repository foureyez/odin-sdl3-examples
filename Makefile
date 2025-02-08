build:
	odin build . -collection:deps=deps  

build-debug:
	odin build . -collection:deps=deps -debug

build-release:
	odin build . -collection:deps=deps -o:aggressive

check:
	odin strip-semicolon . -collection:deps=deps 
	odin check . -collection:deps=deps -collection:engine=engine

doc:
	odin doc . -collection:deps=deps 

run:
	odin run . -collection:deps=deps 
