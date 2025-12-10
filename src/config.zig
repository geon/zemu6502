//! System configuration.
const std = @import("std");
const Yaml = @import("yaml").Yaml;

/// Individual device configuration.
pub const DeviceConfig = struct {
    type: []const u8,
    load: ?[]const u8,
};

/// Bus address configration and accociated peripheral device.
pub const BusAddressConfig = struct {
    start: u16,
    end: u16,
    peripheral: DeviceConfig,
};

/// Top-level system config.
pub const SystemConfig = struct {
    clockFreq: u64,
    dataBus: []BusAddressConfig,
};

/// Load configuration from a file.
pub fn from_file(allocator: std.mem.Allocator, path: []const u8) !SystemConfig {
    const file = try std.fs.cwd().readFileAlloc(allocator, path, 1_000_000);
    defer allocator.free(file);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var yaml: Yaml = .{ .source = file };
    try yaml.load(arena_allocator);

    return try yaml.parse(arena_allocator, SystemConfig);
}
