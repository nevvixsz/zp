const std = @import("std");
const initialize = @import("actions/init.zig").init;
const help = @import("actions/help.zig").help;
const version = @import("actions/version.zig").version;
const add = @import("actions/add.zig").add;
const remove = @import("actions/remove.zig").remove;
const sync = @import("actions/sync.zig").sync;
const u = @import("actions/update.zig");
const list = @import("actions/list.zig").list;
const search = @import("actions/search.zig").search;
const StrList = std.ArrayList([]const u8);

const Action = enum {
    init,
    help,
    version,
    add,
    remove,
    sync,
    update,
    list,
    search,
};

fn strEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var args = try init.minimal.args.toSlice(allocator);
    var pkgs: StrList = .empty;
    var flags: StrList = .empty;

    defer pkgs.deinit(allocator);
    defer flags.deinit(allocator);

    var strAction: ?[]const u8 = null;

    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            try flags.append(allocator, arg);
        } else {
            if (strAction == null) {
                strAction = arg;
            } else {
                try pkgs.append(allocator, arg);
            }
        }
    }

    const action = std.meta.stringToEnum(Action, strAction orelse "") orelse .help;

    switch (action) {
        .init => try initialize(init.io),
        .help => help(),
        .version => version(),
        .add => if (pkgs.items.len == 0) {
            std.debug.print("Error: Package unspecified", .{});
            help();
        } else {
            for (pkgs.items) |pkg| {
                try add(init, pkg);
            }
        },
        .remove => for (pkgs.items) |pkg| {
            try remove(init, pkg);
        },
        .sync => try sync(init),
        .update => if (pkgs.items.len == 0) {
            try u.updateAll(init);
        } else {
            for (pkgs.items) |pkg| {
                try u.updatePkg(init, pkg);
            }
        },
        .list => try list(init, allocator),
        .search => for (pkgs.items) |pkg| {
            std.debug.print("Package {s}:\n", .{pkg});
            try search(init, pkg);
            std.debug.print("\n\n", .{});
        },
    }
}
