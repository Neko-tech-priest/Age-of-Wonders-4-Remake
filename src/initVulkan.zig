const std = @import("std");
const print = std.debug.print;

const VulkanInclude = @import("VulkanInclude.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;

pub inline fn init_commands() void
{
	// create a command pool for commands submitted to the graphics queue
	const commandPoolInfo = VulkanInclude.VkCommandPoolCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		//the command pool will be one that can submit graphics commands
		.queueFamilyIndex = VulkanGlobalState._graphicsQueueFamily,
		//we also want the pool to allow for resetting of individual command buffers
		.flags = VulkanInclude.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
	};
	_ = VulkanInclude.vkCreateCommandPool(VulkanGlobalState._device, &commandPoolInfo, null, &VulkanGlobalState._commandPool);

	const cmdAllocInfo = VulkanInclude.VkCommandBufferAllocateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		//commands will be made from our _commandPool
		.commandPool = VulkanGlobalState._commandPool,
		.commandBufferCount = VulkanGlobalState.FRAME_OVERLAP,
		// command level is Primary
		.level = VulkanInclude.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
	};
	_ = VulkanInclude.vkAllocateCommandBuffers(VulkanGlobalState._device, &cmdAllocInfo, &VulkanGlobalState._commandBuffers);
}
pub inline fn init_sync_structures() void
{
	const semaphoreCreateInfo = VulkanInclude.VkSemaphoreCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
	};
	//create synchronization structures
	const fenceCreateInfo = VulkanInclude.VkFenceCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
		//we want to create the fence with the Create Signaled flag, so we can wait on it before using it on a GPU command (for the first frame)
		.flags = VulkanInclude.VK_FENCE_CREATE_SIGNALED_BIT,
	};
	var i: usize = 0;
	while(i < VulkanGlobalState.FRAME_OVERLAP)
	{
		VulkanGlobalState.VK_CHECK(VulkanInclude.vkCreateFence(VulkanGlobalState._device, &fenceCreateInfo, null, &VulkanGlobalState._renderFences[i]));

		VulkanGlobalState.VK_CHECK(VulkanInclude.vkCreateSemaphore(VulkanGlobalState._device, &semaphoreCreateInfo, null, &VulkanGlobalState._presentSemaphores[i]));
		VulkanGlobalState.VK_CHECK(VulkanInclude.vkCreateSemaphore(VulkanGlobalState._device, &semaphoreCreateInfo, null, &VulkanGlobalState._renderSemaphores[i]));

		i+=1;
	}
}
pub inline fn deinit_sync_structures() void
{
	var i: usize = 0;
	while(i < VulkanGlobalState.FRAME_OVERLAP)
	{
		_ = VulkanInclude.vkDestroyFence(VulkanGlobalState._device, VulkanGlobalState._renderFences[i], null);

		_ = VulkanInclude.vkDestroySemaphore(VulkanGlobalState._device, VulkanGlobalState._presentSemaphores[i], null);
		_ = VulkanInclude.vkDestroySemaphore(VulkanGlobalState._device, VulkanGlobalState._renderSemaphores[i], null);

		i+=1;
	}
}
pub fn createTextureSampler() void
{
	const samplerInfo = VulkanInclude.VkSamplerCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
		// VK_FILTER_NEAREST
		// VK_FILTER_LINEAR
		.magFilter = VulkanInclude.VK_FILTER_LINEAR,
		.minFilter = VulkanInclude.VK_FILTER_LINEAR,
		.addressModeU = VulkanInclude.VK_SAMPLER_ADDRESS_MODE_REPEAT,
		.addressModeV = VulkanInclude.VK_SAMPLER_ADDRESS_MODE_REPEAT,
		.addressModeW = VulkanInclude.VK_SAMPLER_ADDRESS_MODE_REPEAT,
		.anisotropyEnable = VulkanInclude.VK_TRUE,
		.maxAnisotropy = VulkanGlobalState._deviceProperties.limits.maxSamplerAnisotropy,
		.borderColor = VulkanInclude.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
		.unnormalizedCoordinates = VulkanInclude.VK_FALSE,
		.compareEnable = VulkanInclude.VK_FALSE,
		.compareOp = VulkanInclude.VK_COMPARE_OP_ALWAYS,
		.minLod = 0.0,
		.maxLod = VulkanInclude.VK_LOD_CLAMP_NONE,
		// VK_SAMPLER_MIPMAP_MODE_NEAREST
		// VK_SAMPLER_MIPMAP_MODE_LINEAR
		.mipmapMode = VulkanInclude.VK_FILTER_LINEAR,
	};
	VK_CHECK(VulkanInclude.vkCreateSampler(VulkanGlobalState._device, &samplerInfo, null, &VulkanGlobalState._textureSampler));
}
