const std = @import("std");
const p = @import("../parser.zig");
const a= @import("add.zig");

pub fn updatePkg(init: std.process.Init, pkg_name: []const u8) !void {
    var buffer: [4096] u8 = undefined;
    const installed_ver = try p.getInstalledVersion(init.io, pkg_name, &buffer);

    if (installed_ver) |iv| {
        const pkg = try p.GetPkgStatToInstall(init.io, pkg_name, &buffer);

        if (!std.mem.eql(u8, iv, pkg.version)) {
            std.debug.print("Updating {s}: {s} → {s}\n", .{ pkg_name, iv, pkg.version });
            try a.add(init, pkg_name);
        } else {
            std.debug.print("{s} is up to date ({s})\n", .{ pkg_name, iv });
        }
    } else {
        std.debug.print("Package '{s}' is not installed\n", .{pkg_name});
    }
}

pub fn updateAll(init: std.process.Init) !void {
    var buffer: [4096] u8 = undefined;
    const file = std.Io.Dir.cwd().openFile(init.io, "/var/zp/install/packages.db", .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("No installed packages found\n", .{});
            return;
        }
        return err;
    };
    defer file.close(init.io);

    var reader = file.reader(init.io, &buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const pkg_name = tokens.next() orelse continue;
        try updatePkg(init, pkg_name);
    }
}

// update == upgrade
