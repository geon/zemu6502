//! Definition of a basic hardware system.

const std = @import("std");
const Clock = @import("clock.zig");
const DataBus = @import("data-bus.zig");
const MPU = @import("6502.zig").MPU;
const builtin = @import("devices/builtin.zig");

const Self = @This();

allocator: std.mem.Allocator,
data_bus: *DataBus,
mpu: *MPU,
clock: Clock,

/// Initialise system.
pub fn init(allocator: std.mem.Allocator, freq_hz: u64, prgPath: []const u8) !Self {
    const data_bus = try allocator.create(DataBus);
    errdefer allocator.destroy(data_bus);
    data_bus.* = DataBus.init(allocator);

    const mpu = try allocator.create(MPU);
    errdefer allocator.destroy(mpu);
    mpu.* = MPU.init(data_bus);

    const system: Self = .{
        .allocator = allocator,
        .data_bus = data_bus,
        .mpu = mpu,
        .clock = try Clock.init(freq_hz, mpu),
    };

    const peripheral = (try builtin.RAM.init(allocator, 0xffff)).peripheral();
    try system.data_bus.addPeripheral(.{
        .start = 0,
        .end = 0xffff,
        .peripheral = peripheral,
    });
    try loadPrg(allocator, system.data_bus, prgPath);

    return system;
}

fn loadPrg(allocator: std.mem.Allocator, bus: *DataBus, prgPath: []const u8) !void {
    const MAX_IMAGE_SIZE: usize = 0x10000;

    const cwd = std.fs.cwd();
    if (cwd.openFile(prgPath, .{})) |file| {
        const buffer = try file.readToEndAlloc(allocator, MAX_IMAGE_SIZE);
        defer allocator.free(buffer);

        const address = std.mem.readInt(u16, buffer[0..2], .little);

        std.log.info(
            "Loading prg {s} at 0x{x:0>4}",
            .{ prgPath, address },
        );
        var index: u16 = 0;
        for (buffer[2..]) |data| {
            bus.write(address + index, data);
            index += 1;
        }

        // Set the reset vector to the start of the loaded prg content.
        bus.write(0xfffc, @truncate(address));
        bus.write(0xfffd, @truncate(address >> 8));
    } else |err| {
        return err;
    }
}

/// Clean up MCU instance.
pub fn deinit(self: *Self) void {
    self.allocator.destroy(self.mpu);
    self.data_bus.deinit();
    self.allocator.destroy(self.data_bus);
}

/// Reset the system to a known state.
pub fn reset(self: *Self) void {
    self.mpu.reset();
    self.data_bus.reset();
    self.clock.start();
}

/// Run loop
pub fn loop(self: *Self) void {
    self.clock.loop();
    self.data_bus.loop();
}
