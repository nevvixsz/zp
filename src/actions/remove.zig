const std = @import("std");
const runProcess = @import("add.zig").runProcess;
const removePkgEntry = @import("add.zig").removePkgEntry;

pub fn remove(init: std.process.Init, pkg_item: []const u8) !void {
    var list_path_buf: [256]u8 = undefined;
    const list_path = try std.fmt.bufPrint(&list_path_buf, "/var/zp/installed/{s}.list", .{pkg_item});
    const cwd = std.Io.Dir.cwd();
    const allocator = init.arena.allocator();
    const list_file = cwd.openFile(init.io, list_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Package '{s}' is not installed\n", .{pkg_item});
            return;
        }
        return err;
    };
    defer list_file.close(init.io);
    var root_dir = try std.Io.Dir.openDirAbsolute(init.io, "/", .{});
    defer root_dir.close(init.io);
    var file_paths: std.ArrayList([]const u8) = .empty;
    defer {
        for (file_paths.items) |path| allocator.free(path);
        file_paths.deinit(allocator);
    }
    var buffer: [4096]u8 = undefined;
    var reader = list_file.reader(init.io, &buffer);

    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (line.len == 0) continue;

        const rel_path = if (std.mem.startsWith(u8, line, "/")) line[1..] else line;
        const path_copy = try allocator.dupe(u8, rel_path);
        try file_paths.append(allocator, path_copy);
        root_dir.deleteFile(init.io, rel_path) catch |err| switch (err) {
            error.FileNotFound => continue,
            error.IsDir => continue,
            else => {
                std.debug.print("Failed to remove {s}: {}\n", .{ rel_path, err });
                continue;
            },
        };
    }
    try removeEmptyDirs(init.io, allocator, file_paths, root_dir);
    try cwd.deleteFile(init.io, list_path);
    var cmd_buf: [4096]u8 = undefined;
    try removePkgEntry(init, "/var/zp/install/packages.db", pkg_item, &cmd_buf);
    std.debug.print("Package '{s}' removed successfully\n", .{pkg_item});
}

pub fn removeEmptyDirs(io: anytype, allocator: anytype, file_paths: std.ArrayList([]const u8), root_dir: std.Io.Dir) !void {
    var dir_list: std.ArrayList([]const u8) = .empty;
    defer {
        for (dir_list.items) |item| allocator.free(item);
        dir_list.deinit(allocator);
    }

    for (file_paths.items) |rel_path| {
        if (std.fs.path.dirname(rel_path)) |parent| {
            const parent_copy = try allocator.dupe(u8, parent);
            var exists = false;
            for (dir_list.items) |existing| {
                if (std.mem.eql(u8, existing, parent_copy)) {
                    allocator.free(parent_copy);
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                try dir_list.append(allocator, parent_copy);
            }
        }
    }
    std.mem.sort([]const u8, dir_list.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.count(u8, a, "/") > std.mem.count(u8, b, "/");
        }
    }.lessThan);
    for (dir_list.items) |dir_path| {
        root_dir.deleteDir(io, dir_path) catch |err| switch (err) {
            error.DirNotEmpty => continue,
            error.FileNotFound => continue,
            else => {
                std.debug.print("Failed to remove dir {s}: {}", .{ dir_path, err });
                continue;
            },
        };
    }
}
