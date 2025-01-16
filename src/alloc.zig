const std = @import("std");

const PdApi = @import("pd_api.zig").Api;

pub const PdAllocator = struct {
    const Self = @This();

    pd: *const PdApi.PlaydateAPI,

    fn pd_alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        // TODO: use alignment argument!
        _ = ret_addr;

        const self: *const Self = @alignCast(@ptrCast(ctx));
        if (self.pd.system.*.realloc.?(null, len)) |ptr| {
            if (ptr_align != 0 and !std.mem.isAligned(@intFromPtr(ptr), ptr_align)) {
                self.pd.system.*.@"error".?("Unable to get pointer with alignment %d", ptr_align);
                unreachable;
            }
            return @ptrCast(ptr);
        }
        return null;
    }

    fn pd_resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;

        return false;
    }

    fn pd_free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        _ = buf_align;
        _ = ret_addr;

        const self: *const Self = @alignCast(@ptrCast(ctx));
        _ = self.pd.system.*.realloc.?(buf.ptr, 0);
    }

    const vtable = std.mem.Allocator.VTable{
        .alloc = pd_alloc,
        .resize = pd_resize,
        .free = pd_free,
    };

    pub fn init(pd: *const PdApi.PlaydateAPI) Self {
        return Self{ .pd = pd };
    }

    pub fn allocator(self: *const Self) std.mem.Allocator {
        return std.mem.Allocator{
            .ptr = @constCast(self),
            .vtable = &vtable,
        };
    }
};
