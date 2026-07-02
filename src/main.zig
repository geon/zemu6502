const std = @import("std");
const System = @import("system.zig");
const ops = @import("6502/instructions.zig");

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

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        return error.Unimplemented;
    }
    const prgPath = args[1];

    var system = try System.init(allocator, 1, prgPath);
    defer system.deinit();

    system.reset();
    // Will be stepping it manually.
    system.clock.stop();

    // 0x0 is BRK, unless the mpu was just reset.
    while (!(system.mpu.data == 0x0 and system.mpu.addr != 0)) {
        system.clock.step();
    }

    for (0..10) |address| {
        const data = system.data_bus.read(@intCast(address));

        std.log.info(
            "> 0x{x:0>4}: 0x{x:0>2}",
            .{ address, data },
        );
    }
}

test {
    // Work around because testing is ...
    std.testing.refAllDecls(@This());
}
