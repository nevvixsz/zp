const std = @import("std");
const runProcess = @import("add.zig").runProcess;

pub fn sync(init: std.process.Init) !void {
    const argv = [_][]const u8{ "sh", "-c", "/var/zp/mirrors/gen.sh" };
    try runProcess(init.io, &argv, ".");
}
