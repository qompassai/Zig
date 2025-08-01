#!/usr/bin/env sh
# /qompassai/zig/scripts/quickstart.sh
# Qompass AI · Zig Quick‑Start (rootless, XDG, portable)
# Copyright (C) 2025 Qompass AI, All rights reserved
####################################################
set -eu
print() { printf '[zig-quickstart]: %s\n' "$1"; }
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
LOCAL_BIN="$HOME/.local/bin"
ZIG_CONFIG="$XDG_CONFIG_HOME/zig"
mkdir -p "$LOCAL_BIN" "$ZIG_CONFIG"
OS="$(uname | tr 'A-Z' 'a-z')"
ARCH="$(uname -m)"
case "$ARCH" in
x86_64 | amd64) ARCH="x86_64" ;;
arm64 | aarch64) ARCH="aarch64" ;;
*)
	print "Unsupported architecture: $ARCH"
	exit 1
	;;
esac
case "$OS" in
mingw* | msys* | cygwin*) OS="windows" ;;
esac
BANNER() {
	printf '╭────────────────────────────────────────────╮\n'
	printf '│    Qompass AI · Zig Quick‑Start            │\n'
	printf '╰────────────────────────────────────────────╯\n'
	printf '    © 2025 Amor Fati Labs. All rights reserved   \n\n'
}
BANNER
ZIG_LATEST="$(curl -fsSL https://ziglang.org/download/index.json | grep -o '"version": *"[^"]*"' | head -1 | cut -d'"' -f4)"
print "Detected latest Zig version: $ZIG_LATEST"
case "$OS" in
linux)
	PLATFORM="linux-$ARCH"
	EXT="tar.xz"
	;;
darwin)
	PLATFORM="macos-$ARCH"
	EXT="tar.xz"
	;;
windows)
	PLATFORM="windows-$ARCH"
	EXT="zip"
	;;
*)
	print "Unsupported or unknown OS: $OS"
	exit 1
	;;
esac
ZIG_BASENAME="zig-$ZIG_LATEST-$PLATFORM"
ZIG_URL="https://ziglang.org/download/$ZIG_LATEST/$ZIG_BASENAME.$EXT"
print "Downloading Zig from: $ZIG_URL"
cd /tmp
curl -fsSL -o "$ZIG_BASENAME.$EXT" "$ZIG_URL"
print "Extracting Zig..."
if [ "$EXT" = "tar.xz" ]; then
	tar -xf "$ZIG_BASENAME.$EXT"
elif [ "$EXT" = "zip" ]; then
	unzip -q "$ZIG_BASENAME.$EXT"
else
	print "Unexpected archive format: $EXT"
	exit 1
fi
print "Installing Zig to $LOCAL_BIN..."
if [ -f "$ZIG_BASENAME/zig" ]; then
	cp "$ZIG_BASENAME/zig" "$LOCAL_BIN/"
	chmod +x "$LOCAL_BIN/zig"
elif [ -f "$ZIG_BASENAME/zig.exe" ]; then
	cp "$ZIG_BASENAME/zig.exe" "$LOCAL_BIN/"
fi
rm -rf "/tmp/$ZIG_BASENAME"*
ZIG_BIN="$LOCAL_BIN/zig"
if [ -x "$ZIG_BIN" ]; then
	print "Installed Zig: $("$ZIG_BIN" version)"
else
	print "Error: Zig binary not found in $LOCAL_BIN"
	exit 1
fi
ZIGRC="$ZIG_CONFIG/zigrc"
if [ ! -f "$ZIGRC" ]; then
	cat >"$ZIGRC" <<EOF
# Zig XDG config file
# (Stub: add Zig build, linker, or custom driver flags below as needed)
EOF
	print "Created default Zig config at $ZIGRC"
fi
printf "\nAdd these lines to your shell profile for a clean Zig XDG setup:\n"
echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "export ZIG_CONFIG_DIR=\"$XDG_CONFIG_HOME/zig\"   # For Zig config files"
print "\nZig is ready! Run with: zig version"
print "To change settings, edit: $ZIGRC"
exit 0
