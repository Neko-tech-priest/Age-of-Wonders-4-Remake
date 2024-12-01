const std = @import("std");
const print = std.debug.print;

// const include = @import("include.zig").include;
const VulkanInclude = @import("VulkanInclude.zig");
pub const enableValidationLayers: bool = std.debug.runtime_safety;// std.debug.runtime_safety

pub const FRAME_OVERLAP: comptime_int = 1;

pub var _instance: VulkanInclude.VkInstance = undefined;
pub var _debugMessenger: VulkanInclude.VkDebugUtilsMessengerEXT = undefined;
pub var _physicalDevice: VulkanInclude.VkPhysicalDevice = null;
pub var _device: VulkanInclude.VkDevice = undefined;
pub var _graphicsQueue: VulkanInclude.VkQueue = undefined;
pub var _graphicsQueueFamily: u32 = undefined;

pub var _commandPool: VulkanInclude.VkCommandPool = undefined;
pub var _commandBuffers: [FRAME_OVERLAP]VulkanInclude.VkCommandBuffer = undefined;

pub var _presentSemaphores: [FRAME_OVERLAP]VulkanInclude.VkSemaphore = undefined;
pub var _renderSemaphores: [FRAME_OVERLAP]VulkanInclude.VkSemaphore = undefined;
pub var _renderFences: [FRAME_OVERLAP]VulkanInclude.VkFence = undefined;

pub var _surface: VulkanInclude.VkSurfaceKHR = undefined;
pub var _swapchain: VulkanInclude.VkSwapchainKHR = undefined;
pub var _swapchainImages: [3]VulkanInclude.VkImage = undefined;
pub var _swapchainImageViews: [3]VulkanInclude.VkImageView = undefined;
pub var _swapchainImageFormat: c_uint = VulkanInclude.VK_FORMAT_B8G8R8A8_SRGB;
pub var _swapchainImagesCount: u32 = 0;

pub var _depthFormat: VulkanInclude.VkFormat = VulkanInclude.VK_FORMAT_D32_SFLOAT;
pub var _depthImage: VulkanInclude.VkImage = undefined;
pub var _depthImageView: VulkanInclude.VkImageView = undefined;
pub var _depthDeviceMemory: VulkanInclude.VkDeviceMemory = undefined;

pub var _textureSampler: VulkanInclude.VkSampler = undefined;

pub var _deviceProperties: VulkanInclude.VkPhysicalDeviceProperties = undefined;
pub var _deviceFeatures: VulkanInclude.VkPhysicalDeviceFeatures = undefined;

pub var _memoryProperties: VulkanInclude.VkPhysicalDeviceMemoryProperties = undefined;

// const VK_CHECK_string = "Detected Vulkan error: ";
pub fn VK_CHECK(err: VulkanInclude.VkResult) void
{
    if (err != 0)
    {
        print("Detected Vulkan error: {d}\n", .{err});
        // print("{s}{d}\n", .{VK_CHECK_string, err});
        std.c.exit(-1);
    }
}
