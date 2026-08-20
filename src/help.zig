const std = @import("std");

pub fn help() void {
    std.debug.print(
        \\zp - A minimal, source-based package manager
        \\
        \\Usage: zp [OPTIONS] [PACKAGE...]
        \\
        \\Options:
        \\  --init        Initialize /var/zp and generate gen.sh
        \\  -u            Update recipe trees and regenerate the database
        \\  -s <pkg>      Search for a package in the database
        \\  -i <pkg>      Download, build, and install a package from source
        \\  -r <pkg>      Remove an installed package
        \\  -h, --help    Show this help message and exit
        \\  -v, --version Show version information and exit
        \\  -U, --upgrade Upgrade system packages
        \\  
        \\
        \\Examples:
        \\  sudo zp --init              # Initialize the package manager
        \\  sudo zp -u                  # Sync recipe trees (Void + Crux + KISS)
        \\  sudo zp -s htop             # Search for htop
        \\  sudo zp -i htop             # Build & install htop from source
        \\  sudo zp -r htop             # Remove htop
        \\  sudo zp -U htop             # Upgrade htop on new version
        \\  sudo zp -U                  # Upgrade your system
        \\
        \\For more information, visit: https://github.com/nevvixsz/zp
    , .{});
    std.debug.print("\n", .{});
}
