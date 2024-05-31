//! GDB server for the 6502 emulator.
const std = @import("std");
const net = std.net;
const posix = std.posix;

const System = @import("system.zig");
const DebugPort = @import("6502/mpu.zig").DebugPort;
const MPU = @import("6502/mpu.zig").MPU;
const BufferError = @import("gdb/packet.zig").BufferError;
const PacketBuffer = @import("gdb/packet.zig").PacketBuffer;
const Packet = @import("gdb/packet.zig").Packet;
const utils = @import("gdb/utils.zig");

const Self = @This();

// Listener and single connection.
server: net.Server,
connection: ?net.Server.Connection = null,

// Buffers
in: PacketBuffer,
out: PacketBuffer,

// Debug state
step_count: i16 = -1,
break_points: std.BoundedArray(u16, 32),
last_addr: u16 = 0,

/// Initialise server and start listening for connections
pub fn init(address: net.Address) !Self {
    std.log.info("Waiting for GDB connection on {}...", .{address});

    return .{
        .server = try address.listen(.{
            .kernel_backlog = 1, // Only allow a single connection at a time.
            .reuse_address = true,
        }),
        .in = PacketBuffer.init(),
        .out = PacketBuffer.init(),
        .break_points = try std.BoundedArray(u16, 32).init(0),
    };
}

pub fn deinit(self: *Self) void {
    std.log.info("Shutting down GDB server...", .{});

    if (self.connection) |connection| connection.stream.close();
    self.server.deinit();
}

/// Get debug point interface.
pub fn debugPort(self: *Self) DebugPort {
    return .{
        .ptr = self,
        .vtable = &.{
            .pre_decode = preDecode,
            // .post_decode = postDecode,
        },
    };
}

/// Event before decoding
fn preDecode(ctx: *anyopaque, mpu: *const MPU) bool {
    const self: *Self = @ptrCast(@alignCast(ctx));

    // Halted
    if (self.step_count == 0) {
        return false;
    }

    // Check break points
    if (self.break_points.len > 0) {
        // Ignore the last stop address to allow for stepping.
        if ((self.last_addr != mpu.registers.pc) and (self.isBreakPoint(mpu.registers.pc))) {
            self.step_count = 0;
            self.last_addr = mpu.registers.pc;
            std.log.info("[GDB] Breakpoint @ {X:0>4}", .{mpu.registers.pc});
        }
    }

    if (self.step_count > 0) {
        self.step_count -= 1;
        if (self.step_count == 0) {
            self.last_addr = mpu.registers.pc;
            std.log.info("[GDB] Halted @ {X:0>4}", .{mpu.registers.pc});
        }
    }

    return self.step_count != 0;
}

/// Process a Query (q) packet
fn processQuery(self: *Self, system: *System, packet: Packet) !void {
    if (packet.startsWith("qPeripherals")) {
        const start = try self.start_packet();
        for (system.data_bus.peripherals.items) |item| {
            try self.out.append(item.peripheral.vtable.name);
            try self.out.append(":");
            try self.out.append(&utils.hexDigits(@truncate(item.start >> 8)));
            try self.out.append(&utils.hexDigits(@truncate(item.start)));
            try self.out.append(":");
            try self.out.append(&utils.hexDigits(@truncate(item.end >> 8)));
            try self.out.append(&utils.hexDigits(@truncate(item.end)));
            try self.out.append(";");
        }
        self.out.len -= 1; // Remove last final separator.
        try self.end_packet(start);
    } else {
        // std.log.debug("Unknown query: {s}", .{packet.data});
        try self.write_packet("");
    }
}

/// Check if address is a breakpoint
fn isBreakPoint(self: Self, addr: u16) bool {
    for (self.break_points.slice()) |break_point| {
        if (break_point == addr) {
            return true;
        }
    }
    return false;
}

fn setBreakPoint(self: *Self, addr: u16) bool {
    if (!self.isBreakPoint(addr)) {
        self.break_points.append(addr) catch {
            return false;
        };
    }
    return true;
}

// fn clearBreakPoint(self: *Self, addr: u16) void {
// }

fn processPacket(self: *Self, system: *System) !void {
    // Return if there is an incomplete packet
    const start = self.in.indexOf('$') catch return;
    const end = self.in.indexOf('#') catch return;
    const packet_end = end + 3; // End + checksum
    if (self.in.len < packet_end) return;

    const packet = try self.in.packet(start + 1, end);
    const checksum = packet.checksum();
    const expectedSum = try std.fmt.parseUnsigned(u8, self.in.data[(end + 1)..(end + 3)], 16);

    // Packet good?
    if (checksum != expectedSum) {
        try self.write_packet("E01");
        return;
    }
    try self.out.append("+");

    std.log.debug("[GDB] > {s}", .{packet.data});
    switch (packet.data[0]) {
        '?' => {
            // Halt reason
            if (self.step_count == 0) {
                try self.write_packet("S11");
            } else {
                try self.write_packet("S13");
            }
        },
        'g' => {
            // Read registers
            const packet_start = try self.start_packet();
            try self.out.appendByte(system.mpu.registers.ac);
            try self.out.appendByte(system.mpu.registers.xr);
            try self.out.appendByte(system.mpu.registers.yr);
            try self.out.appendByte(system.mpu.registers.sp);
            try self.out.appendWord(system.mpu.registers.pc);
            try self.out.appendByte(@bitCast(system.mpu.registers.sr));
            try self.end_packet(packet_start);
        },
        'G' => {
            // Write registers
            // TODO: Write registers!
        },
        'm' => {
            // Read memory
            if (packet.data.len >= 10) {
                const addr = try packet.hexWordAt(1);
                var length = try packet.hexWordAt(6);

                // Calculate length with overflow check.
                const addr_end = std.math.add(u16, addr, length) catch std.math.maxInt(u16);
                length = (addr_end - addr) + 1; // Addresses are inclusive

                const packet_start = try self.start_packet();
                for (0..length) |idx| {
                    const offset: u16 = @truncate(idx);
                    try self.out.appendByte(system.data_bus.read(addr + offset));
                }
                try self.end_packet(packet_start);
            } else {
                std.log.warn("[GDB] Bad packet: {s}", .{packet.data});
                try self.write_packet("E02");
            }
        },
        'M' => {
            // Write memory
            if (packet.data.len >= 10) {
                var addr = try packet.hexWordAt(1);
                var length = try packet.hexWordAt(6);

                // Calculate length with overflow check.
                const addr_end = std.math.add(u16, addr, length) catch std.math.maxInt(u16);
                length = addr_end - addr;

                for (0..length) |idx| {
                    system.data_bus.write(addr, try packet.hexByteAt(11 + (idx * 2)));
                    addr += 1;
                }

                try self.write_packet("OK");
            } else {
                std.log.warn("[GDB] Bad packet: {s}", .{packet.data});
                try self.write_packet("E03");
            }
        },
        'c' => {
            // Continue
            self.step_count = -1;
            try self.write_packet("S13"); // 0x13 (19)
        },
        's' => {
            // Step (and report PC location)
            self.step_count = 2;
            const packet_start = try self.start_packet();
            try self.out.append("T1104:");
            try self.out.appendWord(system.mpu.current_loc);
            try self.end_packet(packet_start);
        },
        't' => {
            // Stop the processor
            self.step_count = 0;
            const packet_start = try self.start_packet();
            try self.out.append("T1104:");
            try self.out.appendWord(system.mpu.current_loc);
            try self.end_packet(packet_start);
        },
        'r', 'R' => system.reset(),
        'q' => try self.processQuery(system, packet),
        'j' => {
            // Jump/Run from a particular PC address.
            if (packet.data.len != 8) {
                const addr = try packet.hexWordAt(1);
                system.mpu.registers.pc = addr;
                try self.write_packet("OK");
            } else {
                std.log.warn("[GDB] Bad packet: {s}", .{packet.data});
                try self.write_packet("E03");
            }
        },
        'B' => {
            // Set/Clear breakpoint
            if (packet.data.len == 7) {
                const addr = try packet.hexWordAt(1);
                const mode = packet.data[6];
                switch (mode) {
                    's' => {
                        // Set
                        if (self.setBreakPoint(addr)) {
                            std.log.info("[GDB] Set Breakpoint @ {X:0>4}", .{addr});
                            try self.write_packet("OK");
                        } else {
                            try self.write_packet("E06");
                        }
                    },
                    'c' => {
                        // Clear
                        std.log.info("[GDB] Clear Breakpoint @ {X:0>4}", .{addr});
                        try self.write_packet("OK");
                    },
                    else => {
                        std.log.warn("[GDB] Invalid mode: {c}", .{mode});
                        try self.write_packet("E05");
                    },
                }
            } else {
                std.log.warn("[GDB] Bad packet: {s}", .{packet.data});
                try self.write_packet("E04");
            }
        },
        else => {
            std.log.info("[GDB] Unknown packet: {s}", .{packet.data});
            try self.write_packet("");
        },
    }

    self.in.removeHead(packet_end);
}

fn start_packet(self: *Self) !usize {
    try self.out.append("$");
    return self.out.len;
}

fn end_packet(self: *Self, start: usize) !void {
    const checksum = utils.modulo256Sum(self.out.data[start..self.out.len]);
    try self.out.append("#");
    try self.out.append(&utils.hexDigits(checksum));
}

fn write_packet(self: *Self, data: []const u8) !void {
    const start = try self.start_packet();
    try self.out.append(data);
    try self.end_packet(start);
}

/// Check for an incoming connection.
pub fn checkConnection(self: *Self) !void {
    var fds: [1]posix.pollfd = .{.{
        .fd = self.server.stream.handle,
        .events = posix.POLL.IN,
        .revents = undefined,
    }};
    const result = try posix.poll(&fds, 0);
    if (result >= 0 and fds[0].revents > 0) {
        const connection = try self.server.accept();
        std.log.info("[GDB] Connection from {}", .{connection.address});
        self.connection = connection;
    }
}

/// Check for incoming data and process response.
pub fn pollData(self: *Self, connection: net.Server.Connection, system: *System) !void {
    var fds: [1]posix.pollfd = .{.{
        .fd = connection.stream.handle,
        .events = posix.POLL.IN,
        .revents = undefined,
    }};
    const result = try posix.poll(&fds, 0);
    if (result >= 0 and fds[0].revents > 0) {
        var read_buffer: [4096]u8 = [_]u8{0} ** 4096;
        const read = try connection.stream.read(&read_buffer);
        if (read == 0) {
            // Connection closed
            std.log.info("[GDB] Connection closed.", .{});
            self.connection = null;
        } else {
            try self.in.append(read_buffer[0..read]);
            self.processPacket(system) catch |err| switch (err) {
                BufferError.CharNotFound, BufferError.InvalidCharacter => {
                    std.log.warn("[GDB] Invalid packet", .{});
                    try self.write_packet("E04");
                },
                BufferError.Overflow => {
                    std.log.err("[GDB] Unable to process packet", .{});
                    try self.write_packet("E05");
                },
                else => return err,
            };

            // Write out anything in the output buffer.
            if (self.out.len > 0) {
                try connection.stream.writeAll(&self.out.data);
                std.log.debug("[GDB] < {s}", .{self.out.asSlice()});
                self.out.clear();
            }
        }
    }
}

/// Loop handler, poll for any events and respond if required.
pub fn loop(self: *Self, system: *System) !void {
    if (self.connection) |connection| {
        try self.pollData(connection, system);
    } else {
        try self.checkConnection();
    }
}
