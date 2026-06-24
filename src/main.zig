const std = @import("std");
const System = @import("system.zig");

const Allocator = std.mem.Allocator;

var gpa: std.heap.DebugAllocator(.{}) = .init;
pub const std_options: std.Options = .{
    // Set default log level to info.
    .log_level = .info,
};

/// Main entry point
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const clockFreq = 10;

    var system = try System.init(allocator, clockFreq);
    defer system.deinit();
    std.log.info("Initialised system @ {d}Hz", .{clockFreq});

    system.reset();

    while (true) {
        system.loop();
    }
}

test {
    // Work around because testing is ...
    std.testing.refAllDecls(@This());
}
