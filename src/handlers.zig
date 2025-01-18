const Api = @import("handlers/api.zig");
const Memory = @import("handlers/memory.zig");

pub fn register_handlers() !void {
    try Api.register();
    try Memory.register();
}
