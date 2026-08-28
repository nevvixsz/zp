const std = @import("std");
const run = @import("run.zig").run;
const help = @import("help.zig").help;
const initialize = @import("init.zig").initialize;

fn strEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub const Config = struct {
    install: bool = false,
    remove: bool = false,
    update: bool = false,
    search: bool = false,
    init: bool = false,
    help: bool = false,
    version: bool = false,
    Upgrade: bool = false,
    list: bool = false,

    fn regArg(self: *Config, arg: []const u8) void {
        self.install = strEql(arg, "-i") or strEql(arg, "--install");
        self.remove = strEql(arg, "-r") or strEql(arg, "--remove");
        self.update = strEql(arg, "-u") or strEql(arg, "--update");
        self.search = strEql(arg, "-s") or strEql(arg, "--search");
        self.Upgrade = strEql(arg, "-U") or strEql(arg, "--upgrade");
        self.init = strEql(arg, "--init");
        self.help = strEql(arg, "--help") or strEql(arg, "-h");
        self.version = strEql(arg, "--version") or strEql(arg, "-v");
        self.list = strEql(arg, "-l") or strEql(arg, "--list");
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var args = try init.minimal.args.toSlice(allocator);
    var pkg_list: std.ArrayList([]const u8) = .empty;
    defer pkg_list.deinit(allocator);

    var config = Config{};

    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            config.regArg(arg);
            continue;
        }
        try pkg_list.append(allocator, arg);
    }

    if (config.init) {
        try initialize(init.io);
    }

    if (config.help) {
        help();
        return;
    }

    if (config.version) {
        std.debug.print("zp version 0.1.1\n", .{});
        return;
    }

    if (pkg_list.items.len == 0) {
        try pkg_list.append(allocator, "none-package");
    }

    for (pkg_list.items) |pkg| {
        try run(init, pkg, config, allocator);
    }
}
