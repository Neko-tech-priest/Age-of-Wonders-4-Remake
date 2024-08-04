const std = @import("std");
const print = std.debug.print;

const globalState = @import("globalState.zig");

const VulkanInclude = @import("VulkanInclude.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;

pub fn createShaderModule(path: [*:0]const u8) !VulkanInclude.VkShaderModule
{
    const file: std.fs.File = try std.fs.cwd().openFileZ(path, .{});// catch std.process.exit(0)
    defer file.close();

    const stat = file.stat() catch unreachable;
    const file_size: usize = stat.size;
    var fileBuffer: [*]u8 = (globalState.arenaAllocator.alloc(u8, file_size + ((4 - file_size % 4) % 4)) catch unreachable).ptr;
    _ = file.read(fileBuffer[0..file_size]) catch unreachable;

    const createInfo = VulkanInclude.VkShaderModuleCreateInfo
    {
        .sType = VulkanInclude.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = file_size,
        .pCode = @ptrCast(@alignCast(fileBuffer)),
    };

    var shaderModule: VulkanInclude.VkShaderModule = undefined;
    VK_CHECK(VulkanInclude.vkCreateShaderModule(VulkanGlobalState._device, &createInfo, null, &shaderModule));

    return shaderModule;
}
