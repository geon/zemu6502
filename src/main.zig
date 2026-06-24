const std = @import("std");
const devices = @import("devices.zig");
const System = @import("system.zig");

const Allocator = std.mem.Allocator;

var gpa: std.heap.DebugAllocator(.{}) = .init;
pub const std_options: std.Options = .{
    // Set default log level to info.
    .log_level = .info,
};

fn createPeripherals(allocator: Allocator, system: *System) !void {
    const peripheral = try devices.createDevice(allocator);
    try system.data_bus.addPeripheral(.{
        .start = 0,
        .end = 0xffff,
        .peripheral = peripheral,
    });
}

/// Main entry point
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const clockFreq = 10;

    // Create system and add devices.
    var system = try System.init(allocator, clockFreq);
    defer system.deinit();
    std.log.info("Initialised system @ {d}Hz", .{clockFreq});
    try createPeripherals(allocator, &system);

    system.reset();

    while (true) {
        system.loop();
    }
}

test {
    // Work around because testing is ...
    std.testing.refAllDecls(@This());
}
