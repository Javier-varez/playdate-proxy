const std = @import("std");

const PdApi = @cImport({
    @cDefine("TARGET_EXTENSION", "1");
    @cInclude("pd_api.h");
});

pub export fn eventHandler(pd: *PdApi.PlaydateAPI, event: PdApi.PDSystemEvent, arg: u32) callconv(.C) c_int {
    _ = arg;

    if (event == PdApi.kEventInit) {
        pd.*.system.*.setUpdateCallback.?(update, pd);
    }

    return 0;
}

fn update(_pd: ?*const anyopaque) callconv(.C) c_int {
    const pd: *const PdApi.PlaydateAPI = @alignCast(@ptrCast(_pd.?));

    pd.graphics.*.clear.?(PdApi.kColorWhite);

    const str = "Hi there!";
    _ = pd.graphics.*.drawText.?(str, str.len, PdApi.kASCIIEncoding, 0, 0);

    return 1;
}
