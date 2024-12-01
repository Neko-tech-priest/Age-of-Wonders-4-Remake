const std = @import("std");

pub var arena: std.heap.ArenaAllocator = undefined;
pub var arenaAllocator: std.mem.Allocator = undefined;

// pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// pub var gpaAllocator: std.mem.Allocator = undefined;

// pub const pageAllocator = std.heap.page_allocator;
