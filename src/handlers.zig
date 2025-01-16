const Api = @import("handlers/api.zig");

pub fn register_handlers() !void {
    try Api.register();
}
