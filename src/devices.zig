//! Hardware devices

const std = @import("std");
const Peripheral = @import("peripheral.zig");

pub const builtin = @import("devices/builtin.zig");

/// Create a peripheral device.
pub fn createDevice(allocator: std.mem.Allocator) !Peripheral {
    const peripheral = (try builtin.RAM.init(allocator, 0xffff)).peripheral();

    return peripheral;
}
