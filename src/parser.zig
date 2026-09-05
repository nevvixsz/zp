const std = @import("std");
const e = @import("types.zig").Error;
const Dir = std.Io.Dir;

pub const PkgStat = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8,
};

pub fn GetPkgStatToInstall(io: anytype, pkg: []const u8, buffer: []u8, allocator: std.mem.Allocator) !PkgStat {
    const file = try Dir.openFileAbsolute(io, "/var/zp/mirrors/zp.packages", .{});
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        const version = tokens.next() orelse return e.VersionNotFound;
        const url = tokens.next() orelse return e.NoURLFound;
        return .{ .name = try allocator.dupe(u8, name), .version = try allocator.dupe(u8, version), .url = try allocator.dupe(u8, url) };
    }
    return e.PkgNotFound;
}

pub fn getName(io: anytype, pkg: []const u8, buffer: []u8) !bool {
    const file = try Dir.openFileAbsolute(io, "/var/zp/mirrors/zp.packages", .{});
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

pub fn getInstalledVersion(io: anytype, pkg: []const u8, buffer: []u8, allocator: std.mem.Allocator) !?[]const u8 {
    const file = Dir.openFileAbsolute(io, "/var/zp/install/packages.db", .{}) catch return null;
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;
        const version = tokens.next() orelse return null;
        return try allocator.dupe(u8, version);
    }
    return null;
}

pub fn GetInstalledPkgs(io: anytype, buffer: []u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    const file = try Dir.openFileAbsolute(io, "/var/zp/install/packages.db", .{});
    defer file.close(io);
    var massive: std.ArrayList([]const u8) = .empty;

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');

        const name = tokens.next() orelse continue;
        const name_copy = try allocator.dupe(u8, name);
        try massive.append(allocator, name_copy);
    }
    return massive;
}
