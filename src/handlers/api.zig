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

fn handler(app_state: *AppState, args: [][]const u8) void {
    const pd = app_state.pd;

    if (resolveApi(pd, args)) |ptr| {
        pd.system.*.logToConsole.?("Ptr is %p", ptr);
        return;
    }

    pd.system.*.logToConsole.?("Unknown method");
}

pub fn register() !void {
    try Serial.register_command("api", handler);
}

test "resolveApi" {
    const Apis = struct {
        fn format_str(a: [*c][*c]u8, b: [*c]const u8, ...) callconv(.C) c_int {
            _ = a;
            _ = b;
            return 0;
        }
    };

    const system = PdApi.playdate_sys{
        .formatString = Apis.format_str,
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
}
