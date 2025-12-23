//! Decrement and Increment operations

const std = @import("std");
const MPU = @import("../mpu.zig").MPU;
const MicroOpError = @import("../mpu.zig").MicroOpError;

/// Decrement data
pub fn dec(mpu: *MPU) MicroOpError!void {
    mpu.data -%= 1;
    mpu.registers.sr.update_zero(mpu.data);
    mpu.registers.sr.update_negative(mpu.data);
}

test "dec increments by 1" {
    var mpu = try @import("_mocks.zig").mock_mpu(0x10, .{});
    defer mpu.data_bus.deinit();

    try dec(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0F, mpu.data);
}

test "dec increments handles zero" {
    var mpu = try @import("_mocks.zig").mock_mpu(0x1, .{});
    defer mpu.data_bus.deinit();

    try dec(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(true, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0, mpu.data);
}

test "dec increments handles roll-over" {
    var mpu = try @import("_mocks.zig").mock_mpu(0x0, .{});
    defer mpu.data_bus.deinit();

    try dec(&mpu);

    try std.testing.expectEqual(true, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0xFF, mpu.data);
}

/// Decrement x-index
pub fn dex(mpu: *MPU) MicroOpError!void {
    mpu.registers.xr -%= 1;
    mpu.registers.sr.update_zero(mpu.registers.xr);
    mpu.registers.sr.update_negative(mpu.registers.xr);
}

test "dex increments by 1" {
    var mpu = try @import("_mocks.zig").mock_mpu(0, .{ .xr = 0x10 });
    defer mpu.data_bus.deinit();

    try dex(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0F, mpu.registers.xr);
}

test "dex increments handles zero" {
    var mpu = try @import("_mocks.zig").mock_mpu(0, .{ .xr = 0x01 });
    defer mpu.data_bus.deinit();

    try dex(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(true, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0, mpu.registers.xr);
}

test "dex increments handles roll-over" {
    var mpu = try @import("_mocks.zig").mock_mpu(0, .{ .xr = 0x0 });
    defer mpu.data_bus.deinit();

    try dex(&mpu);

    try std.testing.expectEqual(true, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0xFF, mpu.registers.xr);
}

/// Decrement y-index
pub fn dey(mpu: *MPU) MicroOpError!void {
    mpu.registers.yr -%= 1;
    mpu.registers.sr.update_zero(mpu.registers.yr);
    mpu.registers.sr.update_negative(mpu.registers.yr);
}

test "dey increments by 1" {
    var mpu = try @import("_mocks.zig").mock_mpu(0, .{ .yr = 0x10 });
    defer mpu.data_bus.deinit();

    try dey(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0F, mpu.registers.yr);
}

test "dey increments handles zero" {
    var mpu = try @import("_mocks.zig").mock_mpu(0, .{ .yr = 0x01 });
    defer mpu.data_bus.deinit();

    try dey(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(true, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0, mpu.registers.yr);
}

test "dey increments handles roll-over" {
    var mpu = try @import("_mocks.zig").mock_mpu(0, .{ .yr = 0x0 });
    defer mpu.data_bus.deinit();

    try dey(&mpu);

    try std.testing.expectEqual(true, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0xFF, mpu.registers.yr);
}

/// Increment data
pub fn inc(mpu: *MPU) MicroOpError!void {
    mpu.data +%= 1;
    mpu.registers.sr.update_zero(mpu.data);
    mpu.registers.sr.update_negative(mpu.data);
}

test "inc increments by 1" {
    var mpu = try @import("_mocks.zig").mock_mpu(0x10, .{});
    defer mpu.data_bus.deinit();

    try inc(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x11, mpu.data);
}

test "inc increments handles roll-over" {
    var mpu = try @import("_mocks.zig").mock_mpu(0xFF, .{});
    defer mpu.data_bus.deinit();

    try inc(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(true, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0, mpu.data);
}

/// Increment x-index
pub fn inx(mpu: *MPU) MicroOpError!void {
    mpu.registers.xr +%= 1;
    mpu.registers.sr.update_negative(mpu.registers.xr);
    mpu.registers.sr.update_zero(mpu.registers.xr);
}

test "inx increments by 1" {
    var mpu = try @import("_mocks.zig").mock_mpu(
        0,
        .{
            .xr = 0x10,
        },
    );
    defer mpu.data_bus.deinit();

    try inx(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x11, mpu.registers.xr);
}

test "inx increments handles roll-over" {
    var mpu = try @import("_mocks.zig").mock_mpu(
        0,
        .{
            .xr = 0xFF,
        },
    );
    defer mpu.data_bus.deinit();

    try inx(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(true, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0, mpu.registers.xr);
}

/// Increment y-index
pub fn iny(mpu: *MPU) MicroOpError!void {
    mpu.registers.yr +%= 1;
    mpu.registers.sr.update_negative(mpu.registers.yr);
    mpu.registers.sr.update_zero(mpu.registers.yr);
}

test "iny increments by 1" {
    var mpu = try @import("_mocks.zig").mock_mpu(
        0,
        .{
            .yr = 0x10,
        },
    );
    defer mpu.data_bus.deinit();

    try iny(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(false, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x11, mpu.registers.yr);
}

test "iny increments handles roll-over" {
    var mpu = try @import("_mocks.zig").mock_mpu(
        0,
        .{
            .yr = 0xFF,
        },
    );
    defer mpu.data_bus.deinit();

    try iny(&mpu);

    try std.testing.expectEqual(false, mpu.registers.sr.negative);
    try std.testing.expectEqual(true, mpu.registers.sr.zero);
    try std.testing.expectEqual(0x0, mpu.registers.yr);
}
