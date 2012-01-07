ifeq ($(shell uname -sm | sed -e s,x86_64,i386,),Darwin i386)
#osx
LUABUILDNAME=macosx
else
# linux
LUABUILDNAME=linux
endif

all: test

test: clean get build luatest

get:
	git clone http://repo.or.cz/r/lua.git

build:
	cd lua/src; make $(LUABUILDNAME)
	ln -s lua/src/lua ./luaexec

luatest:
	./luaexec test.lua

clean:
	rm -rf lua luaexec
