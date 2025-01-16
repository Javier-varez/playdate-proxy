const std = @import("std");

const PdApi = @import("pd_api.zig").Api;
const Alloc = @import("alloc.zig");

const Self = @This();

pub const TEXT_WIDTH: isize = 86;
pub const TEXT_HEIGHT: isize = 16;

allocator: Alloc.PdAllocator,
pd: *const PdApi.PlaydateAPI,
font: *PdApi.LCDFont,
x: isize,
y: isize,
dx: isize,
dy: isize,

pub fn init(pd: *const PdApi.PlaydateAPI) *Self {
    const fontpath = "/System/Fonts/Asheville-Sans-14-Bold.pft";
    var err: ?[*:0]const u8 = null;

    const font = pd.graphics.*.loadFont.?(fontpath, &err);
    if (font == null) {
        pd.system.*.@"error".?("Couldn't load font %s: %s", fontpath, err);
        unreachable;
    }

    if (pd.system.*.realloc.?(null, @sizeOf(Self) + @alignOf(Self))) |mem| {
        // Ensure that the pointer is aligned
        const ptr: *Self = @ptrFromInt(std.mem.alignForward(usize, @intFromPtr(mem), @alignOf(Self)));

        ptr.* = Self{
            .allocator = Alloc.PdAllocator.init(pd),
            .pd = pd,
            .x = (400 - TEXT_WIDTH) / 2,
            .y = (240 - TEXT_HEIGHT) / 2,
            .dx = 1,
            .dy = 1,
            .font = font.?,
        };
        return ptr;
    }

    pd.system.*.@"error".?("Unable to allocate AppState");
    unreachable;
}

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
