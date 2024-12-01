const std = @import("std");
const mem = std.mem;
const c = std.c;
const print = std.debug.print;

const customMem = @import("customMem.zig");
const memcpyDstAlign = customMem.memcpyDstAlign;
// const memcpy = customMem.memcpy;

const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;

const VkDeviceMemory = @import("VkDeviceMemory.zig");

pub fn createVkBuffer(size: usize, usage:VulkanInclude.VkBufferUsageFlags, buffer: *VulkanInclude.VkBuffer) void
{
	const bufferInfo = VulkanInclude.VkBufferCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = size,
		.usage = usage,
		.sharingMode = VulkanInclude.VK_SHARING_MODE_EXCLUSIVE,
	};

	VK_CHECK(VulkanInclude.vkCreateBuffer(VulkanGlobalState._device, &bufferInfo, null, buffer));
}
pub fn createVkBuffer__VkDeviceMemory__HV_DL(usage: VulkanInclude.VkBufferUsageFlags, size: u32, vkBuffer: *VulkanInclude.VkBuffer, deviceMemory: *VulkanInclude.VkDeviceMemory) void
{
// = deviceMemory;
	var sizeDeviceMemory: usize = 0;
	var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
	createVkBuffer(size, usage, vkBuffer);
	VulkanInclude.vkGetBufferMemoryRequirements(VulkanGlobalState._device, vkBuffer.*, &memRequirements);
	sizeDeviceMemory = (memRequirements.size + ((memRequirements.alignment - memRequirements.size % memRequirements.alignment) % memRequirements.alignment));

	var memoryTypeIndex: u32 = undefined;
	memoryTypeIndex = VkDeviceMemory.findMemoryType(VulkanInclude.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VulkanInclude.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

	const allocInfo = VulkanInclude.VkMemoryAllocateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
		.allocationSize = sizeDeviceMemory,
		.memoryTypeIndex = memoryTypeIndex,
	};
	VK_CHECK(VulkanInclude.vkAllocateMemory(VulkanGlobalState._device, &allocInfo, null, deviceMemory));
	//createVkBuffer(sizeDeviceMemory, VK_BUFFER_USAGE_TRANSFER_DST_BIT, vkBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, vkBuffer.*, deviceMemory.*, 0));
}
pub fn createVkBuffer__VkDeviceMemory(usage: VulkanInclude.VkBufferUsageFlags, buffer: [*]u8, size: usize, vkBuffer: *VulkanInclude.VkBuffer, vkDeviceMemory: *VulkanInclude.VkDeviceMemory) void
{
	var sizeDeviceMemory: usize = 0;
	var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
	createVkBuffer(size, usage, vkBuffer);
	VulkanInclude.vkGetBufferMemoryRequirements(VulkanGlobalState._device, vkBuffer.*, &memRequirements);
	sizeDeviceMemory = (memRequirements.size + ((memRequirements.alignment - memRequirements.size % memRequirements.alignment) % memRequirements.alignment));
	
	var dstBuffer: VulkanInclude.VkBuffer = undefined;
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
	createVkBuffer(sizeDeviceMemory, VulkanInclude.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, &stagingBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, stagingBuffer, stagingDeviceMemory, 0));
	
	memoryTypeIndex = VkDeviceMemory.findMemoryType(VulkanInclude.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
	allocInfo.memoryTypeIndex = memoryTypeIndex;
	VK_CHECK(VulkanInclude.vkAllocateMemory(VulkanGlobalState._device, &allocInfo, null, vkDeviceMemory));
	createVkBuffer(sizeDeviceMemory, VulkanInclude.VK_BUFFER_USAGE_TRANSFER_DST_BIT, &dstBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, dstBuffer, vkDeviceMemory.*, 0));
	
	defer
	{
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, dstBuffer, null);
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, stagingBuffer, null);
		VulkanInclude.vkFreeMemory(VulkanGlobalState._device, stagingDeviceMemory, null);
	}
	var data: ?*anyopaque = undefined;
	_ = VulkanInclude.vkMapMemory(VulkanGlobalState._device, stagingDeviceMemory, 0, sizeDeviceMemory, 0, &data);

	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device,  vkBuffer.*, vkDeviceMemory.*, 0));
	memcpyDstAlign(@ptrCast(data), buffer, size);
	VulkanInclude.vkUnmapMemory(VulkanGlobalState._device, stagingDeviceMemory);

	const cmdBeginInfo = VulkanInclude.VkCommandBufferBeginInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		.flags = VulkanInclude.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};
	_ = VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo);
	
	const copyRegion = VulkanInclude.VkBufferCopy
	{
		.size = sizeDeviceMemory,
	};
	//copyRegion.srcOffset = 0; // Optional
	//copyRegion.dstOffset = 0; // Optional
	VulkanInclude.vkCmdCopyBuffer(VulkanGlobalState._commandBuffers[0], stagingBuffer, dstBuffer, 1, &copyRegion);
	
	_ = VulkanInclude.vkEndCommandBuffer(VulkanGlobalState._commandBuffers[0]);
	
	const submitInfo = VulkanInclude.VkSubmitInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_SUBMIT_INFO,
		.commandBufferCount = 1,
		.pCommandBuffers = &VulkanGlobalState._commandBuffers[0],
	};
	
	_ = VulkanInclude.vkQueueSubmit(VulkanGlobalState._graphicsQueue, 1, &submitInfo, null);
	_ = VulkanInclude.vkQueueWaitIdle(VulkanGlobalState._graphicsQueue);
}
pub fn createVkBuffers__VkDeviceMemory_AoS(usage: VulkanInclude.VkBufferUsageFlags, srcStructArray: [*]u8, srcStructSize: u32, sizeOffset: u32, VkBufferStructArray: [*]u8, VkBufferStructSize: u32, numBuffers: usize, dstDeviceMemory: *VulkanInclude.VkDeviceMemory) void
{
    var sizeDeviceMemory: usize = 0;
	var buffers_full_sizes: [512]u64 = undefined;
//     const buffers_full_sizes: [*]u64 = (globalState.arenaAllocator.alloc(u64, numBuffers) catch unreachable).ptr;
    for(0..numBuffers) |bufferIndex|
    {
        createVkBuffer(mem.bytesToValue(u32, srcStructArray+srcStructSize*bufferIndex+sizeOffset), usage, @as(*VulkanInclude.VkBuffer, @ptrCast(@alignCast(VkBufferStructArray+VkBufferStructSize*bufferIndex))));
        var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
        VulkanInclude.vkGetBufferMemoryRequirements(VulkanGlobalState._device, @as(*VulkanInclude.VkBuffer, @ptrCast(@alignCast(VkBufferStructArray+VkBufferStructSize*bufferIndex))).*, &memRequirements);

        buffers_full_sizes[bufferIndex] = (memRequirements.size + ((memRequirements.alignment - memRequirements.size % memRequirements.alignment) % memRequirements.alignment));
        sizeDeviceMemory += buffers_full_sizes[bufferIndex];
//         print("buffer size: {d}\n", .{buffers_full_sizes[bufferIndex]});
    }
    var dstBuffer: VulkanInclude.VkBuffer = undefined;
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
	createVkBuffer(sizeDeviceMemory, VulkanInclude.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, &stagingBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, stagingBuffer, stagingDeviceMemory, 0));
	memoryTypeIndex = VkDeviceMemory.findMemoryType(VulkanInclude.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
	allocInfo.memoryTypeIndex = memoryTypeIndex;
	VK_CHECK(VulkanInclude.vkAllocateMemory(VulkanGlobalState._device, &allocInfo, null, dstDeviceMemory));
	createVkBuffer(sizeDeviceMemory, VulkanInclude.VK_BUFFER_USAGE_TRANSFER_DST_BIT, &dstBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, dstBuffer, dstDeviceMemory.*, 0));
	defer
	{
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, dstBuffer, null);
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, stagingBuffer, null);
		VulkanInclude.vkFreeMemory(VulkanGlobalState._device, stagingDeviceMemory, null);
	}
	var deviceOffset: usize = 0;
	var data: ?*anyopaque = undefined;
	_ = VulkanInclude.vkMapMemory(VulkanGlobalState._device, stagingDeviceMemory, 0, sizeDeviceMemory, 0, &data);
	for(0..numBuffers) |bufferIndex|
	{
		const PtrStruct = struct
		{
			data: [*]u8 = undefined,
		};
		VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device,  @as(*VulkanInclude.VkBuffer, @ptrCast(@alignCast(VkBufferStructArray+VkBufferStructSize*bufferIndex))).*, dstDeviceMemory.*, deviceOffset));
		memcpyDstAlign((@as([*]u8, @ptrCast(data))+deviceOffset), (@as(*PtrStruct, @ptrCast(@alignCast(srcStructArray+srcStructSize*bufferIndex)))).*.data, @as(*u32,@ptrCast(@alignCast(srcStructArray+srcStructSize*bufferIndex+sizeOffset))).*);
		deviceOffset += buffers_full_sizes[bufferIndex];
	}
	VulkanInclude.vkUnmapMemory(VulkanGlobalState._device, stagingDeviceMemory);
	const cmdBeginInfo = VulkanInclude.VkCommandBufferBeginInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		.flags = VulkanInclude.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};
	_ = VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo);
	const copyRegion = VulkanInclude.VkBufferCopy
	{
		.size = sizeDeviceMemory,
	};
	VulkanInclude.vkCmdCopyBuffer(VulkanGlobalState._commandBuffers[0], stagingBuffer, dstBuffer, 1, &copyRegion);
	_ = VulkanInclude.vkEndCommandBuffer(VulkanGlobalState._commandBuffers[0]);
	const submitInfo = VulkanInclude.VkSubmitInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_SUBMIT_INFO,
		.commandBufferCount = 1,
		.pCommandBuffers = &VulkanGlobalState._commandBuffers[0],
	};
	_ = VulkanInclude.vkQueueSubmit(VulkanGlobalState._graphicsQueue, 1, &submitInfo, null);
	_ = VulkanInclude.vkQueueWaitIdle(VulkanGlobalState._graphicsQueue);
}
pub fn createVkBuffers__VkDeviceMemory_AoS_Dst(usage: VulkanInclude.VkBufferUsageFlags, buffersArray: [*][*]u8, sizesArray: [*]usize, VkBufferStructArray: [*]u8, VkBufferStructSize: u32, numBuffers: usize, dstDeviceMemory: *VulkanInclude.VkDeviceMemory) void
{
	var sizeDeviceMemory: usize = 0;
	const buffers_full_sizes: [*]u64 = (globalState.arenaAllocator.alloc(u64, numBuffers) catch unreachable).ptr;
	for(0..numBuffers) |bufferIndex|
    {
//         print("buffer size: {d}\n", .{sizesArray[bufferIndex]});
        createVkBuffer(sizesArray[bufferIndex], usage, @as(*VulkanInclude.VkBuffer, @ptrCast(@alignCast(VkBufferStructArray+VkBufferStructSize*bufferIndex))));
		var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
		VulkanInclude.vkGetBufferMemoryRequirements(VulkanGlobalState._device, @as(*VulkanInclude.VkBuffer, @ptrCast(@alignCast(VkBufferStructArray+VkBufferStructSize*bufferIndex))).*, &memRequirements);
		
		buffers_full_sizes[bufferIndex] = (memRequirements.size + ((memRequirements.alignment - memRequirements.size % memRequirements.alignment) % memRequirements.alignment));
		sizeDeviceMemory += buffers_full_sizes[bufferIndex];
	}
	var dstBuffer: VulkanInclude.VkBuffer = undefined;
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
	createVkBuffer(sizeDeviceMemory, VulkanInclude.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, &stagingBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, stagingBuffer, stagingDeviceMemory, 0));
	memoryTypeIndex = VkDeviceMemory.findMemoryType(VulkanInclude.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
	allocInfo.memoryTypeIndex = memoryTypeIndex;
	VK_CHECK(VulkanInclude.vkAllocateMemory(VulkanGlobalState._device, &allocInfo, null, dstDeviceMemory));
	createVkBuffer(sizeDeviceMemory, VulkanInclude.VK_BUFFER_USAGE_TRANSFER_DST_BIT, &dstBuffer);
	VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device, dstBuffer, dstDeviceMemory.*, 0));
	defer
	{
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, dstBuffer, null);
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, stagingBuffer, null);
		VulkanInclude.vkFreeMemory(VulkanGlobalState._device, stagingDeviceMemory, null);
	}
	var deviceOffset: usize = 0;
	var data: ?*anyopaque = undefined;
	_ = VulkanInclude.vkMapMemory(VulkanGlobalState._device, stagingDeviceMemory, 0, sizeDeviceMemory, 0, &data);
	for(0..numBuffers) |bufferIndex|
	{
		VK_CHECK(VulkanInclude.vkBindBufferMemory(VulkanGlobalState._device,  @as(*VulkanInclude.VkBuffer, @ptrCast(@alignCast(VkBufferStructArray+VkBufferStructSize*bufferIndex))).*, dstDeviceMemory.*, deviceOffset));
		memcpyDstAlign((@as([*]u8, @ptrCast(data))+deviceOffset), buffersArray[bufferIndex], sizesArray[bufferIndex]);
		deviceOffset += buffers_full_sizes[bufferIndex];
	}
	VulkanInclude.vkUnmapMemory(VulkanGlobalState._device, stagingDeviceMemory);
	const cmdBeginInfo = VulkanInclude.VkCommandBufferBeginInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		.flags = VulkanInclude.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};
	_ = VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[0], &cmdBeginInfo);
	const copyRegion = VulkanInclude.VkBufferCopy
	{
		.size = sizeDeviceMemory,
	};
	VulkanInclude.vkCmdCopyBuffer(VulkanGlobalState._commandBuffers[0], stagingBuffer, dstBuffer, 1, &copyRegion);
	_ = VulkanInclude.vkEndCommandBuffer(VulkanGlobalState._commandBuffers[0]);
	const submitInfo = VulkanInclude.VkSubmitInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_SUBMIT_INFO,
		.commandBufferCount = 1,
		.pCommandBuffers = &VulkanGlobalState._commandBuffers[0],
	};
	_ = VulkanInclude.vkQueueSubmit(VulkanGlobalState._graphicsQueue, 1, &submitInfo, null);
	_ = VulkanInclude.vkQueueWaitIdle(VulkanGlobalState._graphicsQueue);
}
