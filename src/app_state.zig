const std = @import("std");

const PdApi = @import("pd_api.zig").Api;
const Alloc = @import("alloc.zig");

const Self = @This();

allocator: Alloc.PdAllocator,
pd: *const PdApi.PlaydateAPI,
font: *PdApi.LCDFont,
x: isize,
y: isize,
dx: isize,
dy: isize,

pub fn format(self: *const Self, comptime fmt: []const u8, args: anytype) std.ArrayList(u8) {
    var formatted_message = std.ArrayList(u8).init(self.allocator.allocator());

    std.fmt.format(formatted_message.writer(), fmt ++ "\x00", args) catch {
        self.pd.system.*.@"error".?("Unable to format message");
        unreachable;
    };
    return formatted_message;
}

pub fn print(self: *const Self, comptime fmt: []const u8, args: anytype) void {
    const formatted_message = format(self, fmt, args);
    defer formatted_message.deinit();
    self.pd.system.*.logToConsole.?("%s", formatted_message.items.ptr);
}

pub fn panic(self: *const Self, comptime fmt: []const u8, args: anytype) noreturn {
    const formatted_message = format(self, fmt, args);
    defer formatted_message.deinit();
    self.pd.system.*.@"error".?("%s", formatted_message.items.ptr);
    unreachable;
}
