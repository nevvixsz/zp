const std = @import("std");
const runProcess = @import("add.zig").runProcess;

pub fn remove(init: std.process.Init, pkg_item: []const u8) !void {
    if (std.mem.eql(u8, pkg_item, "none-package")) return;
    var cmd_remove: [4096]u8 = undefined;
    const remove_cmd = try std.fmt.bufPrint(&cmd_remove, "rm -rf /usr/bin/{s} /var/zp/pkg/{s} /usr/local/bin/{s} /usr/local/share/man/man1/{s}.1", .{ pkg_item, pkg_item, pkg_item, pkg_item });
    const argv_remove = [_][]const u8{ "sh", "-c", remove_cmd };
    try runProcess(init.io, &argv_remove, "/");
    std.debug.print("Successful uninstalled pkg: {s}\n", .{pkg_item});
}
