const std = @import("std");
const p = @import("../parser.zig");

pub fn list(init: std.process.Init, allocator: anytype) !void {
    var buffer: [8096]u8 = undefined;
    const massive: std.ArrayList([]const u8) = try p.GetInstalledPkgs(init.io, &buffer, allocator);
    if (massive.items.len == 0) {
        std.debug.print("No pkgs installed.", .{});
    } else {
        for (massive.items) |i| {
            std.debug.print("{s}\n", .{i});
        }
    }
}
