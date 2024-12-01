const std = @import("std");
const mem = std.mem;
const c = std.c;
const print = std.debug.print;
const exit = std.process.exit;

const SDL = @import("SDL.zig");
const VulkanInclude = @import("VulkanInclude.zig");

const globalState = @import("globalState.zig");
const WindowGlobalState = @import("WindowGlobalState.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;

const customMem = @import("customMem.zig");
const memcpy = customMem.memcpy;
const memcmp = customMem.memcmp;

const algebra = @import("algebra.zig");

const VkBuffer = @import("VkBuffer.zig");
const VkImage = @import("VkImage.zig");

const initBaseVulkan = @import("initBaseVulkan.zig");
const VkSwapchainKHR = @import("VkSwapchainKHR.zig");
const initVulkan = @import("initVulkan.zig");

const camera = @import("camera.zig");
const Image = @import("Image.zig");
// const AoW3 = @import("AoW3.zig");
const AoW4 = @import("AoW4.zig");
// const AoW3_clb_importer = @import("AoW3_clb_importer.zig");
// const AoW4_clb_importer = @import("AoW4_clb_importer.zig");
const AoW4_clb_custom = @import("AoW4_clb_custom.zig");
const AoW4_clb_customImporter = @import("AoW4_clb_customImporter.zig");

const clb = @import("clb.zig");

pub fn main() !void
{
    globalState.arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer globalState.arena.deinit();
    globalState.arenaAllocator = globalState.arena.allocator();
// globalState.gpaAllocator = globalState.gpa.allocator();
// defer _ = globalState.gpa.deinit();

//     const argv = std.os.argv;
//     std.debug.print("{s}\n", .{argv[0]});

    _ = SDL.SDL_Init(SDL.SDL_INIT_VIDEO);
    defer _ = SDL.SDL_Quit();
//
    WindowGlobalState._window = SDL.SDL_CreateWindow(
        "Vulkan Engine",
        SDL.SDL_WINDOWPOS_UNDEFINED,
        SDL.SDL_WINDOWPOS_UNDEFINED,
        //512, 512,
        @intCast(WindowGlobalState._windowExtent.width),
        @intCast(WindowGlobalState._windowExtent.height),
        WindowGlobalState._window_flags
    );
    defer _ = SDL.SDL_DestroyWindow(WindowGlobalState._window);

    initBaseVulkan.initBaseVulkan();
    defer initBaseVulkan.deinitBaseVulkan();
    VkSwapchainKHR.createVkSwapchainKHR();
    defer VkSwapchainKHR.destroyVkSwapchainKHR();
    VkSwapchainKHR.createDepthResources();
    defer VkSwapchainKHR.destroyDepthResources();
    initVulkan.init_commands();
    defer VulkanInclude.vkDestroyCommandPool(VulkanGlobalState._device, VulkanGlobalState._commandPool, null);
    initVulkan.init_sync_structures();
    defer initVulkan.deinit_sync_structures();
    initVulkan.createTextureSampler();
    defer VulkanInclude.vkDestroySampler(VulkanGlobalState._device, VulkanGlobalState._textureSampler, null);
    camera.createCameraBuffers();
    defer camera.destroyCameraBuffers();
    camera.createCameraVkDescriptorSetLayout();
    defer VulkanInclude.vkDestroyDescriptorSetLayout(VulkanGlobalState._device, camera._cameraDescriptorSetLayout, null);
    camera.createCameraVkDescriptorPool();
    defer VulkanInclude.vkDestroyDescriptorPool(VulkanGlobalState._device, camera._cameraDescriptorPool, null);
    camera.createCameraVkDescriptorSets();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arenaAllocator = arena.allocator();
    // Age of Wonders 4

    // Figure_Skin
        // Penguin_Skin
        // Succubus_Skin
    // Strategic
        // SilvertongueFruit_Strategic
        // FireforgeStone_Strategic
        // Spawner_Dragons_Strategic
        // Spawner_Graveyard_Strategic
        // Spawner_Large_Monster_Strategic
        // Spawner_Ritual_Strategic
        // Spawner_Small_Monster_Strategic
        // Terrain_Shared_Void_Strategic
        // Terrain_Textures_Strategic
        // Terrain
            // Foam
            // Terrain_Shared_LavaCoasts_Strategic
    // Tactical
        // Terrain_Textures_Tactical
    var textures: [*]clb.Texture = undefined;
    var texturesVkDeviceMemory: VulkanInclude.VkDeviceMemory = undefined;
    var texturessCount: u64 = undefined;
    
    var meshes: [*]clb.Mesh = undefined;
    var meshesVerticesVkDeviceMemory: VulkanInclude.VkDeviceMemory = undefined;
    var meshesIndicesVkDeviceMemory: VulkanInclude.VkDeviceMemory = undefined;
    var meshesCount: u64 = undefined;
    
    var modelsCount: u64 = undefined;
    var materialsCount: u64 = undefined;
//     print("{d}\n", .{@sizeOf(VulkanInclude.VkBufferImageCopy)});
    clb.load(arenaAllocator, "Age of Wonders 4 Ways of War/Content/Title/Libraries/Strategic/Spawner_Large_Monster_Strategic.clb", &textures, &texturesVkDeviceMemory, &texturessCount, &meshes, &meshesVerticesVkDeviceMemory, &meshesIndicesVkDeviceMemory, &meshesCount, &modelsCount, &materialsCount);
    defer if(texturessCount > 0)
    {
        for(0..texturessCount) |i|
        textures[i].unload();
        defer VulkanInclude.vkFreeMemory(VulkanGlobalState._device, texturesVkDeviceMemory, null);
    };
    defer if(meshesCount > 0)
    {
        for(0..meshesCount) |i|
            meshes[i].unload();
        VulkanInclude.vkFreeMemory(VulkanGlobalState._device, meshesVerticesVkDeviceMemory, null);
        VulkanInclude.vkFreeMemory(VulkanGlobalState._device, meshesIndicesVkDeviceMemory, null);
    };
//     defer VulkanInclude.vkFreeMemory(VulkanGlobalState._device, texturesVkDeviceMemory, null);
//     var AoW4_models_temp: [*]AoW4_clb_importer.Model_temp = undefined;
//     var AoW4_modelsCount: u32 = 0;
    
// var AoW4_meshes_temp: [*]AoW4_clb_customImporter.Mesh_data = undefined;
// var AoW4_meshes: [*]AoW4.Mesh = undefined;
// var AoW4_meshesCount: usize = 0;
// var AoW4_meshes_vertexVkDeviceMemory: VulkanInclude.VkDeviceMemory = null;
// var AoW4_meshes_indexVkDeviceMemory: VulkanInclude.VkDeviceMemory = null;
// defer VulkanInclude.vkFreeMemory(VulkanGlobalState._device, AoW4_meshes_vertexVkDeviceMemory, null);
// defer VulkanInclude.vkFreeMemory(VulkanGlobalState._device, AoW4_meshes_indexVkDeviceMemory, null);
// 
// var AoW4_images_temp: [*]AoW4_clb_customImporter.Texture_data = undefined;
// var AoW4_images: [*]AoW4.DiffuseMaterial = undefined;
// var AoW4_imagesCount: usize = 0;
// var AoW4_images_VkDeviceMemory: VulkanInclude.VkDeviceMemory = null;
// defer VulkanInclude.vkFreeMemory(VulkanGlobalState._device, AoW4_images_VkDeviceMemory, null);
// 
// //     var AoW4_materials_temp: [*]AoW4_clb_importer.Material_temp = undefined;
// //     var AoW4_materialsCount: u32 = 0;
// 
// var AoW4_imagesDescriptorSetLayout: VulkanInclude.VkDescriptorSetLayout = undefined;
// var AoW4_imagesDescriptorPool: VulkanInclude.VkDescriptorPool = undefined;
// 
// var AoW4_P3N3U2C4T3_Pipeline: VulkanInclude.VkPipeline = null;
// var AoW4_P3N3U2C4T3_PipelineLayout: VulkanInclude.VkPipelineLayout = null;
// 
// var AoW4_models: [*]AoW4_clb_customImporter.Model_data = undefined;
// var AoW4_modelsCount: u64 = undefined;
// // var AoW4_modelIndex: i64 = 0;
// var AoW4_meshIndex: i64 = 0;
// // AoW4_meshIndex = 0;
// var AoW4_imageIndex: i64 = 0;
// //     var AoW4_materialIndex: i64 = 0;
// try AoW4_clb_custom.clb_convert("Age of Wonders 4/Content/Title/Libraries/Strategic/Spawner_Large_Monster_Strategic.clb");
// var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
// defer arena.deinit();
// const arenaAllocator = arena.allocator();
// try AoW4_clb_customImporter.clb_custom_read(arenaAllocator, "clb_custom.raw", &AoW4_images_temp, &AoW4_imagesCount, &AoW4_meshes_temp, &AoW4_meshesCount, &AoW4_models, &AoW4_modelsCount);
// AoW4_meshIndex = AoW4_models[0].meshesIndices[0];
	
	
	
// while(AoW4_imageIndex < AoW4_imagesCount) : (AoW4_imageIndex+=1)
	// if(mem.eql(u8, AoW4_materials[0].DiffuseTexture[0..AoW4_materials[0].DiffuseTextureLen], AoW4_images_temp[@intCast(AoW4_imageIndex)].name[0..AoW4_materials[0].DiffuseTextureLen]))
		// if(AoW4_materials[0].DiffuseTexture == AoW4_images_temp[@intCast(AoW4_imageIndex)].name)
		// break;
// print("{s}\n", .{AoW4_materials[0].DiffuseTexture[0..28]});
// print("{s}\n", .{AoW4_images_temp[3].name[0..28]});
// print("imageIndex: {d}\n", .{AoW4_imageIndex});

// print("AoW4 image:\n", .{});
// print("width: {d}\n", .{AoW4_images[0].width});
// print("height: {d}\n", .{AoW4_images[0].height});
// AoW3_images[0] = AoW4_images[0];
// var squareVertices: [4][48]u8 = undefined;
// mem.bytesAsValue([3]f32, &squareVertices[0][0]).* = [3]f32{-1, -1, 0};
// mem.bytesAsValue([3]f32, &squareVertices[1][0]).* = [3]f32{1, -1, 0};
// mem.bytesAsValue([3]f32, &squareVertices[2][0]).* = [3]f32{1, 1, 0};
// mem.bytesAsValue([3]f32, &squareVertices[3][0]).* = [3]f32{-1, 1, 0};
//
// mem.bytesAsValue([2]f32, &squareVertices[0][24]).* = [2]f32{0, 0};
// mem.bytesAsValue([2]f32, &squareVertices[1][24]).* = [2]f32{1, 0};
// mem.bytesAsValue([2]f32, &squareVertices[2][24]).* = [2]f32{1, 1};
// mem.bytesAsValue([2]f32, &squareVertices[3][24]).* = [2]f32{0, 1};
// const PNUT_Vertex align(48) = packed struct
// {
// position: [3]f32,
// normal: [3]f32,
// UV: [2]f32,
// };
// const squareVertices = [4]PNUT_Vertex
// {
// .{
// .position = [3]f32{-1, -1, 0},
// .UV = [2]f32{0, 0},
// },
// .{
// .position = [3]f32{1, -1, 0},
// .UV = [2]f32{1, 0},
// },
// .{
// .position = [3]f32{1, 1, 0},
// .UV = [2]f32{1, 1},
// },
// .{
// .position = [3]f32{-1, 1, 0},
// .UV = [2]f32{0, 1},
// },
// };
// const squareIndices = [6]u16{0, 1, 2, 2, 3, 0};
// AoW3_meshes[0].verticesBuffer = @ptrCast(&squareVertices);
// AoW3_meshes[0].verticesBufferSize = 48*4;
// AoW3_meshes[0].indicesBuffer = @ptrCast(@constCast(&squareIndices));
// AoW3_meshes[0].indicesBufferSize = 2*6;
// _ = globalState.arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);
// AoW3_meshes_GPU = @ptrCast(@alignCast((c.malloc(AoW3_meshesCount*@sizeOf(AoW3.Mesh_GPU)))));
// defer c.free(@ptrCast(@alignCast(AoW3_meshes_GPU)));
    
    
    
    
// AoW4_meshes = @ptrCast(@alignCast((c.malloc(AoW4_meshesCount*@sizeOf(AoW4.Mesh)))));
// defer c.free(@ptrCast(@alignCast(AoW4_meshes)));
// @memset(AoW4_meshes[0..AoW4_meshesCount], .{.vertexVkBuffer = null, .indexVkBuffer = null, .indicesCount = 0});
// if(AoW4_meshesCount > 0)
// {
//     VkBuffer.createVkBuffers__VkDeviceMemory_AoS(VulkanInclude.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, @as([*]u8, @ptrCast(@alignCast(AoW4_meshes_temp)))+0,  @sizeOf(AoW4_clb_customImporter.Mesh_data), @offsetOf(AoW4_clb_customImporter.Mesh_data, "verticesBufferSize"), @ptrCast(@alignCast(AoW4_meshes)),  @sizeOf(AoW4.Mesh), AoW4_meshesCount, &AoW4_meshes_vertexVkDeviceMemory);
// // std.process.exit(0);
//     VkBuffer.createVkBuffers__VkDeviceMemory_AoS(VulkanInclude.VK_BUFFER_USAGE_INDEX_BUFFER_BIT, @as([*]u8, @ptrCast(@alignCast(AoW4_meshes_temp)))+8,  @sizeOf(AoW4_clb_customImporter.Mesh_data), @offsetOf(AoW4_clb_customImporter.Mesh_data, "indicesBufferSize")-8, @as([*]u8, @ptrCast(@alignCast(AoW4_meshes)))+8,  @sizeOf(AoW4.Mesh), AoW4_meshesCount, &AoW4_meshes_indexVkDeviceMemory);
// }
// defer for(AoW4_meshes[0..AoW4_meshesCount]) |mesh|
//     mesh.unload();
// AoW4_images = @ptrCast(@alignCast((c.malloc(AoW4_imagesCount*@sizeOf(AoW4.DiffuseMaterial)))));
// defer c.free(@ptrCast(@alignCast(AoW4_images)));
// VkImage.createVkImages__VkImageViews__VkDeviceMemory_AoS(@as([*]u8, @ptrCast(@alignCast(AoW4_images_temp)))+0, @sizeOf(AoW4_clb_customImporter.Texture_data), @ptrCast(@alignCast(AoW4_images)), @sizeOf(AoW4.DiffuseMaterial), AoW4_imagesCount, &AoW4_images_VkDeviceMemory);
// //     std.process.exit(0);
// defer for(AoW4_images[0..AoW4_imagesCount]) |image|
//     image.unload();
// AoW4.Create_DiffuseMaterial_VkDescriptorSetLayout(&AoW4_imagesDescriptorSetLayout);
// defer VulkanInclude.vkDestroyDescriptorSetLayout(VulkanGlobalState._device, AoW4_imagesDescriptorSetLayout, null);
// AoW4.Create_DiffuseMaterial_VkDescriptorPool(&AoW4_imagesDescriptorPool, @intCast(AoW4_imagesCount));
// defer VulkanInclude.vkDestroyDescriptorPool(VulkanGlobalState._device, AoW4_imagesDescriptorPool, null);
// 
// for(AoW4_images[0..AoW4_imagesCount]) |*image|
//     image.Create_DiffuseMaterial_VkDescriptorSet(AoW4_imagesDescriptorSetLayout, AoW4_imagesDescriptorPool);
// 
// try AoW4.Create_P3N3U2C4T3_Pipeline(AoW4_imagesDescriptorSetLayout, &AoW4_P3N3U2C4T3_PipelineLayout, &AoW4_P3N3U2C4T3_Pipeline);
// defer
// {
//     VulkanInclude.vkDestroyPipeline(VulkanGlobalState._device, AoW4_P3N3U2C4T3_Pipeline, null);
//     VulkanInclude.vkDestroyPipelineLayout(VulkanGlobalState._device, AoW4_P3N3U2C4T3_PipelineLayout, null);
// }

	var e: SDL.SDL_Event = undefined;
	var bQuit: bool = false;
    bQuit = true;
	var windowPresent: bool = true;

	var currentFrame: usize = 0;
// var swapchainImageIndex: u32 = undefined;
	while (!bQuit)
	{
		//Handle events on queue
		while (SDL.SDL_PollEvent(&e) != 0)
		{
			switch(e.type)
			{
				SDL.SDL_QUIT =>
				{
					bQuit = true;
				},
				SDL.SDL_WINDOWEVENT =>
				{
					switch(e.window.event)
					{
						SDL.SDL_WINDOWEVENT_SHOWN =>
						{
							windowPresent = true;
						},
						SDL.SDL_WINDOWEVENT_HIDDEN =>
						{
							windowPresent = false;
						},
						else =>{}
					}
				},
				SDL.SDL_KEYDOWN =>
				{
					switch(e.key.keysym.scancode)
					{
						// камера
						SDL.SDL_SCANCODE_D =>
						{
							camera.camera_translate_x+=0.5;
						},
						SDL.SDL_SCANCODE_A =>
						{
							camera.camera_translate_x-=0.5;
						},
						// Y
						SDL.SDL_SCANCODE_W =>
						{
							camera.camera_translate_z+=0.5;
						},
						SDL.SDL_SCANCODE_S =>
						{
							camera.camera_translate_z-=0.5;
						},
						// Z
						SDL.SDL_SCANCODE_E =>
						{
							camera.camera_translate_y+=0.5;
						},
						SDL.SDL_SCANCODE_Q =>
						{
							camera.camera_translate_y-=0.5;
						},
						SDL.SDL_SCANCODE_O =>
						{
							//AoW4_meshIndex-=1;
							//if(AoW4_meshIndex < 0)
								//AoW4_meshIndex = 0;
						},
						SDL.SDL_SCANCODE_P =>
						{
							//AoW4_meshIndex+=1;
							//if(AoW4_meshIndex == AoW4_meshesCount)
								//AoW4_meshIndex-=1;
						},
						SDL.SDL_SCANCODE_K =>
						{
							//AoW4_imageIndex-=1;
							//if(AoW4_imageIndex < 0)
								//AoW4_imageIndex = 0;
						},
						SDL.SDL_SCANCODE_L =>
						{
							//AoW4_imageIndex+=1;
							//if(AoW4_imageIndex == AoW4_imagesCount)
								//AoW4_imageIndex-=1;
						},
						// повороты
						SDL.SDL_SCANCODE_UP =>
						{
							camera.camera_rotate_x-=5;
						},
						SDL.SDL_SCANCODE_DOWN =>
						{
							camera.camera_rotate_x+=5;
						},
						SDL.SDL_SCANCODE_LEFT =>
						{
							camera.camera_rotate_z-=5;
						},
						SDL.SDL_SCANCODE_RIGHT =>
						{
							camera.camera_rotate_z+=5;
						},
						else =>{}
					}
				},
				else =>{}
			}
		}
		if (!windowPresent)//SDL_GetWindowFlags(_window) & SDL_WINDOW_MINIMIZED
		{
			SDL.SDL_Delay(50);
		}
		else
		{
			//wait until the gpu has finished rendering the last frame
			VK_CHECK(VulkanInclude.vkWaitForFences(VulkanGlobalState._device, 1, &VulkanGlobalState._renderFences[currentFrame], VulkanInclude.VK_TRUE, VulkanInclude.UINT64_MAX));
			//request image from the swapchain
			var swapchainImageIndex: u32 = undefined;
			var result: VulkanInclude.VkResult = undefined;
			//VK_CHECK
			result = (VulkanInclude.vkAcquireNextImageKHR(VulkanGlobalState._device, VulkanGlobalState._swapchain, VulkanInclude.UINT64_MAX, VulkanGlobalState._presentSemaphores[currentFrame], null, &swapchainImageIndex));
			if (result == VulkanInclude.VK_ERROR_OUT_OF_DATE_KHR)
			{
				VkSwapchainKHR.recreateVkSwapchainKHR();
			}
			else if (result != VulkanInclude.VK_SUCCESS and result != VulkanInclude.VK_SUBOPTIMAL_KHR)
			{
				print("failed to acquire swap chain image!\n", .{});
				std.process.exit(0);
			}
			camera.updateCameraBuffer(currentFrame);
			VK_CHECK(VulkanInclude.vkResetFences(VulkanGlobalState._device, 1, &VulkanGlobalState._renderFences[currentFrame]));
			//now that we are sure that the commands finished executing, we can safely reset the command buffer to begin recording again.
			VK_CHECK(VulkanInclude.vkResetCommandBuffer(VulkanGlobalState._commandBuffers[currentFrame], 0));
			//begin the command buffer recording. We will use this command buffer exactly once, so we want to let Vulkan know that
			const cmdBeginInfo = VulkanInclude.VkCommandBufferBeginInfo
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
				.flags = VulkanInclude.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
			};
			VK_CHECK(VulkanInclude.vkBeginCommandBuffer(VulkanGlobalState._commandBuffers[currentFrame], &cmdBeginInfo));
			const image_memory_barrierBegin = VulkanInclude.VkImageMemoryBarrier
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
				.dstAccessMask = VulkanInclude.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
				.oldLayout = VulkanInclude.VK_IMAGE_LAYOUT_UNDEFINED,
				.newLayout = VulkanInclude.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
				.image = VulkanGlobalState._swapchainImages[swapchainImageIndex],
				.subresourceRange = VulkanInclude.VkImageSubresourceRange
				{
					.aspectMask = VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT,
					.baseMipLevel = 0,
					.levelCount = 1,
					.baseArrayLayer = 0,
					.layerCount = 1,
				}
			};
			VulkanInclude.vkCmdPipelineBarrier(
				VulkanGlobalState._commandBuffers[currentFrame],
				VulkanInclude.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,  // srcStageMask
				VulkanInclude.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, // dstStageMask
				0,
				0,
				null,
				0,
				null,
				1, // imageMemoryBarrierCount
				&image_memory_barrierBegin // pImageMemoryBarriers
			);
			const clearValue = VulkanInclude.VkClearValue
			{
				.color = VulkanInclude.VkClearColorValue
				{
					.float32 = [4]f32{0.5, 0.5, 1.0, 1.0},
				},
			};
			const depthClear = VulkanInclude.VkClearValue
			{
				.depthStencil = VulkanInclude.VkClearDepthStencilValue
				{
					.depth = 1.0,
				}
			};
			const renderArea = VulkanInclude.VkRect2D
			{
				.offset = VulkanInclude.VkOffset2D{.x = 0, .y = 0},
				.extent = WindowGlobalState._windowExtent,
			};
			// VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL_KHR
			const colorAttachmentInfo = VulkanInclude.VkRenderingAttachmentInfoKHR
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR,
				.imageView = VulkanGlobalState._swapchainImageViews[swapchainImageIndex],
				.imageLayout = VulkanInclude.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
				.loadOp = VulkanInclude.VK_ATTACHMENT_LOAD_OP_CLEAR,
				.storeOp = VulkanInclude.VK_ATTACHMENT_STORE_OP_STORE,
				.clearValue = clearValue,
			};
			const depthAttachmentInfo = VulkanInclude.VkRenderingAttachmentInfoKHR
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR,
				.imageView = VulkanGlobalState._depthImageView,
				.imageLayout = VulkanInclude.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL,//VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
				.loadOp = VulkanInclude.VK_ATTACHMENT_LOAD_OP_CLEAR,
				.storeOp = VulkanInclude.VK_ATTACHMENT_STORE_OP_STORE,
				.clearValue = depthClear,
			};
			const renderInfo = VulkanInclude.VkRenderingInfoKHR
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_RENDERING_INFO_KHR,
				.renderArea = renderArea,
				.layerCount = 1,
				.colorAttachmentCount = 1,
				.pColorAttachments = &colorAttachmentInfo,
				.pDepthAttachment = &depthAttachmentInfo,
			};
			VulkanInclude.vkCmdBeginRenderingKHR(VulkanGlobalState._commandBuffers[currentFrame], &renderInfo);
			const viewport = VulkanInclude.VkViewport
			{
				.x = 0.0,
				.y = 0.0,
				.width = @floatFromInt(WindowGlobalState._windowExtent.width),
				.height = @floatFromInt(WindowGlobalState._windowExtent.height),
				.minDepth = 0.0,
				.maxDepth = 1.0,
			};
			VulkanInclude.vkCmdSetViewport(VulkanGlobalState._commandBuffers[currentFrame], 0, 1, &viewport);
			const scissor = VulkanInclude.VkRect2D
			{
				.offset = VulkanInclude.VkOffset2D{.x = 0, .y = 0},
				.extent = WindowGlobalState._windowExtent,
			};
			VulkanInclude.vkCmdSetScissor(VulkanGlobalState._commandBuffers[currentFrame], 0, 1, &scissor);

// VulkanInclude.vkCmdBindPipeline(VulkanGlobalState._commandBuffers[currentFrame], VulkanInclude.VK_PIPELINE_BIND_POINT_GRAPHICS, AoW4_P3N3U2C4T3_Pipeline);
// 
// const offsets = [_]VulkanInclude.VkDeviceSize{0};
// 
// VulkanInclude.vkCmdBindVertexBuffers(VulkanGlobalState._commandBuffers[currentFrame], 0, 1, &AoW4_meshes[@intCast(AoW4_meshIndex)].vertexVkBuffer, &offsets);
// VulkanInclude.vkCmdBindIndexBuffer(VulkanGlobalState._commandBuffers[currentFrame], AoW4_meshes[@intCast(AoW4_meshIndex)].indexVkBuffer, 0, VulkanInclude.VK_INDEX_TYPE_UINT16);
// 
// var descriptorSets: [2]VulkanInclude.VkDescriptorSet = undefined;
// descriptorSets[0] = camera._cameraDescriptorSets[currentFrame];
// descriptorSets[1] = AoW4_images[@intCast(AoW4_imageIndex)].descriptorSet;
// 
// VulkanInclude.vkCmdBindDescriptorSets(VulkanGlobalState._commandBuffers[currentFrame], VulkanInclude.VK_PIPELINE_BIND_POINT_GRAPHICS, AoW4_P3N3U2C4T3_PipelineLayout, 0, 2, &descriptorSets, 0, null);
// // VulkanInclude.vkCmdDrawIndexed(VulkanGlobalState._commandBuffers[currentFrame], AoW3_meshes[@intCast(AoW3_meshIndex)].indicesBufferSize>>1, 1, 0, 0, 0);
// VulkanInclude.vkCmdDrawIndexed(VulkanGlobalState._commandBuffers[currentFrame], AoW4_meshes_temp[@intCast(AoW4_meshIndex)].indicesBufferSize>>1, 1, 0, 0, 0);

			VulkanInclude.vkCmdEndRenderingKHR(VulkanGlobalState._commandBuffers[currentFrame]);

			const imageMemoryBarrierEnd = VulkanInclude.VkImageMemoryBarrier
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
				.srcAccessMask = VulkanInclude.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
				.oldLayout = VulkanInclude.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
				.newLayout = VulkanInclude.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
				.image = VulkanGlobalState._swapchainImages[swapchainImageIndex],
				.subresourceRange = VulkanInclude.VkImageSubresourceRange
				{
					.aspectMask = VulkanInclude.VK_IMAGE_ASPECT_COLOR_BIT,
					.baseMipLevel = 0,
					.levelCount = 1,
					.baseArrayLayer = 0,
					.layerCount = 1,
				}
			};
			VulkanInclude.vkCmdPipelineBarrier(
				VulkanGlobalState._commandBuffers[currentFrame],
				VulkanInclude.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,  // srcStageMask
				VulkanInclude.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, // dstStageMask
				0,
				0,
				null,
				0,
				null,
				1, // imageMemoryBarrierCount
				&imageMemoryBarrierEnd // pImageMemoryBarriers
			);
			//finalize the command buffer (we can no longer add commands, but it can now be executed)
			VK_CHECK(VulkanInclude.vkEndCommandBuffer(VulkanGlobalState._commandBuffers[currentFrame]));

			//prepare the submission to the queue.
			//we want to wait on the _presentSemaphores[_currentFrame], as that semaphore is signaled when the swapchain is ready
			//we will signal the _renderSemaphores[_currentFrame], to signal that rendering has finished

			//VkSemaphore waitSemaphores[] = _presentSemaphores[_currentFrame];
			var waitStage: u32 = VulkanInclude.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
			const submitInfo = VulkanInclude.VkSubmitInfo
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_SUBMIT_INFO,
				.pWaitDstStageMask = &waitStage,

				.waitSemaphoreCount = 1,
				.pWaitSemaphores = &VulkanGlobalState._presentSemaphores[currentFrame],

				.signalSemaphoreCount = 1,
				.pSignalSemaphores = &VulkanGlobalState._renderSemaphores[currentFrame],

				.commandBufferCount = 1,
				.pCommandBuffers = &VulkanGlobalState._commandBuffers[currentFrame],
			};
			//submit command buffer to the queue and execute it.
			// _renderFence will now block until the graphic commands finish execution
			VK_CHECK(VulkanInclude.vkQueueSubmit(VulkanGlobalState._graphicsQueue, 1, &submitInfo, VulkanGlobalState._renderFences[currentFrame]));

			// this will put the image we just rendered into the visible window.
			// we want to wait on the _renderSemaphores[_currentFrame] for that,
			// as it's necessary that drawing commands have finished before the image is displayed to the user
			const presentInfo = VulkanInclude.VkPresentInfoKHR
			{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,

				.pSwapchains = &VulkanGlobalState._swapchain,
				.swapchainCount = 1,

				.pWaitSemaphores = &VulkanGlobalState._renderSemaphores[currentFrame],
				.waitSemaphoreCount = 1,

				.pImageIndices = &swapchainImageIndex,
			};
			//VK_CHECK
			result = (VulkanInclude.vkQueuePresentKHR(VulkanGlobalState._graphicsQueue, &presentInfo));
			if (result == VulkanInclude.VK_ERROR_OUT_OF_DATE_KHR or result == VulkanInclude.VK_SUBOPTIMAL_KHR)
				VkSwapchainKHR.recreateVkSwapchainKHR();

			currentFrame+=1;
			if(currentFrame == VulkanGlobalState.FRAME_OVERLAP)
				currentFrame = 0;
		}
	}
	//make sure the gpu has stopped doing its things
	_ = VulkanInclude.vkDeviceWaitIdle(VulkanGlobalState._device);
}
