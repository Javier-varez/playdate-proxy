const std = @import("std");

const PdApi = @import("../pd_api.zig").Api;
const AppState = @import("../app_state.zig");
const Serial = @import("../serial.zig");

fn resolveApi(value: anytype, path: []const []const u8) ?*const anyopaque {
    switch (@typeInfo(@TypeOf(value))) {
        .Pointer => |p| {
            switch (@typeInfo(p.child)) {
                .Fn => {
                    if (path.len == 0) {
                        return value;
                    }
                    return null;
                },
                else => {
                    return resolveApi(value.*, path);
                },
            }
        },
        .Optional => {
            return resolveApi(value.?, path);
        },
        .Struct => |s| {
            if (path.len == 0) {
                return null;
            }

            inline for (s.fields) |field| {
                if (std.mem.eql(u8, field.name, path[0])) {
                    const inner = @field(value, field.name);
                    return resolveApi(inner, path[1..]);
                }
            }
            return null;
        },
        .Fn => {
            return value;
        },
        else => |typeinfo| {
            @compileError(std.fmt.comptimePrint("Unhandled unwrapped API type: {}", .{typeinfo}));
        },
    }
}

fn readData(app_state: *AppState, _ptr: *const anyopaque, length: usize) !std.ArrayList(u8) {
    var encoded_binary_blob = std.ArrayList(u8).init(app_state.allocator.allocator());
    errdefer encoded_binary_blob.deinit();

    const encoded_size = std.base64.standard.Encoder.calcSize(length);
    try encoded_binary_blob.resize(encoded_size);

    const ptr: [*]const u8 = @ptrCast(_ptr);
    _ = std.base64.standard.Encoder.encode(encoded_binary_blob.items, ptr[0..length]);

    return encoded_binary_blob;
}

fn handler(app_state: *AppState, args: []const []const u8) void {
    if (args.len < 1) {
        app_state.print("Err: Missing arguments to API handler", .{});
        return;
    }

    const encoded_len_size = comptime std.base64.standard.Encoder.calcSize(@sizeOf(u32));
    if (args[0].len != encoded_len_size) {
        app_state.print("Err: Unexpected length argument size. Got {}, Expected {}", .{ args[0].len, encoded_len_size });
        return;
    }

    var decoded_length: [@sizeOf(u32)]u8 = undefined;
    _ = std.base64.standard.Decoder.decode(&decoded_length, args[0]) catch {
        app_state.print("Err: Unable to decode length argument", .{});
        return;
    };
    const length: u32 = @bitCast(decoded_length);

    const ptr = resolveApi(app_state.pd, args[1..]);
    if (ptr == null) {
        app_state.print("Err: Unknown API method {s}", .{args});
        return;
    }

    const encoded_ptr_size = comptime std.base64.standard.Encoder.calcSize(@sizeOf(*const anyopaque));
    const src_ptr_data: [@sizeOf(*const anyopaque)]u8 = @bitCast(@intFromPtr(ptr.?));
    var encoded_ptr_data: [encoded_ptr_size]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&encoded_ptr_data, &src_ptr_data);

    const MASK: usize = 0xFFFFFFFE;
    const encoded_binary_blob = readData(app_state, @ptrFromInt(@intFromPtr(ptr.?) & MASK), length) catch {
        app_state.print("Err: failed to read data at address {s}", .{encoded_ptr_data});
        return;
    };
    defer encoded_binary_blob.deinit();

    app_state.print("{s} {s}", .{ encoded_ptr_data, encoded_binary_blob.items });
}

pub fn register() !void {
    try Serial.register_command("api", handler);
}

test "resolveApi" {
    const Apis = struct {
        fn formatStr(a: [*c][*c]u8, b: [*c]const u8, ...) callconv(.C) c_int {
            _ = a;
            _ = b;
            return 0;
        }
    };

    const system = PdApi.playdate_sys{
        .formatString = Apis.formatStr,
    };

    const api = PdApi.PlaydateAPI{
        .system = &system,
    };

    {
        const ptr: *const anyopaque = resolveApi(&api, &.{ "system", "formatString" }).?;
        const expected_ptr: *const anyopaque = @ptrCast(api.system.*.formatString.?);
        try std.testing.expectEqual(ptr, expected_ptr);
    }

    {
        const ptr: ?*const anyopaque = resolveApi(&api, &.{ "system", "formatStrings" });
        try std.testing.expectEqual(ptr, null);
    }

    {
        const ptr: ?*const anyopaque = resolveApi(&api, &.{ "system", "formatString", "more" });
        try std.testing.expectEqual(ptr, null);
    }

    {
        const ptr: ?*const anyopaque = resolveApi(&api, &.{"system"});
        try std.testing.expectEqual(ptr, null);
    }

    {
        const ptr: ?*const anyopaque = resolveApi(&api, &.{});
        try std.testing.expectEqual(ptr, null);
    }
}
