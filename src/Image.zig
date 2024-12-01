const std = @import("std");
const c = std.c;
const VulkanInclude = @import("VulkanInclude.zig");

pub const Image = packed struct
{
	data: [*]u8,
	mipSize: u32,
	size: u32,
	width: u16,
	height: u16,
	mipsCount: u16,
	alignment: u16,
	format: VulkanInclude.VkFormat,

	pub fn destroy() void
	{
		c.free(@ptrCast(@alignCast(.data)));
	}
};
