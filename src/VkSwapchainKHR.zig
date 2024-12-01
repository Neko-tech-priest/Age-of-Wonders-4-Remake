const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

// const SDL = @import("SDL.zig");

const VulkanInclude = @import("VulkanInclude.zig");

const globalState = @import("globalState.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;
const WindowGlobalState = @import("WindowGlobalState.zig");

const VkDeviceMemory = @import("VkDeviceMemory.zig");
const VkImage = @import("VkImage.zig");

pub fn createVkSwapchainKHR() void
{
	var capabilities :VulkanInclude.VkSurfaceCapabilitiesKHR = undefined;
	var formats: [4]VulkanInclude.VkSurfaceFormatKHR = undefined;
	var presentModes: [4]VulkanInclude.VkPresentModeKHR = undefined;

	_ = VulkanInclude.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(VulkanGlobalState._physicalDevice, VulkanGlobalState._surface, &capabilities);

	var formatCount: u32 = undefined;
	_ = VulkanInclude.vkGetPhysicalDeviceSurfaceFormatsKHR(VulkanGlobalState._physicalDevice, VulkanGlobalState._surface, &formatCount, null);
	//print("formatCount: {d}\n", .{formatCount});
	if (formatCount != 0)
	{
		_ = VulkanInclude.vkGetPhysicalDeviceSurfaceFormatsKHR(VulkanGlobalState._physicalDevice, VulkanGlobalState._surface, &formatCount, &formats);
	}

	var presentModeCount: u32 = undefined;
	_ = VulkanInclude.vkGetPhysicalDeviceSurfacePresentModesKHR(VulkanGlobalState._physicalDevice, VulkanGlobalState._surface, &presentModeCount, null);
	//print("presentModeCount: {d}\n", .{presentModeCount});
	if (presentModeCount != 0)
	{
		_ = VulkanInclude.vkGetPhysicalDeviceSurfacePresentModesKHR(VulkanGlobalState._physicalDevice, VulkanGlobalState._surface, &presentModeCount, &presentModes);
	}
	var formatFound: bool = false;
	for(formats[0..formatCount]) |format|
	{
		if (format.format == VulkanInclude.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == VulkanInclude.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
		{
			formatFound = true;
			break;
		}
	}
	if(!formatFound)
	{
		print("swapchain format not found!\n", .{});
		std.process.exit(0);
	}
//     var presentModeFound: bool = false;
//     for(presentModes[0..presentModeCount]) |presentMode|
//     {
//         //VK_PRESENT_MODE_IMMEDIATE_KHR
//         //VK_PRESENT_MODE_MAILBOX_KHR
//         //VK_PRESENT_MODE_FIFO_KHR
//         //VK_PRESENT_MODE_FIFO_RELAXED_KHR
//         if(presentMode == VulkanInclude.VK_PRESENT_MODE_FIFO_KHR)
//         {
//             presentModeFound = true;
//             break;
//         }
//     }
//     if(!presentModeFound)
//     {
//         print("swapchain present mode not found!\n", .{});
//         std.process.exit(0);
//     }

	const surfaceFormat = VulkanInclude.VkSurfaceFormatKHR
	{
		.format = VulkanInclude.VK_FORMAT_B8G8R8A8_SRGB,
		.colorSpace = VulkanInclude.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
	};
	const presentMode: VulkanInclude.VkPresentModeKHR = VulkanInclude.VK_PRESENT_MODE_FIFO_KHR;
	WindowGlobalState._windowExtent = capabilities.currentExtent;

	VulkanGlobalState._swapchainImagesCount = capabilities.minImageCount;
	//print("_swapchainImagesCount: {d}\n", .{VulkanGlobalState._swapchainImagesCount});
	const swapchainCreateInfo = VulkanInclude.VkSwapchainCreateInfoKHR
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
		.surface = VulkanGlobalState._surface,
		.minImageCount = VulkanGlobalState._swapchainImagesCount,
		.imageFormat = surfaceFormat.format,
		.imageColorSpace = surfaceFormat.colorSpace,
		.imageExtent = capabilities.currentExtent,
		.imageArrayLayers = 1,
		.imageUsage = VulkanInclude.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		//за графику и представление отвечает одна и та же очередь
		.imageSharingMode = VulkanInclude.VK_SHARING_MODE_EXCLUSIVE,
		.queueFamilyIndexCount = 0, // Optional
		.pQueueFamilyIndices = null, // Optional
		//никаких трансформаций
		.preTransform = capabilities.currentTransform,
		//игнорирование альфы
		.compositeAlpha = VulkanInclude.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		.presentMode = presentMode,
		//отсечение пикселей, которых не видно для лучшей производительности
		.clipped = VulkanInclude.VK_TRUE,
		.oldSwapchain = null,
	};
	VK_CHECK(VulkanInclude.vkCreateSwapchainKHR(VulkanGlobalState._device, &swapchainCreateInfo, null, &VulkanGlobalState._swapchain));
//
	_ = VulkanInclude.vkGetSwapchainImagesKHR(VulkanGlobalState._device, VulkanGlobalState._swapchain, &VulkanGlobalState._swapchainImagesCount, null);
    _ = VulkanInclude.vkGetSwapchainImagesKHR(VulkanGlobalState._device, VulkanGlobalState._swapchain, &VulkanGlobalState._swapchainImagesCount, &VulkanGlobalState._swapchainImages);
    var imageViewCreateInfo = VulkanInclude.VkImageViewCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
	// .image = _swapChainImages[i];
		.viewType = VulkanInclude.VK_IMAGE_VIEW_TYPE_2D,
		.format = VulkanInclude.VK_FORMAT_B8G8R8A8_SRGB,
		// переключения цветовых каналов, значение по умолчанию
		.components = VulkanInclude.VkComponentMapping
		{
			.r = VulkanInclude.VK_COMPONENT_SWIZZLE_IDENTITY,
			.g = VulkanInclude.VK_COMPONENT_SWIZZLE_IDENTITY,
			.b = VulkanInclude.VK_COMPONENT_SWIZZLE_IDENTITY,
			.a = VulkanInclude.VK_COMPONENT_SWIZZLE_IDENTITY,
		},
		// к какой части изображения стоит обращаться
		.subresourceRange = VulkanInclude.VkImageSubresourceRange
		{
			.aspectMask = VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT,
			.baseMipLevel = 0,
			.levelCount = 1,
			.baseArrayLayer = 0,
			.layerCount = 1,
		},
	};
	var i: usize = 0;
	while(i < VulkanGlobalState._swapchainImagesCount)
	{
		imageViewCreateInfo.image = VulkanGlobalState._swapchainImages[i];
		VK_CHECK(VulkanInclude.vkCreateImageView(VulkanGlobalState._device, &imageViewCreateInfo, null, &VulkanGlobalState._swapchainImageViews[i]));
		i+=1;
	}
}
pub fn createDepthResources() void
{
	const imageInfo = VulkanInclude.VkImageCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
		.imageType = VulkanInclude.VK_IMAGE_TYPE_2D,
		.extent = VulkanInclude.VkExtent3D
		{
			.width = WindowGlobalState._windowExtent.width,
			.height = WindowGlobalState._windowExtent.height,
			.depth = 1,
		},
		.mipLevels = 1,
		.arrayLayers = 1,
		.format = VulkanGlobalState._depthFormat,
		.tiling = VulkanInclude.VK_IMAGE_TILING_OPTIMAL,
		.initialLayout = VulkanInclude.VK_IMAGE_LAYOUT_UNDEFINED,
		.usage = VulkanInclude.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
		.samples = VulkanInclude.VK_SAMPLE_COUNT_1_BIT,
		.sharingMode = VulkanInclude.VK_SHARING_MODE_EXCLUSIVE,
	};
	VK_CHECK(VulkanInclude.vkCreateImage(VulkanGlobalState._device, &imageInfo, null, &VulkanGlobalState._depthImage));
//VkImage.createVkImage(WindowGlobalState._windowExtent.width, WindowGlobalState._windowExtent.height, VulkanGlobalState._depthFormat, VulkanInclude.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, &VulkanGlobalState._depthImage);
	var memRequirements: VulkanInclude.VkMemoryRequirements = undefined;
	VulkanInclude.vkGetImageMemoryRequirements(VulkanGlobalState._device, VulkanGlobalState._depthImage, &memRequirements);

	VkDeviceMemory.createVkDeviceMemory(memRequirements, VulkanInclude.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &VulkanGlobalState._depthDeviceMemory);

	VK_CHECK(VulkanInclude.vkBindImageMemory(VulkanGlobalState._device, VulkanGlobalState._depthImage, VulkanGlobalState._depthDeviceMemory, 0));
	VkImage.createVkImageView(1, VulkanGlobalState._depthImage, VulkanGlobalState._depthFormat, VulkanInclude.VK_IMAGE_ASPECT_DEPTH_BIT, &VulkanGlobalState._depthImageView);
}
pub fn destroyDepthResources() void
{
	VulkanInclude.vkDestroyImageView(VulkanGlobalState._device, VulkanGlobalState._depthImageView, null);
	VulkanInclude.vkDestroyImage(VulkanGlobalState._device, VulkanGlobalState._depthImage, null);
	VulkanInclude.vkFreeMemory(VulkanGlobalState._device, VulkanGlobalState._depthDeviceMemory, null);
}
pub fn destroyVkSwapchainKHR() void
{
	var i: usize = 0;
	while(i < VulkanGlobalState._swapchainImagesCount)
	{
		VulkanInclude.vkDestroyImageView(VulkanGlobalState._device, VulkanGlobalState._swapchainImageViews[i], null);
		i+=1;
	}
    VulkanInclude.vkDestroySwapchainKHR(VulkanGlobalState._device, VulkanGlobalState._swapchain, null);
//     c.free(@ptrCast(@alignCast(VulkanGlobalState._swapchainImages)));
//     c.free(@ptrCast(@alignCast(VulkanGlobalState._swapchainImageViews)));
}
pub inline fn recreateVkSwapchainKHR() void
{
	_ = VulkanInclude.vkDeviceWaitIdle(VulkanGlobalState._device);
	destroyDepthResources();
	destroyVkSwapchainKHR();
	createVkSwapchainKHR();
	createDepthResources();
}
