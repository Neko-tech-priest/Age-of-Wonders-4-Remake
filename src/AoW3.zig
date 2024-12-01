const std = @import("std");
const c = std.c;

const VulkanInclude = @import("VulkanInclude.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");
const VK_CHECK = VulkanGlobalState.VK_CHECK;
const VkPipeline = @import("VkPipeline.zig");

const camera = @import("camera.zig");
pub const Mesh = packed struct
{
	verticesBuffer: [*]u8 = undefined,
	indicesBuffer: [*]u8 = undefined,
	verticesBufferSize: u32 = undefined,
	indicesBufferSize: u32 = undefined,
};
pub const Mesh_GPU = packed struct
{
	vertexVkBuffer: VulkanInclude.VkBuffer = undefined,
	indexVkBuffer: VulkanInclude.VkBuffer = undefined,

	pub fn unload(self: Mesh_GPU) void
	{
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, self.vertexVkBuffer, null);
		VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, self.indexVkBuffer, null);
	}
};
pub const TerrainMaterial = packed struct
{
	textureVkImage: VulkanInclude.VkImage = undefined,
	textureVkImageView: VulkanInclude.VkImageView = undefined,

	descriptorSet: VulkanInclude.VkDescriptorSet = undefined,

	pub fn unload(self: TerrainMaterial) void
	{
		VulkanInclude.vkDestroyImage(VulkanGlobalState._device, self.textureVkImage, null);
		VulkanInclude.vkDestroyImageView(VulkanGlobalState._device, self.textureVkImageView, null);
	}
	pub fn Create_TerrainMaterial_VkDescriptorSet(self: *TerrainMaterial, descriptorSetLayout: VulkanInclude.VkDescriptorSetLayout, descriptorPool: VulkanInclude.VkDescriptorPool) void
	{
		const allocInfo = VulkanInclude.VkDescriptorSetAllocateInfo
		{
			.sType = VulkanInclude.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
			.descriptorPool = descriptorPool,
			.descriptorSetCount = 1,
			.pSetLayouts = &descriptorSetLayout,
		};

		VK_CHECK(VulkanInclude.vkAllocateDescriptorSets(VulkanGlobalState._device, &allocInfo, &self.descriptorSet));

		const textureInfo = VulkanInclude.VkDescriptorImageInfo
		{
			.imageLayout = VulkanInclude.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
			.imageView = self.textureVkImageView,
			.sampler = VulkanGlobalState._textureSampler,
		};

		const descriptorWrites = [1]VulkanInclude.VkWriteDescriptorSet
		{
			.{
				.sType = VulkanInclude.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
				.dstSet = self.descriptorSet,
				.dstBinding = 1,
				.dstArrayElement = 0,
				.descriptorType = VulkanInclude.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
				.descriptorCount = 1,
				.pImageInfo = &textureInfo,
			},
		};

		VulkanInclude.vkUpdateDescriptorSets(VulkanGlobalState._device, descriptorWrites.len, &descriptorWrites, 0, null);
	}
};

pub fn Create_TerrainMaterial_VkDescriptorSetLayout(descriptorSetLayout: *VulkanInclude.VkDescriptorSetLayout) void
{
	const descriptorSetLayoutBindings = [1]VulkanInclude.VkDescriptorSetLayoutBinding
	{
		.{
			.binding = 1,
			.descriptorCount = 1,
			.descriptorType = VulkanInclude.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			.pImmutableSamplers = null,
			.stageFlags = VulkanInclude.VK_SHADER_STAGE_FRAGMENT_BIT,
		},
	};
	const layoutInfo = VulkanInclude.VkDescriptorSetLayoutCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		.bindingCount = descriptorSetLayoutBindings.len,
		.pBindings = &descriptorSetLayoutBindings,
	};
	VK_CHECK(VulkanInclude.vkCreateDescriptorSetLayout(VulkanGlobalState._device, &layoutInfo, null, descriptorSetLayout));
}
pub fn Create_TerrainMaterial_VkDescriptorPool(descriptorPool: *VulkanInclude.VkDescriptorPool, texturesCount: u32) void
{
	const poolSizes = [1]VulkanInclude.VkDescriptorPoolSize
	{
		.{
			.type = VulkanInclude.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			.descriptorCount = texturesCount,
		},
	};

	const poolInfo = VulkanInclude.VkDescriptorPoolCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
		.poolSizeCount = poolSizes.len,
		.pPoolSizes = &poolSizes,
		.maxSets = texturesCount,
	};
//
	VK_CHECK(VulkanInclude.vkCreateDescriptorPool(VulkanGlobalState._device, &poolInfo, null, descriptorPool));
}

pub fn Create_PNUT_Pipeline(terrainDescriptorSetLayout: VulkanInclude.VkDescriptorSetLayout, pipelineLayout: *VulkanInclude.VkPipelineLayout, pipeline: *VulkanInclude.VkPipeline) !void
{
	const vertShaderModule: VulkanInclude.VkShaderModule = try VkPipeline.createShaderModule("shaders/AoW3_PNUT.vert.spv");
	const fragShaderModule: VulkanInclude.VkShaderModule = try VkPipeline.createShaderModule("shaders/AoW3_Diffuse.frag.spv");
	defer VulkanInclude.vkDestroyShaderModule(VulkanGlobalState._device, fragShaderModule, null);
	defer VulkanInclude.vkDestroyShaderModule(VulkanGlobalState._device, vertShaderModule, null);

	const shaderStages = [2]VulkanInclude.VkPipelineShaderStageCreateInfo
	{
		.{
			.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = VulkanInclude.VK_SHADER_STAGE_VERTEX_BIT,
			.module = vertShaderModule,
			.pName = "main",
		},
		.{
			.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = VulkanInclude.VK_SHADER_STAGE_FRAGMENT_BIT,
			.module = fragShaderModule,
			.pName = "main",
		}
	};

	const bindingDescriptions = [1]VulkanInclude.VkVertexInputBindingDescription
	{
		.{
			.binding = 0,
			.stride = 48,
			.inputRate = VulkanInclude.VK_VERTEX_INPUT_RATE_VERTEX,
		}
	};
	const attributeDescriptions = [2]VulkanInclude.VkVertexInputAttributeDescription
	{
		.{
			.binding = 0,
			.location = 0,
			.format = VulkanInclude.VK_FORMAT_R32G32B32_SFLOAT,
			.offset = 0,
		},
		.{
			.binding = 0,
			.location = 2,
			.format = VulkanInclude.VK_FORMAT_R32G32_SFLOAT,
			.offset = 24,
		},
	};

	const VertexInputState = VulkanInclude.VkPipelineVertexInputStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,

		.vertexBindingDescriptionCount = bindingDescriptions.len,
		.vertexAttributeDescriptionCount = attributeDescriptions.len,
		.pVertexBindingDescriptions = &bindingDescriptions,
		.pVertexAttributeDescriptions = &attributeDescriptions,
	};

	const InputAssemblyState = VulkanInclude.VkPipelineInputAssemblyStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		.topology = VulkanInclude.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
		.primitiveRestartEnable = VulkanInclude.VK_FALSE,
	};

	//VkPipelineTessellationStateCreateInfo TessellationState{};

	//make viewport state from our stored viewport and scissor.
	const ViewportState = VulkanInclude.VkPipelineViewportStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		.viewportCount = 1,
		//.pViewports = &_viewport;
		.scissorCount = 1,
		//.pScissors = &_scissor;
	};

	//configure the rasterizer to draw filled triangles
	const RasterizationState = VulkanInclude.VkPipelineRasterizationStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,

		.depthClampEnable = VulkanInclude.VK_FALSE,
		//discards all primitives before the rasterization stage if enabled which we don't want
		.rasterizerDiscardEnable = VulkanInclude.VK_FALSE,

		.polygonMode = VulkanInclude.VK_POLYGON_MODE_FILL,
		.lineWidth = 1.0,
		.cullMode = VulkanInclude.VK_CULL_MODE_NONE,
		.frontFace = VulkanInclude.VK_FRONT_FACE_CLOCKWISE,
		//no depth bias
		.depthBiasEnable = VulkanInclude.VK_FALSE,
		.depthBiasConstantFactor = 0.0,
		.depthBiasClamp = 0.0,
		.depthBiasSlopeFactor = 0.0,
	};

	//we dont use multisampling, so just run the default one
	const MultisampleState = VulkanInclude.VkPipelineMultisampleStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,

		.sampleShadingEnable = VulkanInclude.VK_FALSE,
		.rasterizationSamples = VulkanInclude.VK_SAMPLE_COUNT_1_BIT,
		//multisampling defaulted to no multisampling (1 sample per pixel)
		.minSampleShading = 1.0,
		.pSampleMask = null,
		.alphaToCoverageEnable = VulkanInclude.VK_FALSE,
		.alphaToOneEnable = VulkanInclude.VK_FALSE,
	};

	//DepthStencilState
	const DepthStencilState = VulkanInclude.VkPipelineDepthStencilStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,

		.depthTestEnable = VulkanInclude.VK_TRUE,
		.depthWriteEnable = VulkanInclude.VK_TRUE,
		.depthCompareOp = VulkanInclude.VK_COMPARE_OP_LESS,//VK_COMPARE_OP_GREATER
		.depthBoundsTestEnable = VulkanInclude.VK_FALSE,
		.minDepthBounds = 0.0, // Optional
		.maxDepthBounds = 1.0, // Optional
		.stencilTestEnable = VulkanInclude.VK_FALSE,
	};

	//setup dummy color blending. We arent using transparent objects yet
	//the blending is just "no blend", but we do write to the color attachment

	//a single blend attachment with no blending and writing to RGBA
	const colorBlendAttachment = VulkanInclude.VkPipelineColorBlendAttachmentState
	{
		.colorWriteMask = VulkanInclude.VK_COLOR_COMPONENT_R_BIT | VulkanInclude.VK_COLOR_COMPONENT_G_BIT | VulkanInclude.VK_COLOR_COMPONENT_B_BIT | VulkanInclude.VK_COLOR_COMPONENT_A_BIT,
		.blendEnable = VulkanInclude.VK_FALSE,
	};

	const ColorBlendState = VulkanInclude.VkPipelineColorBlendStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,

		.logicOpEnable = VulkanInclude.VK_FALSE,
		.logicOp = VulkanInclude.VK_LOGIC_OP_COPY,
		.attachmentCount = 1,
		.pAttachments = &colorBlendAttachment,
	};

	const dynamicStates = [2]VulkanInclude.VkDynamicState
	{
		VulkanInclude.VK_DYNAMIC_STATE_VIEWPORT,
		VulkanInclude.VK_DYNAMIC_STATE_SCISSOR,
	};
	const DynamicState = VulkanInclude.VkPipelineDynamicStateCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		.dynamicStateCount = dynamicStates.len,
		.pDynamicStates = &dynamicStates,
	};

	const descriptorSetLayouts = [2]VulkanInclude.VkDescriptorSetLayout
	{
		camera._cameraDescriptorSetLayout,
		terrainDescriptorSetLayout,
	};

	const pipelineLayoutInfo = VulkanInclude.VkPipelineLayoutCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
		//.flags = 0,
		.setLayoutCount = 2,
		.pSetLayouts = &descriptorSetLayouts,
		//.pushConstantRangeCount = 1,
		//.pPushConstantRanges = &push_constant,
	};

	VK_CHECK(VulkanInclude.vkCreatePipelineLayout(VulkanGlobalState._device, &pipelineLayoutInfo, null, pipelineLayout));

	const pipelineRenderingCreateInfo = VulkanInclude.VkPipelineRenderingCreateInfoKHR
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR,
		.colorAttachmentCount = 1,
		.pColorAttachmentFormats = &VulkanGlobalState._swapchainImageFormat,
		.depthAttachmentFormat = VulkanGlobalState._depthFormat,
	};

	const pipelineInfo = VulkanInclude.VkGraphicsPipelineCreateInfo
	{
		.sType = VulkanInclude.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
		//.flags = VK_PIPELINE_CREATE_DESCRIPTOR_BUFFER_BIT_EXT,

		.stageCount = 2,
		.pStages = &shaderStages,
		.pVertexInputState = &VertexInputState,
		.pInputAssemblyState = &InputAssemblyState,
		.pViewportState = &ViewportState,
		.pRasterizationState = &RasterizationState,
		.pMultisampleState = &MultisampleState,
		.pDepthStencilState = &DepthStencilState,
		.pColorBlendState = &ColorBlendState,
		.pDynamicState = &DynamicState,
		.layout = pipelineLayout.*,
		//.renderPass = _renderPass,
		.subpass = 0,
		.basePipelineHandle = null,

		.renderPass = null,
		.pNext = &pipelineRenderingCreateInfo,
	};

	VK_CHECK(VulkanInclude.vkCreateGraphicsPipelines(VulkanGlobalState._device, null, 1, &pipelineInfo, null, pipeline));
}
