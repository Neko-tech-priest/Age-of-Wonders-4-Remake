const std = @import("std");

// pub fn memcpy(dst: [*]u8, src: [*]u8, sizeIn: u64) void
// {
//     @setRuntimeSafety(false);
//     var offset: u64 = 0;
//     while(offset < sizeIn) : (offset+=1)
//     {
//         @as(*u8, @ptrCast(@alignCast(dst+offset))).* = @as(*u8, @ptrCast(@alignCast(src+offset))).*;
//     }
// }
// pub fn memcpyBaseType(noalias dst: [*]u8, noalias src: [*]u8, comptime type: type) void
// {
//
// }
pub const alingment = std.simd.suggestVectorLength(u8) orelse 8;
pub fn memcpy(noalias dst: [*]u8, noalias src: [*]const u8, sizeIn: u64) void
{
//     std.debug.print("dst adress %: {d}\n", .{@intFromPtr(dst) % 8});
    @setRuntimeSafety(false);
    const vectorSize_u8: u64 = std.simd.suggestVectorLength(u8) orelse 8;
    const vectorSize_u64: u64 = std.simd.suggestVectorLength(u64) orelse 1;
//     const alignSize = sizeIn % vectorSize_u8;
//     const size = sizeIn - alignSize;
    var offset: u64 = 0;
    while(offset < sizeIn) : (offset+=vectorSize_u8)
    {
        @as(*@Vector(vectorSize_u64, u64), @ptrCast(@alignCast(dst+offset))).* = @as(*align(1) @Vector(vectorSize_u64, u64), @ptrCast(@constCast((src+offset)))).*;
    }
//     while(offset < sizeIn) : (offset+=1)
//     {
//         @as(*u8, @ptrCast(dst+offset)).* = @as(*u8, @ptrCast(@constCast(src+offset))).*;
// //         @as(*align(vectorSize_u8) u8, @ptrCast(@alignCast(dst+offset))).* = @as(*u8, @ptrCast(@constCast(src+offset))).*;
//     }
}
