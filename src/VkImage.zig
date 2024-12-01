const std = @import("std");
const c = std.c;
const print = std.debug.print;

const customMem = @import("customMem.zig");
const memcpyDstAlign = customMem.memcpyDstAlign;

const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;

const VkBuffer = @import("VkBuffer.zig");
const VkDeviceMemory = @import("VkDeviceMemory.zig");

const Image = @import("Image.zig");

pub fn createVkImage(image: *Image.Image, usage: VulkanInclude.VkImageUsageFlags, vkImage: *VulkanInclude.VkImage) void
{
	//print("mipsCount: {d}\n", .{image.mipsCount});
	const imageInfo = VulkanInclude.VkImageCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
		.imageType = VulkanInclude.VK_IMAGE_TYPE_2D,
		.extent = VulkanInclude.VkExtent3D
		{
			.width = image.width,
			.height = image.height,
			.depth = 1,
		},
		.mipLevels = image.mipsCount,
		.arrayLayers = 1,
		.format = image.format,
		.tiling = VulkanInclude.VK_IMAGE_TILING_OPTIMAL,
		.initialLayout = VulkanInclude.VK_IMAGE_LAYOUT_UNDEFINED,
		.usage = usage,
		.samples = VulkanInclude.VK_SAMPLE_COUNT_1_BIT,
		.sharingMode = VulkanInclude.VK_SHARING_MODE_EXCLUSIVE,
	};
	VK_CHECK(VulkanInclude.vkCreateImage(VulkanGlobalState._device, &imageInfo, null, vkImage));
}
pub fn createVkImageView(mipsCount: u32, image: VulkanInclude.VkImage, format: VulkanInclude.VkFormat, aspectFlags: VulkanInclude.VkImageAspectFlags, imageView: *VulkanInclude.VkImageView) void
{
	//_ = mipsCount;
	//print("mipsCount(createVkImageView): {d}\n", .{mipsCount});
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
			.levelCount = mipsCount,
			.baseArrayLayer = 0,
			.layerCount = 1,
		},
	};

	VK_CHECK(VulkanInclude.vkCreateImageView(VulkanGlobalState._device, &viewInfo, null, imageView));
}
pub fn createVkImages__VkImageViews__VkDeviceMemory_AoS_dst(images: [*]Image.Image, descriptors: [*]u8, descriptorsStructSize: u32, numImages: usize, dstDeviceMemory: *VulkanInclude.VkDeviceMemory) void
{
	var sizeDeviceMemory: usize = 0;
	var images_full_sizes: [512]u64 = undefined;
	//const images_full_sizes: [*]u64 = (globalState.arenaAllocator.alloc(u64, numImages) catch unreachable).ptr;
	for(0..numImages) |imageIndex|
	{
		const image = &images[imageIndex];
		createVkImage(image, VulkanInclude.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VulkanInclude.VK_IMAGE_USAGE_SAMPLED_BIT, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))));
		var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
		VulkanInclude.vkGetImageMemoryRequirements(VulkanGlobalState._device, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, &memRequirements);
		images_full_sizes[imageIndex] = (memRequirements.size + ((memRequirements.alignment - memRequirements.size % memRequirements.alignment) % memRequirements.alignment));
		sizeDeviceMemory += images_full_sizes[imageIndex];
		//print("imageFullSize: {d}\n", .{images_full_sizes[imageIndex]});
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
	for(0..numImages) |imageIndex|
	{
		const image = &images[imageIndex];
		VK_CHECK(VulkanInclude.vkBindImageMemory(VulkanGlobalState._device, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, dstDeviceMemory.*, deviceOffset));
		createVkImageView(image.mipsCount, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, image.format, VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT, @as(*VulkanInclude.VkImageView, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex+8))));
		memcpyDstAlign((@as([*]u8, @ptrCast(data))+deviceOffset), image.data, image.size);
		deviceOffset += images_full_sizes[imageIndex];
	}
	VulkanInclude.vkUnmapMemory(VulkanGlobalState._device, stagingDeviceMemory);
	
	//
	const cmdBeginInfo = VulkanInclude.VkCommandBufferBeginInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		.flags = VulkanInclude.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};
	// = VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo);
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
	for(0..numImages) |imageIndex|
	{
		barrier.image = @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*;
		barrier.subresourceRange.levelCount = images[imageIndex].mipsCount;
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
	for(0..numImages) |imageIndex|
	{
		const image = &images[imageIndex];
		var mipWidth: usize = image.width;
		var mipHeight: usize = image.height;
		var mipSize: usize = image.mipSize;
		var bufferOffset: usize = deviceOffset;
		for(0..image.mipsCount) |mipIndex|
		{
			region.imageSubresource.mipLevel = @intCast(mipIndex);
			region.bufferOffset = bufferOffset;
			region.imageExtent.width = @intCast(mipWidth);
			region.imageExtent.height = @intCast(mipHeight);
			VulkanInclude.vkCmdCopyBufferToImage(VulkanGlobalState._commandBuffers[0], stagingBuffer, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, VulkanInclude.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
            bufferOffset += mipSize;
			mipWidth /= 2;
			mipHeight /= 2;
			mipSize /= 4;
		}
		deviceOffset += images_full_sizes[imageIndex];
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
	
	for(0..numImages) |imageIndex|
	{
		barrier.image = @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*;
		barrier.subresourceRange.levelCount = images[imageIndex].mipsCount;
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
pub fn createVkImages__VkImageViews__VkDeviceMemory_AoS(srcStructArray: [*]u8, srcStructSize: u32, descriptors: [*]u8, descriptorsStructSize: u32, numImages: usize, dstDeviceMemory: *VulkanInclude.VkDeviceMemory) void
{
    var sizeDeviceMemory: usize = 0;
    var images_full_sizes: [512]u64 = undefined;
    //const images_full_sizes: [*]u64 = (globalState.arenaAllocator.alloc(u64, numImages) catch unreachable).ptr;
    for(0..numImages) |imageIndex|
    {
        const image = @as(*Image.Image, @alignCast(@ptrCast(srcStructArray+srcStructSize*imageIndex)));
        createVkImage(image, VulkanInclude.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VulkanInclude.VK_IMAGE_USAGE_SAMPLED_BIT, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))));
        var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
        VulkanInclude.vkGetImageMemoryRequirements(VulkanGlobalState._device, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, &memRequirements);
        images_full_sizes[imageIndex] = (memRequirements.size + ((memRequirements.alignment - memRequirements.size % memRequirements.alignment) % memRequirements.alignment));
        sizeDeviceMemory += images_full_sizes[imageIndex];
//         print("imageFullSize: {d}\n", .{images_full_sizes[imageIndex]});
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
    for(0..numImages) |imageIndex|
    {
        const image = @as(*Image.Image, @alignCast(@ptrCast(srcStructArray+srcStructSize*imageIndex)));
        VK_CHECK(VulkanInclude.vkBindImageMemory(VulkanGlobalState._device, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, dstDeviceMemory.*, deviceOffset));
        createVkImageView(image.mipsCount, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, image.format, VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT, @as(*VulkanInclude.VkImageView, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex+8))));
        memcpyDstAlign((@as([*]u8, @ptrCast(data))+deviceOffset), image.data, image.size);
        deviceOffset += images_full_sizes[imageIndex];
    }
    VulkanInclude.vkUnmapMemory(VulkanGlobalState._device, stagingDeviceMemory);
    
    //
    const cmdBeginInfo = VulkanInclude.VkCommandBufferBeginInfo
    {
        .sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VulkanInclude.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    // = VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo);
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
    for(0..numImages) |imageIndex|
    {
        barrier.image = @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*;
        barrier.subresourceRange.levelCount = @as(*Image.Image, @alignCast(@ptrCast(srcStructArray+srcStructSize*imageIndex))).mipsCount;
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
//     var region = VulkanInclude.VkBufferImageCopy
//     {
//         //.bufferOffset = 0,
//         .bufferRowLength = 0,
//         .bufferImageHeight = 0,
//         
//         .imageSubresource = VulkanInclude.VkImageSubresourceLayers
//         {
//             .aspectMask = VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT,
//             .mipLevel = 0,
//             .baseArrayLayer = 0,
//             .layerCount = 1,
//         },
//         .imageOffset = .{.x = 0, .y = 0, .z = 0},
//         .imageExtent = VulkanInclude.VkExtent3D
//         {
//             .depth = 1,
//         },
//     };
//     VK_CHECK(VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo));
//     deviceOffset = 0;
//     for(0..numImages) |imageIndex|
//     {
//         const image = @as(*Image.Image, @alignCast(@ptrCast(srcStructArray+srcStructSize*imageIndex)));
//         var mipWidth: usize = image.width;
//         var mipHeight: usize = image.height;
//         var mipSize: usize = image.mipSize;
//         var bufferOffset: usize = deviceOffset;
//         for(0..image.mipsCount) |mipIndex|
//         {
//             region.imageSubresource.mipLevel = @intCast(mipIndex);
//             region.bufferOffset = bufferOffset;
//             region.imageExtent.width = @intCast(mipWidth);
//             region.imageExtent.height = @intCast(mipHeight);
//             VulkanInclude.vkCmdCopyBufferToImage(VulkanGlobalState._commandBuffers[0], stagingBuffer, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, VulkanInclude.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
//             bufferOffset += mipSize;
//             mipWidth /= 2;
//             mipHeight /= 2;
//             mipSize /= 4;
//         }
//         deviceOffset += images_full_sizes[imageIndex];
//     }
    VK_CHECK(VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo));
    var regions: [16]VulkanInclude.VkBufferImageCopy = undefined;
    @memset(&regions,
    .{
        .imageSubresource = VulkanInclude.VkImageSubresourceLayers
        {
            .aspectMask = VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT,
            .layerCount = 1,
        },
        .imageExtent = VulkanInclude.VkExtent3D
        {
            .depth = 1,
        },
    }
    );
    deviceOffset = 0;
    for(0..numImages) |imageIndex|
    {
        const image = @as(*Image.Image, @alignCast(@ptrCast(srcStructArray+srcStructSize*imageIndex)));
        var mipWidth: u32 = image.width;
        var mipHeight: u32 = image.height;
        var mipSize: usize = image.mipSize;
        var bufferOffset: usize = deviceOffset;
        for(0..image.mipsCount) |mipIndex|
        {
            regions[mipIndex].imageSubresource.mipLevel = @intCast(mipIndex);
            regions[mipIndex].bufferOffset = bufferOffset;
            regions[mipIndex].imageExtent.width = mipWidth;
            regions[mipIndex].imageExtent.height = mipHeight;
            bufferOffset += mipSize;
            mipWidth /= 2;
            mipHeight /= 2;
            mipSize /= 4;
            mipSize += ((image.alignment - mipSize % image.alignment) % image.alignment);
        }
        VulkanInclude.vkCmdCopyBufferToImage(VulkanGlobalState._commandBuffers[0], stagingBuffer, @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*, VulkanInclude.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, image.mipsCount, &regions);
        deviceOffset += images_full_sizes[imageIndex];
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
    
    for(0..numImages) |imageIndex|
    {
        barrier.image = @as(*VulkanInclude.VkImage, @ptrCast(@alignCast(descriptors+descriptorsStructSize*imageIndex))).*;
        barrier.subresourceRange.levelCount = @as(*Image.Image, @alignCast(@ptrCast(srcStructArray+srcStructSize*imageIndex))).mipsCount;
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
