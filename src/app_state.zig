const PdApi = @import("pd_api.zig").Api;
const Alloc = @import("alloc.zig");

allocator: Alloc.PdAllocator,
pd: *const PdApi.PlaydateAPI,
font: *PdApi.LCDFont,
x: isize,
y: isize,
dx: isize,
dy: isize,
