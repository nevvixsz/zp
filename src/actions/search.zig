const std = @import("std");
const p = @import("../parser.zig");

pub fn search(init: std.process.Init, pkg_item: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    const find = try p.getName(init.io, pkg_item, &buffer);
    if (!find) {
        std.debug.print("No find '{s}'\n", .{pkg_item});
    } else std.debug.print("Find '{s}'\n", .{pkg_item});
}
