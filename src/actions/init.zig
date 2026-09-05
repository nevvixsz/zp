const std = @import("std");
const Dir = std.Io.Dir;

pub fn createDirectories(io: anytype, root: []const u8) !void {
    var path_buf: [256]u8 = undefined;
    const dir = Dir.cwd();

    var path_len: usize = if (root[0] == '/') 1 else 0;
    if (path_len == 1) path_buf[0] = '/';
    var parts = std.mem.tokenizeScalar(u8, root, '/');
    while (parts.next()) |part| {
        if (path_len > 1) {
            path_buf[path_len] = '/';
            path_len += 1;
        }
        @memcpy(path_buf[path_len..][0..part.len], part);
        path_len += part.len;
        const path = path_buf[0..path_len];
        dir.createDir(io, path, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    for ([_][]const u8{ "build", "install", "mirrors", "pkg" }) |part| {
        const path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ root, part });
        dir.createDir(io, path, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
}

pub fn init(io: anytype) !void {
    std.debug.print("Initializing zp...\n", .{});

    try createDirectories(io, "/var/zp");

    const file = try Dir.createFileAbsolute(io, "/var/zp/mirrors/gen.sh", .{});
    defer file.close(io);

    const cmd =
        \\#!/usr/bin/env bash
        \\set -u
        \\VOID_URL="https://github.com/void-linux/void-packages"
        \\KISS_URL="https://github.com/kisslinux/repo"
        \\VOID_TREE="/var/zp/mirrors/tree"
        \\KISS_TREE="/var/zp/mirrors/kiss"
        \\CRUX_BASE="/var/zp/mirrors"
        \\OUT="/var/zp/mirrors/zp.packages"
        \\mkdir -p /var/zp/mirrors
        \\
        \\echo "zp: update void..."
        \\if [ -d "$VOID_TREE/.git" ]; then git -C "$VOID_TREE" pull --ff-only >/dev/null 2>&1 || true
        \\else git clone --depth 1 "$VOID_URL" "$VOID_TREE"; fi
        \\
        \\echo "zp: update kiss..."
        \\if [ -d "$KISS_TREE/.git" ]; then git -C "$KISS_TREE" pull --ff-only >/dev/null 2>&1 || true
        \\else git clone --depth 1 "$KISS_URL" "$KISS_TREE"; fi
        \\
        \\echo "zp: update crux..."
        \\for repo in core opt xorg; do
        \\  t="$CRUX_BASE/crux-$repo"
        \\  if [ -d "$t/.git" ]; then git -C "$t" pull --ff-only >/dev/null 2>&1 || true
        \\  else git clone --depth 1 "https://git.crux.nu/ports/$repo.git" "$t"; fi
        \\done
        \\
        \\echo "zp: parse void..."
        \\grep -rH --include=template -E '^[A-Za-z_][A-Za-z0-9_]*=' "$VOID_TREE/srcpkgs" | awk '
        \\function lsub(s, from, to,    p, out, n) {
        \\  out = ""; n = length(from)
        \\  while ((p = index(s, from)) > 0) { out = out substr(s, 1, p-1) to; s = substr(s, p+n) }
        \\  return out s
        \\}
        \\function emit(    s, k, pass, n, parts, name, ver) {
        \\  if (file == "" || dist == "") return
        \\  s = dist
        \\  for (pass = 0; pass < 3; pass++)
        \\    for (k in V) s = lsub(s, "${" k "}", V[k])
        \\  gsub(/[ \t"]+/, " ", s); sub(/^ /, "", s); sub(/ .*$/, "", s)
        \\  if (s == "" || index(s, "$") || index(s, ">") || index(s, "{") || index(s, "}")) return
        \\  name = pkg
        \\  if (name == "") { n = split(file, parts, "/"); name = parts[n-1] }
        \\  ver = V["version"]
        \\  if (ver == "" || index(ver, "$")) return
        \\  print name, ver, s
        \\}
        \\{
        \\  raw = $0; c = index(raw, ":")
        \\  f = substr(raw, 1, c-1); line = substr(raw, c+1)
        \\  if (f != file) { emit(); file = f; for (k in V) delete V[k]; pkg = ""; dist = "" }
        \\  if (match(line, /^[A-Za-z_][A-Za-z0-9_]*=/)) {
        \\    k = substr(line, 1, RLENGTH-1); v = substr(line, RLENGTH+1)
        \\    sub(/^["'\'']/, "", v); sub(/["'\'']$/, "", v)
        \\    V[k] = v
        \\    if (k == "pkgname")   pkg  = v
        \\    if (k == "distfiles") dist = v
        \\  }
        \\}
        \\END { emit() }
        \\' > /var/zp/mirrors/.void.tmp
        \\
        \\echo "zp: parse kiss..."
        \\(
        \\for d in "$KISS_TREE"/*/*/; do
        \\  [ -f "$d/sources" ] || continue
        \\  name=$(basename "$d")
        \\  ver=$(awk '{print $1; exit}' "$d/version" 2>/dev/null)
        \\  [ -z "$ver" ] && continue
        \\  while IFS= read -r src; do
        \\    case "$src" in
        \\      '') continue ;;
        \\      '#'*) continue ;;
        \\    esac
        \\    url=${src//VERSION/$ver}
        \\    case "$url" in http://*|https://*) ;; *) continue;; esac
        \\    case "$url" in *.git|*git://*) continue;; esac
        \\    echo "$name $ver $url"
        \\  done < "$d/sources"
        \\done
        \\) > /var/zp/mirrors/.kiss.tmp
        \\
        \\echo "zp: parse crux..."
        \\(
        \\for repo in core opt xorg; do
        \\  t="$CRUX_BASE/crux-$repo"
        \\  for d in "$t"/*/; do
        \\    [ -f "$d/Pkgfile" ] || continue
        \\    name=$(grep -m1 '^name=' "$d/Pkgfile" | cut -d= -f2)
        \\    ver=$(grep -m1 '^version=' "$d/Pkgfile" | cut -d= -f2)
        \\    [ -z "$name" ] && name=$(basename "$d")
        \\    [ -z "$ver" ] && continue
        \\    grep -m1 '^source=' "$d/Pkgfile" | grep -oE 'https?://[^ )"]+' | while IFS= read -r url; do
        \\      url=${url//\$version/$ver}
        \\      url=${url//\${version}/$ver}
        \\      url=${url//\$name/$name}
        \\      url=${url//\${name}/$name}
        \\      case "$url" in *.git|*git://*) continue;; esac
        \\      echo "$name $ver $url"
        \\    done
        \\  done
        \\done
        \\) > /var/zp/mirrors/.crux.tmp
        \\
        \\echo "zp: merge (dedup by name, priority: void > crux > kiss)..."
        \\cat /var/zp/mirrors/.void.tmp /var/zp/mirrors/.crux.tmp /var/zp/mirrors/.kiss.tmp \
        \\  | grep -vF '$' | grep -vF '>' | grep -vF '{' | grep -vF '}' | awk 'NF >= 3 && !seen[$1]++' | sort > "$OUT"
        \\rm -f /var/zp/mirrors/.void.tmp /var/zp/mirrors/.kiss.tmp /var/zp/mirrors/.crux.tmp
        \\
        \\echo "zp: base ready -> $OUT  (packages: $(wc -l < "$OUT"))"
    ;

    const stat = try file.stat(io);

    try file.writePositionalAll(io, cmd, stat.size);
    try file.setPermissions(io, std.Io.File.Permissions.fromMode(0o755));

    const pkgs = try Dir.createFileAbsolute(io, "/var/zp/install/packages.db", .{});
    defer pkgs.close(io);

    std.debug.print("Done.\n", .{});
}

test "createDirectories creates nested init paths" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var path_buf: [256]u8 = undefined;
    const root = try std.fmt.bufPrint(&path_buf, ".zig-cache/tmp/{s}/var/zp", .{tmp.sub_path});

    try createDirectories(io, root);
    try createDirectories(io, root);

    var root_dir = try Dir.cwd().openDir(io, root, .{});
    defer root_dir.close(io);

    for ([_][]const u8{ "build", "install", "mirrors", "pkg" }) |path| {
        var child = try root_dir.openDir(io, path, .{});
        child.close(io);
    }
}
