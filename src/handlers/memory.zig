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

fn handler(app_state: *AppState, args: []const []const u8) void {
    if (args.len < 2) {
        app_state.print("Err: Expected at least [address] and [length] arguments", .{});
        return;
    }

    const address = base64Decode(u32, args[0]) catch {
        app_state.print("Err: Unable to decode address", .{});
        return;
    };
    const length = base64Decode(u32, args[1]) catch {
        app_state.print("Err: Unable to decode length", .{});
        return;
    };

    var result = std.ArrayList(u8).init(app_state.allocator.allocator());
    defer result.deinit();

    const encoded_length = std.base64.standard.Encoder.calcSize(length);
    const src_ptr: [*]const u8 = @ptrFromInt(address);
    result.resize(encoded_length) catch {
        app_state.print("Err: Unable to resize array", .{});
        return;
    };
    _ = std.base64.standard.Encoder.encode(result.items, src_ptr[0..length]);

    app_state.print("{s}", .{result.items});
}

pub fn register() !void {
    try Serial.register_command("memdump", handler);
}
