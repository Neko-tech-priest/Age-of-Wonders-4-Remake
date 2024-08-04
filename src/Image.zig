const std = @import("std");
const c = std.c;
const VulkanInclude = @import("VulkanInclude.zig");

pub const Image = packed struct
{
	data: [*]u8 = undefined,
	size: u32 = undefined,
	width: u32 = undefined,
	height: u32 = undefined,
	format: VulkanInclude.VkFormat = VulkanInclude.VK_FORMAT_UNDEFINED,

	pub inline fn destroy() void
	{
		c.free(@ptrCast(@alignCast(.data)));
	}
};
