const std = @import("std");

const AppState = @import("../app_state.zig");
const Serial = @import("../serial.zig");

const DecodeError = error{
    length_mismatch,
};

fn base64Decode(T: type, src: []const u8) !T {
    if (src.len != std.base64.standard.Encoder.calcSize(@sizeOf(T))) {
        return DecodeError.length_mismatch;
    }
    var dest: [@sizeOf(T)]u8 = undefined;
    _ = try std.base64.standard.Decoder.decode(&dest, src);
    return @bitCast(dest);
}

fn new_read_handler(T: type) Serial.Handler {
    const S = struct {
        fn handler(app_state: *AppState, args: []const []const u8) void {
            if (args.len < 1) {
                app_state.print("Err: Expected at least [address] to read as an argument", .{});
                return;
            }

            const address = base64Decode(u32, args[0]) catch {
                app_state.print("Err: Unable to decode address", .{});
                return;
            };

            const src_ptr: *const volatile T = @ptrFromInt(address);
            const result = src_ptr.*;

            const result_buf: [@sizeOf(T)]u8 = @bitCast(result);
            var encoded_result: [std.base64.standard.Encoder.calcSize(@sizeOf(T))]u8 = undefined;
            _ = std.base64.standard.Encoder.encode(&encoded_result, result_buf[0..@sizeOf(T)]);

            app_state.print("{s}", .{encoded_result});
        }
    };
    return S.handler;
}

fn new_write_handler(T: type) Serial.Handler {
    const S = struct {
        fn handler(app_state: *AppState, args: []const []const u8) void {
            if (args.len < 1) {
                app_state.print("Err: Expected at least [address] to read as an argument", .{});
                return;
            }

            const address = base64Decode(u32, args[0]) catch {
                app_state.print("Err: Unable to decode address", .{});
                return;
            };

            const value = base64Decode(T, args[1]) catch {
                app_state.print("Err: Unable to decode value", .{});
                return;
            };

            const src_ptr: *volatile T = @ptrFromInt(address);
            src_ptr.* = value;

            app_state.print("Ok: wrote value {} to {}", .{ value, src_ptr });
        }
    };
    return S.handler;
}

pub fn register() !void {
    try Serial.register_command("w8", new_write_handler(u8));
    try Serial.register_command("w16", new_write_handler(u16));
    try Serial.register_command("w32", new_write_handler(u32));
    try Serial.register_command("r8", new_read_handler(u8));
    try Serial.register_command("r16", new_read_handler(u16));
    try Serial.register_command("r32", new_read_handler(u32));
}
