const std = @import("std");
const Config = @import("../main.zig").Config;
const getName = @import("get.zig").getName;
const getInstalledVersion = @import("get.zig").getInstalledVersion;
const GetPkgStatToInstall = @import("get.zig").GetPkgStatToInstall;
const GetInstalledPkgs = @import("get.zig").GetInstalledPkgs;

pub fn runProcess(io: anytype, argv: []const []const u8, path: []const u8) !void {
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .cwd = .{ .path = path },
        .stdout = .inherit,
        .stderr = .inherit,
        .stdin = .inherit,
    });
    _ = try child.wait(io);
}

pub fn runInstall(init: std.process.Init, pkg_item: []const u8) !void {
    var buf: [4096]u8 = undefined;
    const pkg = try GetPkgStatToInstall(init.io, pkg_item, &buf);
    const file_name = if (std.mem.lastIndexOfScalar(u8, pkg.url, '/')) |i| pkg.url[i + 1 ..] else pkg.url;
    const argv = [_][]const u8{ "curl", "-fSL", "-o", file_name, pkg.url };
    try runProcess(init.io, &argv, "/var/zp/install/");

    var tar_cmd_buf: [1024]u8 = undefined;
    const tar_cmd = try std.fmt.bufPrint(&tar_cmd_buf, "mkdir -p /var/zp/build/{s} && tar -xf /var/zp/install/{s} -C /var/zp/build/{s} --strip-components=1", .{ pkg_item, file_name, pkg_item });
    const argv_tar = [_][]const u8{ "sh", "-c", tar_cmd };
    try runProcess(init.io, &argv_tar, "/var/zp/install/");

    var buff: [256]u8 = undefined;
    const src = try std.fmt.bufPrint(&buff, "/var/zp/build/{s}", .{pkg_item});
    const pkg_bin = "/var/zp/pkg";

    var cmd: [4096]u8 = undefined;
    const build_cmd = try std.fmt.bufPrint(&cmd,
        \\set -e
        \\P=/usr
        \\D={s}
        \\mkdir -p "$D"
        \\if [ ! -x ./configure ] && {{ [ -f configure.ac ] || [ -f configure.in ]; }}; then
        \\  if [ -x ./autogen.sh ]; then ./autogen.sh; else autoreconf -fi; fi
        \\fi
        \\if [ -x ./configure ]; then
        \\  ./configure --prefix=$P
        \\  make -j$(nproc)
        \\  make install DESTDIR=$D
        \\elif [ -f CMakeLists.txt ]; then
        \\  cmake -B _zb -DCMAKE_INSTALL_PREFIX=$P
        \\  cmake --build _zb --parallel $(nproc)
        \\  DESTDIR=$D cmake --install _zb
        \\elif [ -f meson.build ]; then
        \\  meson setup _zb --prefix=$P
        \\  meson compile -C _zb
        \\  DESTDIR=$D meson install -C _zb
        \\elif [ -f Makefile ] || [ -f makefile ] || [ -f GNUmakefile ]; then
        \\  make -j$(nproc)
        \\  make install DESTDIR=$D
        \\else
        \\  echo "zp: Error: No cmake/make/meson files." >&2; exit 1
        \\fi
        \\cp -a /var/zp/pkg/. /
    , .{pkg_bin});

    const argv_make = [_][]const u8{ "sh", "-c", build_cmd };
    try runProcess(init.io, &argv_make, src);

    try removePkgEntry(init, "/var/zp/install/packages.db", pkg_item, &cmd);

    var buffer: [4096]u8 = undefined;
    try writeFile(init, "/var/zp/install/packages.db", pkg_item, pkg.version, &buffer);
}

pub fn writeFile(init: std.process.Init, file: []const u8, pkg: []const u8, version: []const u8, buffer: []u8) !void {
    try removePkgEntry(init, file, pkg, buffer);
    const clean_version = std.mem.trim(u8, version, "\n\r ");
    const open_file = std.Io.Dir.cwd().openFile(init.io, file, .{ .mode = .read_write }) catch |err| {
        if (err == error.FileNotFound) {
            const new_file = try std.Io.Dir.cwd().createFile(init.io, file, .{});
            defer new_file.close(init.io);
            const name_version = try std.fmt.bufPrint(buffer, "{s} {s}\n", .{ pkg, clean_version });
            const stat = try new_file.stat(init.io);
            const size = stat.size;
            _ = try new_file.writePositionalAll(init.io, name_version, size);
            return;
        }
        return err;
    };
    defer open_file.close(init.io);

    const stat = try open_file.stat(init.io);
    const file_size = stat.size;
    const name_version = try std.fmt.bufPrint(buffer, "{s} {s}\n", .{ pkg, clean_version });
    _ = try open_file.writePositionalAll(init.io, name_version, file_size);
}

pub fn removePkgEntry(init: std.process.Init, file: []const u8, pkg: []const u8, buffer: []u8) !void {
    const open_file = std.Io.Dir.cwd().openFile(init.io, file, .{}) catch return;
    defer open_file.close(init.io);

    var reader = open_file.reader(init.io, buffer);
    var content: std.ArrayList(u8) = .empty;
    defer content.deinit(init.arena.allocator());
    const tmp_path = "/var/zp/install/packages.db.tmp";
    const tmp_file = try std.Io.Dir.cwd().createFile(init.io, tmp_path, .{});
    defer tmp_file.close(init.io);

    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (std.mem.eql(u8, name, pkg)) continue;

        var line_buf: [4096]u8 = undefined;
        const line_with_newline = try std.fmt.bufPrint(&line_buf, "{s}\n", .{line});
        const stat_file = try tmp_file.stat(init.io);
        const size = stat_file.size;
        _ = try tmp_file.writePositionalAll(init.io, line_with_newline, size);
    }
    const argv = [_][]const u8{ "mv", tmp_path, file };
    var child = try std.process.spawn(init.io, .{
        .argv = &argv,
        .cwd = .{ .path = "/" },
    });
    _ = try child.wait(init.io);
}

fn upgradePackage(init: std.process.Init, pkg_name: []const u8, buffer: []u8) !void {
    const installed_ver = try getInstalledVersion(init.io, pkg_name, buffer);
    if (installed_ver) |iv| {
        const pkg = try GetPkgStatToInstall(init.io, pkg_name, buffer);
        if (!std.mem.eql(u8, iv, pkg.version)) {
            std.debug.print("Updating {s}: {s} → {s}\n", .{ pkg_name, iv, pkg.version });
            try runInstall(init, pkg_name);
        } else {
            std.debug.print("{s} is up to date ({s})\n", .{ pkg_name, iv });
        }
    } else {
        std.debug.print("Package '{s}' is not installed\n", .{pkg_name});
    }
}

fn upgradeAll(init: std.process.Init, buffer: []u8) !void {
    const file = std.Io.Dir.cwd().openFile(init.io, "/var/zp/install/packages.db", .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("No installed packages found\n", .{});
            return;
        }
        return err;
    };
    defer file.close(init.io);

    var reader = file.reader(init.io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const pkg_name = tokens.next() orelse continue;
        try upgradePackage(init, pkg_name, buffer);
    }
}

pub fn run(init: std.process.Init, pkg_item: []const u8, config: Config, allocator: anytype) !void {
    if (config.Upgrade) {
        var buffer: [4096]u8 = undefined;
        const argv = [_][]const u8{ "sh", "-c", "/var/zp/mirrors/gen.sh" };
        try runProcess(init.io, &argv, ".");

        if (pkg_item.len > 0 and !std.mem.eql(u8, pkg_item, "none-package")) {
            try upgradePackage(init, pkg_item, &buffer);
        } else {
            try upgradeAll(init, &buffer);
        }
    }

    if (config.list) {
        var buffer: [8096]u8 = undefined;
        const massive: std.ArrayList([]const u8) = try GetInstalledPkgs(init.io, &buffer, allocator);
        if (massive.items.len == 0) {
            std.debug.print("No pkgs installed.", .{});
        } else {
            for (massive.items) |i| {
                std.debug.print("{s}\n", .{i});
            }
        }
    }

    if (config.search) {
        var buffer: [4096]u8 = undefined;
        const find = try getName(init.io, pkg_item, &buffer);
        if (!find) {
            std.debug.print("No find '{s}'\n", .{pkg_item});
        } else std.debug.print("Find '{s}'\n", .{pkg_item});
    }
    if (config.update) {
        const argv = [_][]const u8{ "sh", "-c", "/var/zp/mirrors/gen.sh" };
        try runProcess(init.io, &argv, ".");
    }

    if (config.install) {
        try runInstall(init, pkg_item);
    } else if (config.remove) {
        if (std.mem.eql(u8, pkg_item, "none-package")) return;
        var cmd_remove: [4096]u8 = undefined;
        const remove_cmd = try std.fmt.bufPrint(&cmd_remove, "rm -rf /usr/bin/{s} /var/zp/pkg/{s} /usr/local/bin/{s} /usr/local/share/man/man1/{s}.1", .{ pkg_item, pkg_item, pkg_item, pkg_item });
        const argv_remove = [_][]const u8{ "sh", "-c", remove_cmd };
        try runProcess(init.io, &argv_remove, "/");
        std.debug.print("Successful uninstalled pkg: {s}\n", .{pkg_item});
    }
}
