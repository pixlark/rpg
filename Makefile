ZIGFLAGS=-I/usr/include -L/usr/lib/x86_64-linux-gnu -lc -lSDL2

all: rpg

rpg: *.zig
	zig $(ZIGFLAGS) build-exe main.zig --name rpg
	rm *.o

.PHONY: all
