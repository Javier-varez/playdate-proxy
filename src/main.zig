const std = @import("std");

const PdApi = @import("pd_api.zig").Api;
const Serial = @import("serial.zig");
const Alloc = @import("alloc.zig");
const AppState = @import("app_state.zig");

pub export fn event_handler(pd: *PdApi.PlaydateAPI, event: PdApi.PDSystemEvent, arg: u32) callconv(.C) c_int {
    _ = arg;

    switch (event) {
        PdApi.kEventInit => {
            const app_state = AppState.init(pd);

            pd.system.*.setUpdateCallback.?(update, app_state);

            Serial.configure(app_state) catch {
                app_state.panic("Unable to register serial callback", .{});
            };
        },
        else => {},
    }

    return 0;
}

fn update(_app_state: ?*anyopaque) callconv(.C) c_int {
    const app_state: *AppState = @alignCast(@ptrCast(_app_state.?));
    const pd: *const PdApi.PlaydateAPI = app_state.pd;

    pd.graphics.*.clear.?(PdApi.kColorWhite);
    pd.graphics.*.setFont.?(app_state.font);

    const LCD_ROWS: isize = @intCast(PdApi.LCD_ROWS);
    const LCD_COLUMNS: isize = @intCast(PdApi.LCD_COLUMNS);

    app_state.x += app_state.dx;
    app_state.y += app_state.dy;

    const str = "Hello world!";
    _ = pd.graphics.*.drawText.?(str, str.len, PdApi.kASCIIEncoding, @intCast(app_state.x), @intCast(app_state.y));

    if ((app_state.x < 0) or (app_state.x > LCD_COLUMNS - AppState.TEXT_WIDTH)) {
        app_state.dx = -app_state.dx;
    }

    if ((app_state.y < 0) or (app_state.y > LCD_ROWS - AppState.TEXT_HEIGHT)) {
        app_state.dy = -app_state.dy;
    }

    return 1;
}
