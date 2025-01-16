const std = @import("std");

const PdApi = @import("pd_api.zig").Api;
const AppState = @import("app_state.zig");
const Handlers = @import("handlers.zig");

const Handler = *const fn (app_state: *AppState, args: [][]const u8) void;

const Command = struct {
    name: []const u8,
    handler: Handler,
};

const SerialState = struct {
    app_state: *AppState,
    commands: std.ArrayList(Command),
};

var serial_state: ?SerialState = null;

pub fn configure(app_state: *AppState) !void {
    serial_state = SerialState{
        .app_state = app_state,
        .commands = std.ArrayList(Command).init(app_state.allocator.allocator()),
    };
    app_state.pd.system.*.setSerialMessageCallback.?(@ptrCast(&serial_callback));
    try Handlers.register_handlers();
}

fn serial_callback(message: [*:0]const u8) callconv(.C) void {
    const app_state = serial_state.?.app_state;

    var args = std.ArrayList([]const u8).init(app_state.allocator.allocator());
    defer args.deinit();

    const message_slice = std.mem.span(message);
    var iter = std.mem.splitScalar(u8, message_slice, ' ');
    while (iter.next()) |v| {
        if (v.len == 0) continue;

        args.append(v) catch {
            app_state.print("Out of memory while collecting args for command", .{});
            return;
        };
    }

    if (args.items.len == 0) {
        app_state.print("Please, specify a command to handle", .{});
        return;
    }

    const cmd = args.items[0];
    const other_args = args.items[1..];

    for (serial_state.?.commands.items) |c| {
        if (std.mem.eql(u8, cmd, c.name)) {
            c.handler(app_state, other_args);
            return;
        }
    }

    app_state.print("Unknown command {s}", .{cmd});
}

pub fn register_command(command: []const u8, handler: Handler) !void {
    if (serial_state) |*state| {
        try state.commands.append(Command{
            .name = command,
            .handler = handler,
        });
    }
}
