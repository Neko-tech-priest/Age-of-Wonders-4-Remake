const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

const customMem = @import("customMem.zig");
const memcpyDstAlign = customMem.memcpyDstAlign;
// const memcpyDstAlignVector = customMem.memcpyDstAlignVector;

const algebra = @import("algebra.zig");
const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;
const WindowGlobalState = @import("WindowGlobalState.zig");

const VkBuffer = @import("VkBuffer.zig");

pub var _cameraBuffers: [VulkanGlobalState.FRAME_OVERLAP]VulkanInclude.VkBuffer = undefined;
pub var _cameraBuffersMemory: [VulkanGlobalState.FRAME_OVERLAP]VulkanInclude.VkDeviceMemory = undefined;
pub var _cameraBuffersMapped: [VulkanGlobalState.FRAME_OVERLAP]?*anyopaque = undefined;

pub var _cameraDescriptorSetLayout: VulkanInclude.VkDescriptorSetLayout = undefined;
pub var _cameraDescriptorPool: VulkanInclude.VkDescriptorPool = undefined;
pub var _cameraDescriptorSets: [VulkanGlobalState.FRAME_OVERLAP]VulkanInclude.VkDescriptorSet = undefined;

pub var camera_translate_x: f32 = 0;
pub var camera_translate_y: f32 = 0;
pub var camera_translate_z: f32 = 0;
pub var camera_rotate_x: f32 = 0;
pub var camera_rotate_y: f32 = 0;
pub var camera_rotate_z: f32 = 0;

const CameraBufferObject = struct
{
	view: algebra.mat4,
	proj: algebra.mat4,
};
pub inline fn createCameraBuffers() void
{
	const bufferSize: VulkanInclude.VkDeviceSize = @sizeOf(CameraBufferObject);
	//print("{d}\n", .{bufferSize});
	var i: usize = 0;
	while(i < VulkanGlobalState.FRAME_OVERLAP)
	{
		VkBuffer.createVkBuffer__VkDeviceMemory__HV_DL(VulkanInclude.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, bufferSize, &_cameraBuffers[i], &_cameraBuffersMemory[i]);
		_ = VulkanInclude.vkMapMemory(VulkanGlobalState._device, _cameraBuffersMemory[i], 0, bufferSize, 0, &_cameraBuffersMapped[i]);
		i+=1;
	}
}
pub inline fn destroyCameraBuffers() void
{
	var i: usize = 0;
	while(i < VulkanGlobalState.FRAME_OVERLAP)
	{
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, _cameraBuffers[i], null);
		VulkanInclude.vkFreeMemory(VulkanGlobalState._device, _cameraBuffersMemory[i], null);
		i+=1;
	}
}
pub inline fn createCameraVkDescriptorSetLayout() void
{
	const cameraLayoutBinding = VulkanInclude.VkDescriptorSetLayoutBinding
	{
		.binding = 0,
		.descriptorCount = 1,
		.descriptorType = VulkanInclude.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
		.pImmutableSamplers = null,
		.stageFlags = VulkanInclude.VK_SHADER_STAGE_VERTEX_BIT,
	};
	const layoutInfo = VulkanInclude.VkDescriptorSetLayoutCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		.bindingCount = 1,
		.pBindings = &cameraLayoutBinding,
	};
	VK_CHECK(VulkanInclude.vkCreateDescriptorSetLayout(VulkanGlobalState._device, &layoutInfo, null, &_cameraDescriptorSetLayout));
}
pub inline fn createCameraVkDescriptorPool() void
{
	const poolSizes = VulkanInclude.VkDescriptorPoolSize
	{
		.type = VulkanInclude.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
		.descriptorCount = VulkanGlobalState.FRAME_OVERLAP,
	};
	const poolInfo = VulkanInclude.VkDescriptorPoolCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
		.poolSizeCount = 1,
		.pPoolSizes = &poolSizes,
		.maxSets = VulkanGlobalState.FRAME_OVERLAP,
	};
	VK_CHECK(VulkanInclude.vkCreateDescriptorPool(VulkanGlobalState._device, &poolInfo, null, &_cameraDescriptorPool));
}
pub inline fn createCameraVkDescriptorSets() void
{
	var layouts: [VulkanGlobalState.FRAME_OVERLAP]VulkanInclude.VkDescriptorSetLayout = undefined;
	var i: usize = 0;
	while(i < VulkanGlobalState.FRAME_OVERLAP)
	{
		layouts[i] = _cameraDescriptorSetLayout;
		i+=1;
	}
	const allocInfo = VulkanInclude.VkDescriptorSetAllocateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
		.descriptorPool = _cameraDescriptorPool,
		.descriptorSetCount = VulkanGlobalState.FRAME_OVERLAP,
		.pSetLayouts = &layouts,
	};
	VK_CHECK(VulkanInclude.vkAllocateDescriptorSets(VulkanGlobalState._device, &allocInfo, &_cameraDescriptorSets));
	i = 0;
	var descriptorWrites = [1]VulkanInclude.VkWriteDescriptorSet
	{
		.{},
	};
	while(i < VulkanGlobalState.FRAME_OVERLAP)
	{
		const bufferInfo = VulkanInclude.VkDescriptorBufferInfo
		{
			.buffer = _cameraBuffers[i],
			.offset = 0,
			.range = @sizeOf(CameraBufferObject),
		};

		descriptorWrites[0].sType = VulkanInclude.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
		descriptorWrites[0].dstSet = _cameraDescriptorSets[i];
		descriptorWrites[0].dstBinding = 0;
		descriptorWrites[0].dstArrayElement = 0;
		descriptorWrites[0].descriptorType = VulkanInclude.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
		descriptorWrites[0].descriptorCount = 1;
		descriptorWrites[0].pBufferInfo = &bufferInfo;

		VulkanInclude.vkUpdateDescriptorSets(VulkanGlobalState._device, descriptorWrites.len, &descriptorWrites, 0, null);
		i+=1;
	}
}
pub inline fn updateCameraBuffer(currentFrame: usize) void
{
// = currentFrame;
	var CoordinateSystem: algebra.mat4 = undefined;
	CoordinateSystem.rotate(90, 'x');
	var camera: CameraBufferObject = undefined;
	var cameraScale: algebra.mat4 = undefined;
	var cameraRotate: algebra.mat4 = undefined;
	var cameraTranslate: algebra.mat4 = undefined;

	cameraScale.scale(1, -1, 1);
	cameraRotate.rotate(camera_rotate_x, 'x');
	cameraTranslate.translate(0+camera_translate_x, 0+camera_translate_y, 2+camera_translate_z);
	camera.view = algebra.mul(cameraRotate, cameraTranslate);
	camera.proj.perspective(90.0, @as(f32, @floatFromInt(WindowGlobalState._windowExtent.width)) / @as(f32, @floatFromInt(WindowGlobalState._windowExtent.height)), 1.0/64.0, 64.0);
	camera.proj = algebra.mul(camera.proj, cameraScale);
	memcpyDstAlign(@ptrCast(_cameraBuffersMapped[currentFrame]), @ptrCast(&camera), @sizeOf(CameraBufferObject));
}
