const std = @import("std");
const runZP = @import("src/runZP.zig").runZP;
const init_zp = @import("src/init_zp.zig").init_zp;

pub const Config = struct {
    install: bool = false,
    remove: bool = false,
    update: bool = false,
    search: bool = false,
    init: bool = false,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    var args = try init.minimal.args.toSlice(allocator);
    var pkg_list: std.ArrayList([]const u8) = .empty;
    defer pkg_list.deinit(allocator);

    var config = Config{};

    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-i")) config.install = true;
            if (std.mem.eql(u8, arg, "-r")) config.remove = true;
            if (std.mem.eql(u8, arg, "-u")) config.update = true;
            if (std.mem.eql(u8, arg, "-s")) config.search = true;
            if (std.mem.eql(u8, arg, "--init")) config.init = true;
            continue;
        }
        try pkg_list.append(allocator, arg);
    }

    if (config.init) {
        try init_zp(io);
    }

    if (pkg_list.items.len == 0) {
        try pkg_list.append(allocator, "none-package");
    }

    for (pkg_list.items) |pkg| {
        try runZP(io, pkg, config);
    }
}
