// 00_hello.zig — toolchain: Zig 0.13+ (https://ziglang.org/)
// One idea per file: the smallest runnable Zig program.
const std = @import("std");

pub fn main() void {
    std.debug.print("Hello from the Qompass AI Zig template.\n", .{});
}
