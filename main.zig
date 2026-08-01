const std = @import("std");
const runZP = @import("src/runZP.zig").runZP;
const init_zp = @import("src/init_zp.zig").init_zp;

fn strEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub const Config = struct {
    install: bool = false,
    remove: bool = false,
    update: bool = false,
    search: bool = false,
    init: bool = false,

    fn applyArg(self: *Config, arg: []const u8) void {
        self.install = strEql(arg, "-i");
        self.remove = strEql(arg, "-r");
        self.update = strEql(arg, "-u");
        self.search = strEql(arg, "-s");
        self.init = strEql(arg, "--init");
    }
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
            config.applyArg(arg);
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
