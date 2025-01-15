const std = @import("std");

const PdApi = @import("pd_api.zig").Api;
const Serial = @import("serial.zig");
const Alloc = @import("alloc.zig");
const AppState = @import("app_state.zig");

const TEXT_WIDTH: isize = 86;
const TEXT_HEIGHT: isize = 16;

pub export fn event_handler(pd: *PdApi.PlaydateAPI, event: PdApi.PDSystemEvent, arg: u32) callconv(.C) c_int {
    _ = arg;

    switch (event) {
        PdApi.kEventInit => {
            const fontpath: [*:0]const u8 = "/System/Fonts/Asheville-Sans-14-Bold.pft";

            var pd_alloc = Alloc.PdAllocator.create(pd);
            var app_state = pd_alloc.allocator().create(AppState) catch {
                pd.system.*.@"error".?("Unable to allocate any memory\n");
                return 1;
            };

            app_state.allocator = pd_alloc;
            app_state.pd = pd;
            app_state.x = (400 - TEXT_WIDTH) / 2;
            app_state.y = (240 - TEXT_HEIGHT) / 2;
            app_state.dx = 1;
            app_state.dy = 2;

            var err: ?[*:0]const u8 = null;
            const font = pd.graphics.*.loadFont.?(fontpath, &err);

            if (font == null) {
                pd.system.*.@"error".?("Couldn't load font %s: %s", fontpath, err);
            }

            app_state.font = font.?;

            pd.system.*.setUpdateCallback.?(update, app_state);
            Serial.configure(app_state);
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

    if ((app_state.x < 0) or (app_state.x > LCD_COLUMNS - TEXT_WIDTH)) {
        app_state.dx = -app_state.dx;
    }

    if ((app_state.y < 0) or (app_state.y > LCD_ROWS - TEXT_HEIGHT)) {
        app_state.dy = -app_state.dy;
    }

    return 1;
}
