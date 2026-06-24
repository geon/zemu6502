const std = @import("std");
const config = @import("config.zig");
const devices = @import("devices.zig");
const System = @import("system.zig");

const Allocator = std.mem.Allocator;

var gpa: std.heap.DebugAllocator(.{}) = .init;
pub const std_options: std.Options = .{
    // Set default log level to info.
    .log_level = .info,
};

/// Stupidly simple command line arguments
const Args = struct {
    config_file: []const u8,
};

fn processArgs(allocator: Allocator) !Args {
    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        var stderr_buffer: [1024]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        const stderr = &stderr_writer.interface;

        try stderr.print(
            "Missing config file argument.\n{s} CONFIG_FILE",
            .{args[0]},
        );
        return error.Unimplemented;
    }

    return .{ .config_file = args[1] };
}

fn createPeripherals(allocator: Allocator, system_dir: std.fs.Dir, system: *System, system_config: config.SystemConfig) !void {
    for (system_config.dataBus) |bus_address_config| {
        const peripheral = try devices.createDevice(allocator, system_dir, &bus_address_config, &system_config);
        try system.data_bus.addPeripheral(.{
            .start = bus_address_config.start,
            .end = bus_address_config.end,
            .peripheral = peripheral,
        });
        std.log.info(
            "Added {s} to bus at @{X:0^4}-{X:0^4}",
            .{ peripheral.vtable.name, bus_address_config.start, bus_address_config.end },
        );
    }
}

/// Clone of the method from std library to return a sentenal
pub fn realpathAlloc(self: std.fs.Dir, allocator: Allocator, pathname: []const u8) ![:0]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    return allocator.dupeZ(u8, try self.realpath(pathname, buf[0..]));
}

/// Main entry point
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse command line and load system config
    const args = processArgs(allocator) catch |err| switch (err) {
        error.Unimplemented => return,
        else => return err,
    };
    const config_path = std.fs.realpathAlloc(allocator, args.config_file) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.err("Config file not found: {s}", .{args.config_file});
            return;
        },
        else => return err,
    };
    defer allocator.free(config_path);

    // Resolve system working dir (relative to config file)
    var system_dir: std.fs.Dir = undefined;
    if (std.fs.path.dirname(config_path)) |path| {
        system_dir = try std.fs.openDirAbsolute(path, .{});
    } else {
        system_dir = std.fs.cwd();
    }

    const system_config = try config.from_file(allocator, config_path);

    // Create system and add devices defined in config.
    var system = try System.init(allocator, system_config.clockFreq);
    defer system.deinit();
    std.log.info("Initialised system @ {d}Hz", .{system_config.clockFreq});
    try createPeripherals(allocator, system_dir, &system, system_config);

    system.reset();

    while (true) {
        system.loop();
    }
}

test {
    // Work around because testing is ...
    std.testing.refAllDecls(@This());
}
