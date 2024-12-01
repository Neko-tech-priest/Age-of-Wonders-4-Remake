const std = @import("std");
const c = std.c;
const mem = std.mem;
const print = std.debug.print;
// const linux = std.os.linux;

const SDL = @import("SDL.zig");

const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");
const VulkanFunctionsLoader = @import("VulkanFunctionsLoader.zig");

const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;
const WindowGlobalState = @import("WindowGlobalState.zig");

const validationLayers = [_][]const u8{"VK_LAYER_KHRONOS_validation"};
const deviceExtensions = [_][*:0]const u8
{
	"VK_KHR_swapchain",
	"VK_EXT_descriptor_indexing",
	"VK_KHR_dynamic_rendering",
};

fn debugCallback(messageSeverity: VulkanInclude.VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: VulkanInclude.VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: [*c]const VulkanInclude.VkDebugUtilsMessengerCallbackDataEXT, pUserData: ?*anyopaque) callconv(.C) VulkanInclude.VkBool32
{
	_ = messageSeverity;
	_ = messageType;
	_ = pUserData;
	print("validation layer: {s}\n", .{pCallbackData.*.pMessage});
	return VulkanInclude.VK_FALSE;
}
pub inline fn initBaseVulkan() void
{
	VulkanInclude.vkGetInstanceProcAddr = @ptrCast(SDL.SDL_Vulkan_GetVkGetInstanceProcAddr());
	VulkanFunctionsLoader.loadBaseFunctions();

	if(VulkanGlobalState.enableValidationLayers)
	{
		var layerCount: u32 = undefined;
		_ = VulkanInclude.vkEnumerateInstanceLayerProperties(&layerCount, 0);
		const availableLayers: [*]VulkanInclude.VkLayerProperties = (globalState.arenaAllocator.alloc(VulkanInclude.VkLayerProperties, layerCount) catch unreachable).ptr;
		_ = VulkanInclude.vkEnumerateInstanceLayerProperties(&layerCount, @ptrCast(availableLayers));
		for(validationLayers) |requiredLayer|
		{
			std.debug.print("{s}\n", .{requiredLayer});
			var layerFound: bool = false;
			for(availableLayers[0..layerCount]) |availableLayer|
			{
				if(mem.eql(u8, requiredLayer, availableLayer.layerName[0..requiredLayer.len]))
				{
					layerFound = true;
					break;
				}
			}
			if (!layerFound)
			{
				print("validation layers requested, but not available!\n", .{});
				std.process.exit(0);
			}
		}
	}
	var usedNumberOfInstanceExtensions: u32 = 2;
// //_ = SDL.SDL_Vulkan_GetInstanceExtensions(_window, &usedNumberOfInstanceExtensions, 0);
// //const requiredExtensions: [][*:0]const u8 = try allocator.alloc([*:0]const u8, usedNumberOfInstanceExtensions);
// //defer allocator.free(requiredExtensions);
	var requiredExtensions: [3][*:0]const u8 = undefined;
// //const x: [*c][*c]const u8 = &requiredExtensions;
	_ = SDL.SDL_Vulkan_GetInstanceExtensions(WindowGlobalState._window, &usedNumberOfInstanceExtensions, @ptrCast(&requiredExtensions));
	if(VulkanGlobalState.enableValidationLayers)
	{
		requiredExtensions[usedNumberOfInstanceExtensions] = "VK_EXT_debug_utils";
		usedNumberOfInstanceExtensions+=1;
	}

	const appInfo = VulkanInclude.VkApplicationInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_APPLICATION_INFO,
		.apiVersion = VulkanInclude.VK_API_VERSION_1_2,
	};

	var instanseCreateInfo = VulkanInclude.VkInstanceCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		.pApplicationInfo = &appInfo,

		.enabledExtensionCount = usedNumberOfInstanceExtensions,
		.ppEnabledExtensionNames = @ptrCast(&requiredExtensions),
	};

	var debugCreateInfo = VulkanInclude.VkDebugUtilsMessengerCreateInfoEXT{};


	if (VulkanGlobalState.enableValidationLayers)
	{
		instanseCreateInfo.enabledLayerCount = validationLayers.len;
		instanseCreateInfo.ppEnabledLayerNames = @ptrCast(&validationLayers);


		debugCreateInfo.sType = VulkanInclude.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
		debugCreateInfo.messageSeverity = VulkanInclude.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | VulkanInclude.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | VulkanInclude.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
		debugCreateInfo.messageType = VulkanInclude.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | VulkanInclude.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | VulkanInclude.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
		debugCreateInfo.pfnUserCallback = debugCallback;

		instanseCreateInfo.pNext = &debugCreateInfo;
	} else
	{
		instanseCreateInfo.enabledLayerCount = 0;
		instanseCreateInfo.pNext = null;
	}
	VK_CHECK(VulkanInclude.vkCreateInstance(&instanseCreateInfo, 0, &VulkanGlobalState._instance));
	VulkanFunctionsLoader.loadInstanceFunctions();
// linux.exit(-1);
	if (VulkanGlobalState.enableValidationLayers)
		VK_CHECK(VulkanInclude.vkCreateDebugUtilsMessengerEXT(VulkanGlobalState._instance, &debugCreateInfo, 0, &VulkanGlobalState._debugMessenger));
	if (SDL.SDL_Vulkan_CreateSurface(WindowGlobalState._window, @ptrCast(VulkanGlobalState._instance), @ptrCast(&VulkanGlobalState._surface)) == 0)
	{
		print("failed to create window surface!\n", .{});
		std.process.exit(0);
	}
	var physicaldeviceCount: u32 = undefined;
	_ = (VulkanInclude.vkEnumeratePhysicalDevices(VulkanGlobalState._instance, &physicaldeviceCount, null));
// print("{d}\n", .{physicaldeviceCount});
//     if (physicaldeviceCount == 0)
//     {
//         print("failed to find GPUs with Vulkan support!\n", .{});
//         std.process.exit(0);
//     }
    var physicalDevices: [2]VulkanInclude.VkPhysicalDevice = undefined;
    _ = (VulkanInclude.vkEnumeratePhysicalDevices(VulkanGlobalState._instance, &physicaldeviceCount, @ptrCast(&physicalDevices)));
    // підтримувані розширення
    var extensionProperties: [*]VulkanInclude.VkExtensionProperties = undefined;
    var extensionCount: u32 = undefined;
//     // підтримувані сімейства черг
    var queueFamiliesProperties: [*]VulkanInclude.VkQueueFamilyProperties = undefined;
    var queueFamilyCount: u32 = undefined;
    for(physicalDevices[0..physicaldeviceCount]) |physicalDevice|
    {
		// отримання відомостей про пристрій
		VulkanInclude.vkGetPhysicalDeviceProperties(physicalDevice, &VulkanGlobalState._deviceProperties);
		VulkanInclude.vkGetPhysicalDeviceFeatures(physicalDevice, &VulkanGlobalState._deviceFeatures);

        _ = VulkanInclude.vkEnumerateDeviceExtensionProperties(physicalDevice, null, &extensionCount, null);
        extensionProperties = (globalState.arenaAllocator.alloc(VulkanInclude.VkExtensionProperties, extensionCount) catch unreachable).ptr;
		_ = VulkanInclude.vkEnumerateDeviceExtensionProperties(physicalDevice, null, &extensionCount, extensionProperties);

		// перевірка на підтримку необхідних розширень пристрою
		var extensionFound: bool = undefined;
		for(deviceExtensions) |deviceExtension|
		{
			extensionFound = false;
			for(extensionProperties[0..extensionCount]) |availableExtension|
			{
				var len: usize = 0;
				while(availableExtension.extensionName[len] != 0)
					len+=1;
				if(mem.eql(u8, deviceExtension[0..len], availableExtension.extensionName[0..len]))
				{
					extensionFound = true;
                    break;
				}
			}
			if(!extensionFound)
            {
                print("Extension not found: {s}\n", .{deviceExtension});
                break;
            }
		}
		if(!extensionFound)
        {
            continue;
        }
        // перевірка підтримки потрібних фіч
		VulkanInclude.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, null);
		queueFamiliesProperties = (globalState.arenaAllocator.alloc(VulkanInclude.VkQueueFamilyProperties, queueFamilyCount) catch unreachable).ptr;
		VulkanInclude.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, queueFamiliesProperties);

		// перевірка на наявність потрібного сімейства черг
		var checkQueueFamily: bool = false;
		var indexQueueFamily: u32 = 0;
		while(indexQueueFamily < queueFamilyCount)
		{
			if(queueFamiliesProperties[indexQueueFamily].queueFlags & VulkanInclude.VK_QUEUE_GRAPHICS_BIT > 0)
			{
				var presentSupport: u32 = 0;//VulkanInclude.VkBool32
				_ = VulkanInclude.vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, indexQueueFamily, VulkanGlobalState._surface, &presentSupport);
				if(presentSupport > 0)
                {
                    checkQueueFamily = true;
                    VulkanGlobalState._graphicsQueueFamily = indexQueueFamily;
                    break;
                }
			}
			indexQueueFamily+=1;
		}
		if(!checkQueueFamily)
        {
            continue;
        }
        VulkanGlobalState._physicalDevice = physicalDevice;
        print("gpu: {s}\n", .{VulkanGlobalState._deviceProperties.deviceName});
        if(VulkanGlobalState._deviceProperties.deviceType == VulkanInclude.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU)
            break;
    }
    if(VulkanGlobalState._physicalDevice == null)
    {
        print("failed to find suidable device!\n", .{});
        std.process.exit(0);
    }
    // завантаження певних глобальних відомостей про пристрій
    VulkanInclude.vkGetPhysicalDeviceMemoryProperties(VulkanGlobalState._physicalDevice, &VulkanGlobalState._memoryProperties);
    // створення однієї графічної черги
	const queuePriority: f32 = 1.0;
    const queueCreateInfo = VulkanInclude.VkDeviceQueueCreateInfo
    {
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
		.queueFamilyIndex = VulkanGlobalState._graphicsQueueFamily,
		.queueCount = 1,
		.pQueuePriorities = &queuePriority,
    };

    // активація фіч
    var VkPD_Features2 = VulkanInclude.VkPhysicalDeviceFeatures2
    {
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
		.features = VulkanInclude.VkPhysicalDeviceFeatures
		{
			.samplerAnisotropy = VulkanInclude.VK_TRUE,
		},
    };
    var PhysicalDeviceDynamicRenderingFeaturesKHR = VulkanInclude.VkPhysicalDeviceDynamicRenderingFeaturesKHR
    {
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES_KHR,
		.dynamicRendering = VulkanInclude.VK_TRUE,
    };
    VkPD_Features2.pNext = @ptrCast(&PhysicalDeviceDynamicRenderingFeaturesKHR);

    const deviceCreateInfo = VulkanInclude.VkDeviceCreateInfo
    {
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		.pNext = &VkPD_Features2,
		.pQueueCreateInfos = &queueCreateInfo,
		.queueCreateInfoCount = 1,

		.enabledExtensionCount = deviceExtensions.len,
		.ppEnabledExtensionNames = (&deviceExtensions),
    };
	print("{s}{d}\n", .{"device extensions: ", deviceExtensions.len});
    VK_CHECK(VulkanInclude.vkCreateDevice(VulkanGlobalState._physicalDevice, &deviceCreateInfo, null, &VulkanGlobalState._device));
    VulkanFunctionsLoader.loadDeviceFunctions();
    VulkanInclude.vkGetDeviceQueue(VulkanGlobalState._device, VulkanGlobalState._graphicsQueueFamily, 0, &VulkanGlobalState._graphicsQueue);
}
pub inline fn deinitBaseVulkan() void
{
	VulkanInclude.vkDestroySurfaceKHR(VulkanGlobalState._instance, VulkanGlobalState._surface, null);
	VulkanInclude.vkDestroyDevice(VulkanGlobalState._device, null);
	if (VulkanGlobalState.enableValidationLayers)
		VulkanInclude.vkDestroyDebugUtilsMessengerEXT(VulkanGlobalState._instance, VulkanGlobalState._debugMessenger, 0);
	VulkanInclude.vkDestroyInstance(VulkanGlobalState._instance, 0);
}
