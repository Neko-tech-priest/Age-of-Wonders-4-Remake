const std = @import("std");
const c = std.c;
const print = std.debug.print;

const customMem = @import("customMem.zig");
const memcpy = customMem.memcpy;

const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;

const VkBuffer = @import("VkBuffer.zig");
const VkDeviceMemory = @import("VkDeviceMemory.zig");

const Image = @import("Image.zig");

pub fn createVkImage(width: u32, height: u32, format: VulkanInclude.VkFormat, usage: VulkanInclude.VkImageUsageFlags, vkImage: *VulkanInclude.VkImage) void
{
	const imageInfo = VulkanInclude.VkImageCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
		.imageType = VulkanInclude.VK_IMAGE_TYPE_2D,
		.extent = VulkanInclude.VkExtent3D
		{
			.width = width,
			.height = height,
			.depth = 1,
		},
		.mipLevels = 1,
		.arrayLayers = 1,
		.format = format,
		.tiling = VulkanInclude.VK_IMAGE_TILING_OPTIMAL,
		.initialLayout = VulkanInclude.VK_IMAGE_LAYOUT_UNDEFINED,
		.usage = usage,
		.samples = VulkanInclude.VK_SAMPLE_COUNT_1_BIT,
		.sharingMode = VulkanInclude.VK_SHARING_MODE_EXCLUSIVE,
	};
	VK_CHECK(VulkanInclude.vkCreateImage(VulkanGlobalState._device, &imageInfo, null, vkImage));
}
pub fn createVkImageView(image: VulkanInclude.VkImage, format: VulkanInclude.VkFormat, aspectFlags: VulkanInclude.VkImageAspectFlags, imageView: *VulkanInclude.VkImageView) void
{
	const viewInfo = VulkanInclude.VkImageViewCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
		.image = image,
		.viewType = VulkanInclude.VK_IMAGE_VIEW_TYPE_2D,
		.format = format,
		.subresourceRange = VulkanInclude.VkImageSubresourceRange
		{
			.aspectMask = aspectFlags,
			.baseMipLevel = 0,
			.levelCount = 1,
			.baseArrayLayer = 0,
			.layerCount = 1,
		},
	};

	VK_CHECK(VulkanInclude.vkCreateImageView(VulkanGlobalState._device, &viewInfo, null, imageView));
}
pub fn createVkImages__VkImageViews__VkDeviceMemory_AoS(srcStructArray: [*]u8, srcStructSize: u32, descriptors: [*]u8, descriptorsStructSize: u32, numImages: u32, dstDeviceMemory: *VulkanInclude.VkDeviceMemory) void
{
	var sizeDeviceMemory: usize = 0;
	const images_full_sizes: [*]u64 = (globalState.arenaAllocator.alloc(u64, numImages) catch unreachable).ptr;
	var i: usize = 0;
	while(i < numImages) : (i+=1)
	{
// 		@as(*VulkanInclude.VkBuffer, @ptrCast(@alignCast(VkBufferStructArray+VkBufferStructSize*i)))
		createVkImage(@as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).width,
					  @as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).height,
					  @as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).format,
					  VulkanInclude.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VulkanInclude.VK_IMAGE_USAGE_SAMPLED_BIT, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i))));
		var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
		VulkanInclude.vkGetImageMemoryRequirements(VulkanGlobalState._device, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i))).*, &memRequirements);
		images_full_sizes[i] = (memRequirements.size + ((memRequirements.alignment - memRequirements.size % memRequirements.alignment) % memRequirements.alignment));
		sizeDeviceMemory += images_full_sizes[i];
	}
	var stagingBuffer: VulkanInclude.VkBuffer = undefined;
	var stagingDeviceMemory: VulkanInclude.VkDeviceMemory = undefined;

	var memoryTypeIndex: u32 = undefined;

	var allocInfo = VulkanInclude.VkMemoryAllocateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
		.allocationSize = sizeDeviceMemory,
	};
	memoryTypeIndex = VkDeviceMemory.findMemoryType(VulkanInclude.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
	allocInfo.memoryTypeIndex = memoryTypeIndex;
	VK_CHECK(VulkanInclude.vkAllocateMemory(VulkanGlobalState._device, &allocInfo, null, &stagingDeviceMemory));
	VkBuffer.createVkBuffer(sizeDeviceMemory, VulkanInclude.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, &stagingBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, stagingBuffer, stagingDeviceMemory, 0));

	memoryTypeIndex = VkDeviceMemory.findMemoryType(VulkanInclude.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
	allocInfo.memoryTypeIndex = memoryTypeIndex;
	VK_CHECK(VulkanInclude.vkAllocateMemory(VulkanGlobalState._device, &allocInfo, null, dstDeviceMemory));

	defer
	{
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, stagingBuffer, null);
		VulkanInclude.vkFreeMemory(VulkanGlobalState._device, stagingDeviceMemory, null);
	}

	var deviceOffset: usize = 0;
	var data: ?*anyopaque = undefined;
	_ = VulkanInclude.vkMapMemory(VulkanGlobalState._device, stagingDeviceMemory, 0, sizeDeviceMemory, 0, &data);
	i = 0;
	while(i < numImages) : (i+=1)
	{
		VK_CHECK(VulkanInclude.vkBindImageMemory(VulkanGlobalState._device, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i))).*, dstDeviceMemory.*, deviceOffset));
		createVkImageView(@as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i))).*, @as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).format, VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT, @as(*VulkanInclude.VkImageView, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i+8))));
// 		print("{d}\n", .{@intFromPtr(data)+deviceOffset});
// 		print("{d}\n", .{(@intFromPtr(data)+deviceOffset) % 8});
// 		print("{d}\n", .{@intFromPtr(images[i].data)});
// 		print("{d}\n", .{@intFromPtr(images[i].data) % 8});
// 		@memcpy((@as([*]u8, @ptrCast(data))+deviceOffset)[0..images[i].size], images[i].data);
		memcpy((@as([*]u8, @ptrCast(data))+deviceOffset), @as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).data, @as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).size);
		deviceOffset += images_full_sizes[i];
	}
	VulkanInclude.vkUnmapMemory(VulkanGlobalState._device, stagingDeviceMemory);

	//
	const cmdBeginInfo = VulkanInclude.VkCommandBufferBeginInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		.flags = VulkanInclude.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};
// 	_ = VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo);
	//
	const submitInfo = VulkanInclude.VkSubmitInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_SUBMIT_INFO,
		.commandBufferCount = 1,
		.pCommandBuffers = &VulkanGlobalState._commandBuffers[0],
	};

	// перший бар'єр
	var barrier = VulkanInclude.VkImageMemoryBarrier
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
		.oldLayout =VulkanInclude. VK_IMAGE_LAYOUT_UNDEFINED,
		.newLayout = VulkanInclude.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		.srcQueueFamilyIndex = VulkanInclude.VK_QUEUE_FAMILY_IGNORED,
		.dstQueueFamilyIndex = VulkanInclude.VK_QUEUE_FAMILY_IGNORED,
		//.image = textureImage,
		.subresourceRange = VulkanInclude.VkImageSubresourceRange
		{
			.aspectMask = VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT,
			.baseMipLevel = 0,
			.levelCount = 1,
			.baseArrayLayer = 0,
			.layerCount = 1,
		},
	};

	barrier.srcAccessMask = 0;
	barrier.dstAccessMask = VulkanInclude.VK_ACCESS_TRANSFER_WRITE_BIT;

	_ = VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo);

	i = 0;
	while(i < numImages) : (i+=1)
	{
		barrier.image = @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i))).*;
		VulkanInclude.vkCmdPipelineBarrier(
			VulkanGlobalState._commandBuffers[0],
			VulkanInclude.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VulkanInclude.VK_PIPELINE_STAGE_TRANSFER_BIT,
			0,
			0, null,
			0, null,
			1, &barrier
		);
	}

	VK_CHECK(VulkanInclude.vkEndCommandBuffer(VulkanGlobalState._commandBuffers[0]));
	VK_CHECK(VulkanInclude.vkQueueSubmit(VulkanGlobalState._graphicsQueue, 1, &submitInfo, null));
	_ = VulkanInclude.vkQueueWaitIdle(VulkanGlobalState._graphicsQueue);

	//копіювання
	var region = VulkanInclude.VkBufferImageCopy
	{
		//.bufferOffset = 0,
		.bufferRowLength = 0,
		.bufferImageHeight = 0,

		.imageSubresource = VulkanInclude.VkImageSubresourceLayers
		{
			.aspectMask = VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT,
			.mipLevel = 0,
			.baseArrayLayer = 0,
			.layerCount = 1,
		},
		.imageOffset = .{.x = 0, .y = 0, .z = 0},
		.imageExtent = VulkanInclude.VkExtent3D
		{
			.depth = 1,
		},
	};

	VK_CHECK(VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo));

	deviceOffset = 0;
	i = 0;
	while(i < numImages) : (i+=1)
	{
		region.bufferOffset = deviceOffset;
		region.imageExtent.width = @as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).width;
		region.imageExtent.height = @as(*Image.Image, @ptrCast(@alignCast(srcStructArray+srcStructSize*i))).height;
		VulkanInclude.vkCmdCopyBufferToImage(VulkanGlobalState._commandBuffers[0], stagingBuffer, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i))).*, VulkanInclude.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
		deviceOffset += images_full_sizes[i];
	}

	VK_CHECK(VulkanInclude.vkEndCommandBuffer(VulkanGlobalState._commandBuffers[0]));
	VK_CHECK(VulkanInclude.vkQueueSubmit(VulkanGlobalState._graphicsQueue, 1, &submitInfo, null));
	_ = VulkanInclude.vkQueueWaitIdle(VulkanGlobalState._graphicsQueue);

	//другий бар'єр
	barrier.oldLayout = VulkanInclude.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
	barrier.newLayout = VulkanInclude.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

	barrier.srcAccessMask = VulkanInclude.VK_ACCESS_TRANSFER_WRITE_BIT;
	barrier.dstAccessMask = VulkanInclude.VK_ACCESS_SHADER_READ_BIT;

	VK_CHECK(VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo));

	i = 0;
	while(i < numImages) : (i+=1)
	{
		barrier.image = @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*i))).*;
		VulkanInclude.vkCmdPipelineBarrier(
			VulkanGlobalState._commandBuffers[0],
			VulkanInclude.VK_PIPELINE_STAGE_TRANSFER_BIT, VulkanInclude.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
			0,
			0, null,
			0, null,
			1, &barrier
		);
	}
	VK_CHECK(VulkanInclude.vkEndCommandBuffer(VulkanGlobalState._commandBuffers[0]));
	VK_CHECK(VulkanInclude.vkQueueSubmit(VulkanGlobalState._graphicsQueue, 1, &submitInfo, null));
	_ = VulkanInclude.vkQueueWaitIdle(VulkanGlobalState._graphicsQueue);
}
