prefix ?= /usr/local
bindir = $(prefix)/bin
libdir = $(prefix)/lib

.PHONY: build install uninstall clean

build:
	swift build -c release --disable-sandbox

install: build
	install -d "$(bindir)" "$(libdir)"
	install ".build/release/swifty-dmg" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/swifty-dmg"

clean:
	rm -rf .build

