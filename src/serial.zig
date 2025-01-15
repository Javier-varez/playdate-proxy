const PdApi = @import("pd_api.zig").Api;
const AppState = @import("app_state.zig");

var app_state: ?*AppState = null;

pub fn configure(_app_state: *AppState) void {
    app_state = _app_state;
    app_state.?.pd.system.*.setSerialMessageCallback.?(@ptrCast(&serial_callback));
}

fn serial_callback(message: [*:0]const u8) callconv(.C) void {
    app_state.?.pd.system.*.logToConsole.?("Hello world: %s\n", message);
}
