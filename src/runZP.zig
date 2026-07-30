const std = @import("std");
const Config = @import("../main.zig").Config;
const getUrl = @import("get.zig").getUrl;
const getName = @import("get.zig").getName;

pub fn runZP(io: anytype, pkg_item: []const u8, config: Config) !void {
    if (config.search) {
        var buffer: [4096]u8 = undefined;
        const find = try getName(io, pkg_item, &buffer);
        if (!find) {
            std.debug.print("No find package '{s}' in /var/zp/mirrors/zp.packages\n", .{pkg_item});
        } else std.debug.print("Find package '{s}' in /var/zp/mirrors/zp.packages\n", .{pkg_item});
    }
    if (config.update) {
        const argv = [_][]const u8{ "sh", "-c", "/var/zp/mirrors/gen.sh" };
        var child = try std.process.spawn(io, .{
            .argv = &argv,
            .cwd = .{ .path = "/var/zp/mirrors/" },
            .stdout = .inherit,
            .stderr = .inherit,
        });
        _ = try child.wait(io);
    }

    if (config.install) {
        if (std.mem.eql(u8, pkg_item, "none-package")) return;
        var buf: [4096]u8 = undefined;
        const url = try getUrl(io, pkg_item, &buf);
        const file_name = if (std.mem.lastIndexOfScalar(u8, url, '/')) |i| url[i + 1 ..] else url;
        const argv = [_][]const u8{ "curl", "-fSL", "-o", file_name, url };
        var child = try std.process.spawn(io, .{
            .argv = &argv,
            .cwd = .{ .path = "/var/zp/install/" },
            .stdout = .inherit,
            .stderr = .inherit,
        });

        const term_curl = try child.wait(io);
        switch (term_curl) {
            .exited => |code| switch (code) {
                0 => std.debug.print("Installed!\n", .{}),
                else => std.debug.print("curl: Error exiting code: {d}\n", .{code}),
            },
            else => std.debug.print("Error curl install.\n", .{}),
        }

        var tar_cmd_buf: [1024]u8 = undefined;
        const tar_cmd = try std.fmt.bufPrint(&tar_cmd_buf, "mkdir -p /var/zp/build/{s} && tar -xf /var/zp/install/{s} -C /var/zp/build/{s} --strip-components=1", .{ pkg_item, file_name, pkg_item });
        const argv_tar = [_][]const u8{ "sh", "-c", tar_cmd };
        var child_tar = try std.process.spawn(io, .{
            .argv = &argv_tar,
            .cwd = .{ .path = "/var/zp/install/" },
            .stdout = .inherit,
            .stdin = .inherit,
        });
        _ = try child_tar.wait(io);

        var buff: [256]u8 = undefined;
        const src = try std.fmt.bufPrint(&buff, "/var/zp/build/{s}", .{pkg_item});
        const pkg_bin = "/var/zp/pkg";

        var cmd: [4096]u8 = undefined;
        const build_cmd = try std.fmt.bufPrint(&cmd,
            \\set -e
            \\P=/usr
            \\D={s}
            \\mkdir -p "$D"
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
        var child_make = try std.process.spawn(io, .{
            .argv = &argv_make,
            .cwd = .{ .path = src },
            .stdout = .inherit,
            .stderr = .inherit,
        });
        _ = try child_make.wait(io);
    } else if (config.remove) {
        if (std.mem.eql(u8, pkg_item, "none-package")) return;
        var cmd_remove: [4096]u8 = undefined;
        const remove_cmd = try std.fmt.bufPrint(&cmd_remove, "rm -rf /usr/bin/{s} && rm -rf /var/zp/pkg/{s} && rm -rf /usr/local/bin/{s} && rm -rf /usr/local/share/man/man1/{s}.1", .{ pkg_item, pkg_item, pkg_item, pkg_item });
        const argv_remove = [_][]const u8{ "sh", "-c", remove_cmd };
        var child_remove = try std.process.spawn(io, .{
            .argv = &argv_remove,
            .cwd = .{ .path = "/" },
            .stdout = .inherit,
            .stderr = .inherit,
        });
        _ = try child_remove.wait(io);
        std.debug.print("Successful uninstalled pkg: {s}\n", .{pkg_item});
    }
}
