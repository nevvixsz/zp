const std = @import("std");
const p = @import("../parser.zig");

pub fn list(init: std.process.Init, allocator: std.mem.Allocator) !void {
    var buffer: [8096]u8 = undefined;
    var massive: std.ArrayList([]const u8) = try p.GetInstalledPkgs(init.io, &buffer, allocator);

    defer {
        for (massive.items) |i| {
            allocator.free(i);
        }
        massive.deinit(allocator);
    }

    if (massive.items.len == 0) {
        std.debug.print("No pkgs installed.\n", .{});
    } else {
        for (massive.items) |i| {
            std.debug.print("{s}\n", .{i});
        }
    }
}
