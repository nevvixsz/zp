const std = @import("std");

pub fn getUrl(io: anytype, pkg: []const u8, buffer: []u8) ![]const u8 {
    const file = try std.Io.Dir.cwd().openFile(io, "/var/zp/mirrors/zp.packages", .{});
    defer file.close(io);

    var reader = file.reader(io, buffer);
    while (try reader.interface.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const name = tokens.next() orelse continue;
        if (!std.mem.eql(u8, name, pkg)) continue;

        const url = tokens.next() orelse return error.MalformedLine;
        return url;
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
        if (std.mem.startsWith(u8, pkg, name)) {
            return true;
        }
    }
    return false;
}
