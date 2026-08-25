const std = @import("std");

pub const Package_Stat = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8,
};

pub fn GetPkgStatToInstall(io: anytype, pkg: []const u8, buffer: []u8) !Package_Stat {
    const file = try std.Io.Dir.cwd().openFile(io, "/var/zp/mirrors/zp.packages", .{});
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        const version = tokens.next() orelse return error.MalformedLine;
        const url = tokens.next() orelse return error.MalformedLine;
        return .{ .name = name, .version = version, .url = url };
    }
    return error.PackageNotFound;
}

pub fn getName(io: anytype, pkg: []const u8, buffer: []u8) !bool {
    const file = try std.Io.Dir.cwd().openFile(io, "/var/zp/mirrors/zp.packages", .{});
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');

        const name = tokens.next() orelse continue;
        if (std.mem.eql(u8, pkg, name)) {
            return true;
        }
    }
    return false;
}

pub fn getInstalledVersion(io: anytype, pkg: []const u8, buffer: []u8) !?[]const u8 {
    const file = std.Io.Dir.cwd().openFile(io, "/var/zp/install/packages.db", .{}) catch return null;
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        return tokens.next();
    }
    return null;
}

pub fn GetInstalledPkgs(io: anytype, buffer: []u8, allocator: anytype) !std.ArrayList([]const u8) {
    const file = try std.Io.Dir.cwd().openFile(io, "/var/zp/install/packages.db", .{});
    defer file.close(io);
    var massive: std.ArrayList([]const u8) = .empty;
    defer massive.deinit(allocator);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');

        const name = tokens.next() orelse continue;
        try massive.append(allocator, name);
    }
    return massive;
}
