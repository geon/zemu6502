//! Memory read/write operations

const std = @import("std");
const MPU = @import("../mpu.zig").MPU;
const MicroOpError = @import("../mpu.zig").MicroOpError;

/// Write value in accumulator to address in _addr
pub fn ac_write_to_addr(mpu: *MPU) MicroOpError!void {
    mpu.data = mpu.registers.ac;
    mpu.write(mpu.addr);
}

/// Read data at addr into accumulator
pub fn ac_read_from_addr(mpu: *MPU) MicroOpError!void {
    mpu.read(mpu.addr);
    mpu.registers.ac = mpu.data;
    mpu.registers.sr.update_negative(mpu.data);
    mpu.registers.sr.update_zero(mpu.data);
}

/// Read data at pc into accumulator
pub fn ac_read_from_pc(mpu: *MPU) MicroOpError!void {
    mpu.read_pc();
    mpu.registers.ac = mpu.data;
    mpu.registers.sr.update_negative(mpu.data);
    mpu.registers.sr.update_zero(mpu.data);
}

/// Write value in x-register to address in addr
pub fn xr_write_to_addr(mpu: *MPU) MicroOpError!void {
    mpu.data = mpu.registers.xr;
    mpu.write(mpu.addr);
}

/// Read data at addr into x-register
pub fn xr_read_from_addr(mpu: *MPU) MicroOpError!void {
    mpu.read(mpu.addr);
    mpu.registers.xr = mpu.data;
    mpu.registers.sr.update_negative(mpu.data);
    mpu.registers.sr.update_zero(mpu.data);
}

/// Read data at pc into x-register
pub fn xr_read_from_pc(mpu: *MPU) MicroOpError!void {
    mpu.read_pc();
    mpu.registers.xr = mpu.data;
    mpu.registers.sr.update_negative(mpu.data);
    mpu.registers.sr.update_zero(mpu.data);
}

/// Write value in y-register to address in addr
pub fn yr_write_to_addr(mpu: *MPU) MicroOpError!void {
    mpu.data = mpu.registers.yr;
    mpu.write(mpu.addr);
}

/// Read data at addr into yr
pub fn yr_read_from_addr(mpu: *MPU) MicroOpError!void {
    mpu.read(mpu.addr);
    mpu.registers.yr = mpu.data;
    mpu.registers.sr.update_negative(mpu.data);
    mpu.registers.sr.update_zero(mpu.data);
}

/// Read data at pc into y-register
pub fn yr_read_from_pc(mpu: *MPU) MicroOpError!void {
    mpu.read_pc();
    mpu.registers.yr = mpu.data;
    mpu.registers.sr.update_negative(mpu.data);
    mpu.registers.sr.update_zero(mpu.data);
}

/// Read data at pc into addr
pub fn addr_l_read_from_pc(mpu: *MPU) MicroOpError!void {
    mpu.read_pc();
    mpu.addr = mpu.data;
}

/// Read data at pc into addr high
pub fn addr_h_read_from_pc(mpu: *MPU) MicroOpError!void {
    mpu.read_pc();
    mpu.addr += @as(u16, mpu.data) << 8;
}

/// Read data at pc into addr high and index using x-register
pub fn addr_h_read_from_pc_add_xr(mpu: *MPU) MicroOpError!void {
    try addr_h_read_from_pc(mpu);
    mpu.addr += mpu.registers.xr;
}

/// Read data at pc into addr high and index using y-register
pub fn addr_h_read_from_pc_add_yr(mpu: *MPU) MicroOpError!void {
    try addr_h_read_from_pc(mpu);
    mpu.addr += mpu.registers.yr;
}

/// Address indirect h
pub fn addr_h_read_from_addr_indirect(mpu: *MPU) MicroOpError!void {
    const addr = mpu.addr + 1;
    mpu.addr = mpu.data;

    mpu.read(addr);
    mpu.addr += @as(u16, mpu.data) << 8;
}

/// Write data to addr
pub fn data_write_to_addr(mpu: *MPU) MicroOpError!void {
    mpu.write(mpu.addr);
}

/// Read data at pc into addr
pub fn data_read_from_addr(mpu: *MPU) MicroOpError!void {
    mpu.read(mpu.addr);
}
