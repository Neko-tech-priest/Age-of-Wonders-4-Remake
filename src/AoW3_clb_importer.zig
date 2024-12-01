const std = @import("std");
const mem = std.mem;
const c = std.c;
const print = std.debug.print;

const customMem = @import("customMem.zig");
const memcpy = customMem.memcpy;

const globalState = @import("globalState.zig");

const VulkanInclude = @import("VulkanInclude.zig");

const AoW3 = @import("AoW3.zig");
const Image = @import("Image.zig");

const LibraryAndName = struct
{
	library: [*]u8,
	libraryLen: u8,
	name: [*]u8,
	nameLen: u8,
};

fn readBlockName(fileBufferPtrIteratorIn: [*]u8) void
{
	var fileBufferPtrIterator = fileBufferPtrIteratorIn;
	var nameLength: usize = mem.bytesToValue(u32, fileBufferPtrIterator);
	fileBufferPtrIterator+=4;
	print("{s}\n", .{fileBufferPtrIterator[0..nameLength]});
	fileBufferPtrIterator += nameLength;
	nameLength = mem.bytesToValue(u32, fileBufferPtrIterator);
	fileBufferPtrIterator+=4;
	print("{s}\n", .{fileBufferPtrIterator[0..nameLength]});
}
const Table = struct
{
	dataAfterHeaderPtr: [*]u8,
	offsets: [*][2]u32,
	tablesCount: u64,
};
fn readTable(fileBufferPtrIteratorIn: [*]u8) Table
{
	var fileBufferPtrIterator = fileBufferPtrIteratorIn;
	var table: Table = undefined;
	//     defer fileBufferPtrIteratorPtr.* = fileBufferPtrIterator;

	var nearBlocksCount: u64 = fileBufferPtrIterator[0];
	fileBufferPtrIterator+=1;
	var farBlocksCount: u64 = 0;
	var nearBlocksPtr: [*]u8 = undefined;
	var farBlocksPtr: [*]u8 = undefined;
	if(nearBlocksCount > 0x80)
	{
		farBlocksCount = mem.bytesToValue(u32, fileBufferPtrIterator);
		fileBufferPtrIterator+=4;
		nearBlocksCount = nearBlocksCount & 127;
	}
	nearBlocksPtr = fileBufferPtrIterator;
	fileBufferPtrIterator+=(nearBlocksCount<<1);
	farBlocksPtr = fileBufferPtrIterator;
	fileBufferPtrIterator+=(farBlocksCount<<3);

	const blocksCount: u64 = nearBlocksCount+farBlocksCount;
	var offsets: [*][2]u32 = (globalState.arenaAllocator.alloc([2]u32, blocksCount) catch unreachable).ptr;
	//     table.*.tables = (globalState.arenaAllocator.alloc(Table, blocksCount) catch unreachable).ptr;
	table.offsets = offsets;
	table.dataAfterHeaderPtr = fileBufferPtrIterator;
	table.tablesCount = blocksCount;
	//     table.*.offsets = (globalState.arenaAllocator.alloc([2]u32, blocksCount) catch unreachable).ptr;
	var i: usize = 0;
	while(i < nearBlocksCount) : (i+=1)
	{
		offsets[i][0] = ((nearBlocksPtr+(i<<1)))[0];
		offsets[i][1] = ((nearBlocksPtr+(i<<1))+1)[0];
	}
	i = 0;
	while(i < farBlocksCount) : (i+=1)
	{
		offsets[nearBlocksCount+i][0] = mem.bytesToValue(u32, ((farBlocksPtr+(i<<3))));
		offsets[nearBlocksCount+i][1] = mem.bytesToValue(u32, ((farBlocksPtr+(i<<3))+4));
	}
	return table;
}
inline fn read_Model_Chunk(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, offsetsTable: [*]u32, blocksCount: usize) void
{
	var fileBufferPtrIterator = fileBufferPtrIteratorIn;
	const zeroOffsetPtr = fileBufferPtrIterator;

	var i: usize = 2;
	while(i < blocksCount) : (i+=1)
	{
		fileBufferPtrIterator = zeroOffsetPtr + offsetsTable[i];
		print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
//      break;
	}
}
inline fn read_Mesh_Chunk(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, mesh: *AoW3.Mesh, meshesCount: *usize) void
{
	var fileBufferPtrIterator: [*]u8 = undefined;
	const meshBlockTable: Table = readTable(fileBufferPtrIteratorIn);
	fileBufferPtrIterator = meshBlockTable.dataAfterHeaderPtr;

	const MESH_BlockIndices: [8]u8              = .{0x03, 0x14, 0x00, 0x15, 0x01, 0x16, 0x05, 0x01};
	const MESH_BlockVertices_PNUT: [38]u8       = .{0x03, 0x14, 0x00, 0x15, 0x1f, 0x16, 0x23, 0x03, 0x15, 0x00, 0x16, 0x04, 0x17, 0x08, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x02, 0x00, 0x00, 0x05, 0x01, 0x00, 0x00, 0x09, 0x03};
	const MESH_BlockVertices_PNUCT: [42]u8      = .{0x03, 0x14, 0x00, 0x15, 0x23, 0x16, 0x27, 0x03, 0x15, 0x00, 0x16, 0x04, 0x17, 0x08, 0x34, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x02, 0x00, 0x00, 0x05, 0x01, 0x00, 0x00, 0x06, 0x0f, 0x00, 0x00, 0x09, 0x03};
	//const uint8_t MESH_BlockVertices_PNUUT[42]    = {0x03, 0x14, 0x00, 0x15, 0x23, 0x16, 0x27, 0x03, 0x15, 0x00, 0x16, 0x04, 0x17, 0x08, 0x38, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x02, 0x00, 0x00, 0x05, 0x01, 0x01, 0x00, 0x05, 0x01, 0x00, 0x00, 0x09, 0x03};
	//const uint8_t MESH_BlockVertices_PNUUCT[46]   = {0x03, 0x14, 0x00, 0x15, 0x27, 0x16, 0x2b, 0x03, 0x15, 0x00, 0x16, 0x04, 0x17, 0x08, 0x3c, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x02, 0x00, 0x00, 0x05, 0x01, 0x01, 0x00, 0x05, 0x01, 0x00, 0x00, 0x06, 0x0f, 0x00, 0x00, 0x09, 0x03};
	const MESH_BlockVertices_PNUCIIIWWT: [62]u8 = .{0x03, 0x14, 0x00, 0x15, 0x37, 0x16, 0x3b, 0x03, 0x15, 0x00, 0x16, 0x04, 0x17, 0x08, 0x39, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x02, 0x00, 0x00, 0x05, 0x01, 0x00, 0x00, 0x06, 0x0f, 0x00, 0x00, 0x0b, 0x04, 0x01, 0x00, 0x0b, 0x04, 0x02, 0x00, 0x0b, 0x04, 0x00, 0x01, 0x0a, 0x07, 0x01, 0x01, 0x0a, 0x07, 0x00, 0x00, 0x09, 0x03};

	var blockReadIndices: bool = false;
	var blockReadVertices: bool = false;

//  print("{d}\n", .{blocksCount});
	var i: usize = 2;
	while(i < meshBlockTable.tablesCount) : (i+=1)
	{
		fileBufferPtrIterator = meshBlockTable.dataAfterHeaderPtr + meshBlockTable.offsets[i][1];
		if(mem.eql(u8, fileBufferPtrIterator[0..8], MESH_BlockIndices[0..8]))//mem.bytesToValue(u64, MESH_BlockIndices)
		{
			if(blockReadIndices == false)
			{
				print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
				fileBufferPtrIterator+=8;
				const indicesCount: u32 = mem.bytesToValue(u32, fileBufferPtrIterator);
				fileBufferPtrIterator+=4;
				print("indices count: {d}\n", .{indicesCount});

				mesh.*.indicesBuffer = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, indicesCount*2) catch unreachable).ptr;
				mesh.*.indicesBufferSize = indicesCount*2;
				memcpy(mesh.*.indicesBuffer, fileBufferPtrIterator, indicesCount*2);
				blockReadIndices = true;
				//meshesCount+=1;
			}
		}
		else if(mem.eql(u8, fileBufferPtrIterator[0..38], MESH_BlockVertices_PNUT[0..38]))
		{
			print("vertex format: PNUT\n", .{});
			const vertexSize: usize =  mem.bytesToValue(u16, (fileBufferPtrIterator+14));
			print("vertex size: {d}\n", .{vertexSize});
			fileBufferPtrIterator+=38;
			const verticesCount: usize = mem.bytesToValue(u32, fileBufferPtrIterator);
			fileBufferPtrIterator+=4;
			print("vertices count: {d}\n", .{verticesCount});
			if(blockReadVertices == false)
			{
				mesh.*.verticesBuffer = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, verticesCount*vertexSize) catch unreachable).ptr;
				mesh.*.verticesBufferSize = @intCast(verticesCount*vertexSize);
//              @memcpy(mesh.verticesBuffer[0..verticesCount*vertexSize], fileBufferPtrIterator[0..verticesCount*vertexSize]);
				memcpy(mesh.verticesBuffer, fileBufferPtrIterator, verticesCount*vertexSize);
				var indexVertex: usize = 4;
//              const ptr: [*]f32 = @ptrCast(@alignCast(fileBufferPtrIterator));
				while(indexVertex < mesh.*.verticesBufferSize) : (indexVertex+=vertexSize)
					mem.bytesAsValue(f32, (mesh.verticesBuffer+indexVertex)).* *= -1;
//                  @as([*]f32, @ptrCast(@alignCast(mesh.verticesBuffer+indexVertex+4)))[0] *= -1;
				blockReadVertices = true;
				meshesCount.*+=1;
			}
		}
		else if(mem.eql(u8, fileBufferPtrIterator[0..42], MESH_BlockVertices_PNUCT[0..42]))
		{
			print("vertex format: PNUCT\n", .{});
		}
		else if(mem.eql(u8, fileBufferPtrIterator[0..62], MESH_BlockVertices_PNUCIIIWWT[0..62]))
		{
			print("vertex format: PNUCIIIWWT\n", .{});
			const vertexSize: usize =  mem.bytesToValue(u16, (fileBufferPtrIterator+14));
			print("vertex size: {d}\n", .{vertexSize});
			fileBufferPtrIterator+=62;
			const verticesCount = mem.bytesToValue(u32, fileBufferPtrIterator);
			fileBufferPtrIterator+=4;
			print("vertices count: {d}\n", .{verticesCount});
//          const vertexSizeAligned = vertexSize + ((4 - vertexSize % 4) % 4);
// 			if(blockReadVertices == false)
// 			{
// 				mesh.*.verticesBuffer = (try globalState.arenaAllocator.alloc(u8, verticesCount*vertexSizeAligned)).ptr;
// 				mesh.*.verticesBufferSize = verticesCount*vertexSizeAligned;
// 				var vertexOffset: usize = 0;
// 				while(vertexOffset < verticesCount*vertexSizeAligned) : (i+=vertexSizeAligned)
// // 				for(size_t i = 0; i < verticesCount; i+=1)
// 				{
// 					@memcpy((mesh.verticesBuffer+vertexOffset)[0..vertexSize], fileBufferPtrIterator[0..vertexSize]);
// 					fileBufferPtrIterator+=vertexSize;
// 				}
// 				vertexOffset = 4;
// 				while(vertexOffset < verticesCount*vertexSizeAligned) : (i+=vertexSizeAligned)
// 				{
// 					mem.bytesAsValue(f32, (mesh.verticesBuffer+vertexOffset)).* *= -1;
// 				}
// // 				for(size_t i = 0; i < mesh.verticesBufferSize; i+=vertexSizeAligned)
// // 				{
// // 					*(float*)(mesh.verticesBuffer+i+4) *= -1;
// // 					*(float*)(mesh.verticesBuffer+i+8) *= -1;
// // 				}
// 				blockReadVertices = true;
// 				meshesCount+=1;
// 			}
		}
	}
}
const MaterialChunk = struct
{
	DiffuseTextureName: [*]u8,
	DiffuseTextureNameLen: u8,
	NormalMapTextureName: [*]u8,
	NormalMapTextureNameLen: u8,
	MasksTextureName: [*]u8,
	MasksTextureNameLen: u8,
	SlopeBlendedDiffuseTextureName: [*]u8,
	SlopeBlendedDiffuseTextureNameLen: u8,
	SlopeBlendedNormalTextureName: [*]u8,
	SlopeBlendedNormalTextureNameLen: u8,
	SlopeBlendedMasksTextureName: [*]u8,
	SlopeBlendedMasksTextureNameLen: u8,

// 	BlendNormalFlatness: u8,
// 	SlopeNormalRepeatFactor: u8,
};
fn readMaterialField_Texture(materialFieldTable: Table, TextureNamePtr: *[*]u8, TextureNameLenPtr: *u8) void
{
	_ = TextureNamePtr;
	_ = TextureNameLenPtr;
	var fileBufferPtrIterator = materialFieldTable.dataAfterHeaderPtr;
	print("\n", .{});
	const fieldNameLength: u64 = fileBufferPtrIterator[0];
	print("{s}\n", .{(fileBufferPtrIterator+4)[0..fieldNameLength]});
	fileBufferPtrIterator += 4 + fieldNameLength;
	// LibraryAndName block
	fileBufferPtrIterator+=8;
	const libraryNameLength: u64 = fileBufferPtrIterator[0];
	print("{s}\n", .{(fileBufferPtrIterator+4)[0..libraryNameLength]});
	fileBufferPtrIterator += 4 + libraryNameLength;
	const textureNameLength: u64 = fileBufferPtrIterator[0];
	print("{s}\n", .{(fileBufferPtrIterator+4)[0..textureNameLength]});
	fileBufferPtrIterator += 4 + textureNameLength;
// 	fileBufferPtrIterator = materialFieldTable.tables[1].tables[0].dataAfterHeaderPtr;
// // 	readBlockName(fileBufferPtrIterator);
// 	const libraryNameLen: u64 = fileBufferPtrIterator[0];
// 	fileBufferPtrIterator+=4;
// 	print("{s}\n", .{fileBufferPtrIterator[0..libraryNameLen]});
// 	fileBufferPtrIterator += libraryNameLen;
// 	const textureNameLen: u64 = fileBufferPtrIterator[0];
// 	TextureNameLenPtr.* = @intCast(textureNameLen);
// 	fileBufferPtrIterator+=4;
// 	TextureNamePtr.* = ((globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, textureNameLen) catch unreachable).ptr);
// 	memcpy(TextureNamePtr.*, fileBufferPtrIterator, textureNameLen);
// 	print("{s}\n", .{fileBufferPtrIterator[0..textureNameLen]});
// 	print("\n", .{});
}
inline fn read_Material_Chunk(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8) void
{
// 	_ = fileBuffer;
	var fileBufferPtrIterator: [*]u8 = undefined;
	const materialBlockTable: Table = readTable(fileBufferPtrIteratorIn);
	fileBufferPtrIterator = materialBlockTable.dataAfterHeaderPtr;
	readBlockName(fileBufferPtrIterator);
	var chunkIndex: u64 = 2;
	while(mem.bytesToValue(u16, fileBufferPtrIterator) != 0x0101) : (chunkIndex+=1)
	{
		fileBufferPtrIterator = materialBlockTable.dataAfterHeaderPtr + materialBlockTable.offsets[chunkIndex+1][1];
	}
	fileBufferPtrIterator+=3;
	print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
	const materialFieldsHeaderOffsetsTable: Table = readTable(fileBufferPtrIterator);
	if(materialFieldsHeaderOffsetsTable.tablesCount != 43)
	{
		print("materialFielsCount != 43!\n", .{});
	}
// 	fileBufferPtrIterator = materialFieldsHeaderOffsetsTable.dataAfterHeaderPtr;
// 	print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
	var materialFieldsTables: [43]Table = undefined;
	chunkIndex = 0;
	while(chunkIndex < 43) : (chunkIndex+=1)
		materialFieldsTables[chunkIndex] = readTable(materialFieldsHeaderOffsetsTable.dataAfterHeaderPtr + materialFieldsHeaderOffsetsTable.offsets[chunkIndex][1] + 4);

// // // 	const materialBlockSignature: [4]u8 = .{0x73, 0x16, 0x41, 0x00};
// // // 	const Block: [8]u8 = .{0x73, 0x16, 0x41, 0x00, 0x03, 0x28, 0x00, 0x29};

	var materialChunk: MaterialChunk = undefined;
// // 	print("{d}\n\n", .{@sizeOf(MaterialChunk)});
// 	var materialFieldTable: Table = undefined;
	// DiffuseTexture
	readMaterialField_Texture(materialFieldsTables[0], &materialChunk.DiffuseTextureName, &materialChunk.DiffuseTextureNameLen);
// // 	readMaterialField_Texture(materialTable.tables[1], &materialChunk.NormalMapTextureName, &materialChunk.NormalMapTextureNameLen);
// // 	readMaterialField_Texture(materialTable.tables[2], &materialChunk.MasksTextureName, &materialChunk.MasksTextureNameLen);
// // 	readMaterialField_Texture(materialTable.tables[3], &materialChunk.SlopeBlendedDiffuseTextureName, &materialChunk.SlopeBlendedDiffuseTextureNameLen);
// // 	readMaterialField_Texture(materialTable.tables[4], &materialChunk.SlopeBlendedNormalTextureName, &materialChunk.SlopeBlendedNormalTextureNameLen);
// // 	readMaterialField_Texture(materialTable.tables[5], &materialChunk.SlopeBlendedMasksTextureName, &materialChunk.SlopeBlendedMasksTextureNameLen);
//
// // 	materialFieldTable = materialTable.tables[6];
// // 	materialChunk.BlendNormalFlatness = materialFieldTable.tables[1].dataAfterHeaderPtr[0];
// // 	print("{s}: {d}\n", .{(materialFieldTable.tables[0].dataAfterHeaderPtr+4)[0..materialFieldTable.tables[0].dataAfterHeaderPtr[0]], materialChunk.BlendNormalFlatness});
// //
// // 	materialFieldTable = materialTable.tables[7];
// // 	materialChunk.SlopeNormalRepeatFactor = @intFromFloat(mem.bytesToValue(f32, materialFieldTable.tables[1].tables[1].dataAfterHeaderPtr));
// // 	print("{s}: {d}\n", .{(materialFieldTable.tables[0].dataAfterHeaderPtr+4)[0..materialFieldTable.tables[0].dataAfterHeaderPtr[0]], materialChunk.SlopeNormalRepeatFactor});
//
}
inline fn read_Texture_Chunk(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, texture: *Image.Image) void
{
	var fileBufferPtrIterator: [*]u8 = undefined;
	const textureBlockTable: Table = readTable(fileBufferPtrIteratorIn);
	fileBufferPtrIterator = textureBlockTable.dataAfterHeaderPtr;
// 	var offsetsTable: [*]u32 = undefined;
// 	var blocksCount: u64 = undefined;
// 	readTable(&fileBufferPtrIterator, &offsetsTable, &blocksCount);
	readBlockName(fileBufferPtrIterator);
	const zeroOffsetPtr = fileBufferPtrIterator;
	var chunkIndex_4b_00: u64 = 2;
	while(chunkIndex_4b_00 < textureBlockTable.tablesCount) : (chunkIndex_4b_00+=1)
	{
		fileBufferPtrIterator = zeroOffsetPtr + textureBlockTable.offsets[chunkIndex_4b_00][1];
		if(mem.bytesToValue(u16, fileBufferPtrIterator) == 0x0101)
		{
			fileBufferPtrIterator+=3;
			const mipmapsHeaderOffsetsTable: Table = readTable(fileBufferPtrIterator);
			fileBufferPtrIterator = mipmapsHeaderOffsetsTable.dataAfterHeaderPtr;
// 			var textureBlocksCount: u64 = undefined;
// 			var textureOffsetsTable: [*]u32 = undefined;
// 			readTable(&fileBufferPtrIterator, &textureOffsetsTable, &textureBlocksCount);

			if(mem.bytesToValue(u32, fileBufferPtrIterator) != 0x00410024)
			{
				print("!= 0x00410024\n", .{});
				print("{d}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
				std.process.exit(0);
			}
			fileBufferPtrIterator+=4;
			const mipHeaderBlocksCount: u64 = fileBufferPtrIterator[0];
			fileBufferPtrIterator+=1;
			fileBufferPtrIterator+=(mipHeaderBlocksCount<<1);
			const tex_width: u64 = mem.bytesToValue(u32, fileBufferPtrIterator);
			const tex_height: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
			const tex_format: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+8);
			print("width: {d}\nheight: {d}\n", .{tex_width, tex_height});
			fileBufferPtrIterator+=(fileBufferPtrIterator-1)[0];
			var texture_size: u64 = 0;
			switch(tex_format)
			{
				0x05 =>
				{
					texture_size = (tex_width*tex_height)*4;
					texture.*.format = VulkanInclude.VK_FORMAT_A8B8G8R8_SRGB_PACK32;
				},
				0x07 =>
				{
					texture_size = (tex_width*tex_height)/2;
					texture.*.format = VulkanInclude.VK_FORMAT_BC1_RGB_SRGB_BLOCK;
				},
				0x09 =>
				{
					texture_size = (tex_width*tex_height);
					texture.*.format = VulkanInclude.VK_FORMAT_BC2_SRGB_BLOCK;
				},
				0x0b =>
				{
					texture_size = (tex_width*tex_height);
					texture.*.format = VulkanInclude.VK_FORMAT_BC3_UNORM_BLOCK;
				},
				else =>
				{
					print("unknown texture image format\n", .{});
					std.process.exit(0);
				}
			}
			print("DXT{d}\n", .{tex_format-6});
			texture.*.data = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, texture_size) catch unreachable).ptr;
			texture.*.size = @intCast(texture_size);
			texture.*.width = @intCast(tex_width);
			texture.*.height = @intCast(tex_height);
			memcpy(texture.data, fileBufferPtrIterator, texture_size);
			break;
		}
	}
}
pub fn clb_read(path: [*:0]const u8, meshesPtr: *[*]AoW3.Mesh, meshesCountPtr: *u32, texturesPtr: *[*]Image.Image, texturesCountPtr: *u32) !void
{
	var meshes: [*]AoW3.Mesh = meshesPtr.*;
	defer meshesPtr.* = meshes;
	var meshesCount: usize = meshesCountPtr.*;
	defer meshesCountPtr.* = @intCast(meshesCount);
	var textures: [*]Image.Image = texturesPtr.*;
	defer texturesPtr.* = textures;
	var texturesCount: u32 = texturesCountPtr.*;
	defer texturesCountPtr.* = texturesCount;

	var libraryName: [256]u8 align(customMem.alingment) = undefined;
	@memset(&libraryName, 0);
	var path_ptr_iterator: [*]const u8 = path;
	while(path_ptr_iterator[0] != 0)
	{
		path_ptr_iterator+=1;
	}
	const path_ptr_null: [*]const u8 = path_ptr_iterator;
	while(path_ptr_iterator[0] != '/')
	{
		path_ptr_iterator-=1;
	}
	path_ptr_iterator+=1;
	const libraryNameLength: usize = @intFromPtr(path_ptr_null)-@intFromPtr(path_ptr_iterator)-4;
	memcpy(&libraryName, path_ptr_iterator, libraryNameLength);
	var libraryName_ptr_iterator: [*]u8 = &libraryName;
	while(libraryName_ptr_iterator[0] != 0)
	{
		if(libraryName_ptr_iterator[0] > 0x60 and libraryName_ptr_iterator[0] < 0x7b)
			libraryName_ptr_iterator[0] -= 0x20;
		libraryName_ptr_iterator+=1;
	}
	print("{s}\n", .{libraryName[0..libraryNameLength]});
	var fileBufferPtrIterator: [*]u8 = undefined;
	const file: std.fs.File = try std.fs.cwd().openFileZ(path, .{});
	defer file.close();

	const stat = file.stat() catch unreachable;
	const file_size: usize = stat.size;
	const fileBuffer: [*]u8 = (globalState.arenaAllocator.alloc(u8, file_size) catch unreachable).ptr;
	_ = file.read(fileBuffer[0..file_size]) catch unreachable;
	fileBufferPtrIterator = fileBuffer;
	while(!mem.eql(u8, libraryName[0..libraryNameLength], fileBufferPtrIterator[0..libraryNameLength]))
		fileBufferPtrIterator+=1;
	fileBufferPtrIterator+=libraryNameLength;
	if(mem.bytesToValue(u16, fileBufferPtrIterator) != 257)
	{
		print("!= 0x 01 01\n", .{});
		std.process.exit(0);
	}
	if((fileBufferPtrIterator+2)[0] != 0)
	{
		print("!= 0\n", .{});
		std.process.exit(0);
	}
	fileBufferPtrIterator+=3;
	var chunks_count: usize = undefined;
	var Ptr_on_offsetsTable: [*]u8 = undefined;
	var Ptr_on_ZeroChunk: [*]u8 = undefined;
	if(fileBufferPtrIterator[0] == 0x81)
	{
		chunks_count = (fileBufferPtrIterator+1)[0];
		Ptr_on_offsetsTable = fileBufferPtrIterator+3;
		fileBufferPtrIterator+=7;
		fileBufferPtrIterator+=(chunks_count*8);
		Ptr_on_ZeroChunk = fileBufferPtrIterator;
	}
	else
	{
		print("unknown header data\n", .{});
		std.process.exit(0);
	}
	var modelsCount: usize = 0;
	var materialsCount: usize = 0;
	var chunk_index: usize = 0;
	while(chunk_index <= chunks_count) : (chunk_index+=1)
	{
		fileBufferPtrIterator = Ptr_on_ZeroChunk + mem.bytesToValue(u32, Ptr_on_offsetsTable+chunk_index*8);
		const chunkHeaderPtr: [*]u8 = fileBufferPtrIterator;
		const chunkType: usize =  mem.bytesToValue(u16, fileBufferPtrIterator);
		while(!mem.eql(u8, fileBufferPtrIterator[0..libraryNameLength], libraryName[0..libraryNameLength]))
			fileBufferPtrIterator+=1;
		fileBufferPtrIterator+=libraryNameLength+1;
		switch(chunkType)
		{
			0x0005 =>//ANIM
			{

			},
			0x004b =>//OBJ
			{
				modelsCount+=1;
			},
			0x166f =>//MAT
			{
				materialsCount+=1;
			},
			0x003d =>//TX
			{
				texturesCount+=1;
			},
			0x0035 =>//MESH
			{
				meshesCount+=1;
			},
			else =>
			{
				print("unknown chunk type: {d}\n", .{chunkType});
				print("{d}\n\n", .{@intFromPtr(chunkHeaderPtr)-@intFromPtr(fileBuffer)});
			}
		}
	}
// 	modelsCount = 0;
	print("modelsCount: {d}\n", .{modelsCount});
	modelsCount = 0;

	print("meshesCount: {d}\n", .{meshesCount});
	meshes = (globalState.arenaAllocator.alloc(AoW3.Mesh, meshesCount) catch unreachable).ptr;
// 	meshes = @ptrCast(@alignCast((c.malloc(meshesCount*@sizeOf(AoW3.Mesh)))));
	meshesCount = 0;

	print("materialsCount: {d}\n", .{materialsCount});
	materialsCount = 0;

	print("texturesCount: {d}\n", .{texturesCount});
// 	textures = @ptrCast(@alignCast((c.malloc(texturesCount*@sizeOf(Image.Image)))));
	textures = (globalState.arenaAllocator.alloc(Image.Image, texturesCount) catch unreachable).ptr;
	texturesCount = 0;

	// Models
// 	chunk_index=0;
// 	while(chunk_index <= chunks_count) : (chunk_index+=1)
// 	{
// 		fileBufferPtrIterator = Ptr_on_ZeroChunk + mem.bytesToValue(u32, Ptr_on_offsetsTable+chunk_index*8);
// 		// const chunkHeaderPtr: [*]u8 = fileBufferPtrIterator;
// 		const chunkType: usize =  mem.bytesToValue(u16, fileBufferPtrIterator);
// 		fileBufferPtrIterator+=4;
// 		if(chunkType == 0x004b)
// 		{
// 			print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
// 			var table: Table = undefined;
// 			readTables(fileBuffer, fileBufferPtrIterator, &table, 0);
// // 			var offsetsTable: [*]u32 = undefined;
// // 			var blocksCount: usize = undefined;
// // 			readChunkTable(fileBuffer, &fileBufferPtrIterator, &libraryName, libraryNameLength, &offsetsTable, &blocksCount);
// // 			read_Model_Chunk(fileBuffer, fileBufferPtrIterator, offsetsTable, blocksCount);
// // 			modelsCount+=1;
// 			print("\n", .{});
// 		}
// 	}
	// Meshes
	chunk_index=0;
	while(chunk_index <= chunks_count) : (chunk_index+=1)
	{
		fileBufferPtrIterator = Ptr_on_ZeroChunk + mem.bytesToValue(u32, Ptr_on_offsetsTable+chunk_index*8);
// 		const chunkHeaderPtr: [*]u8 = fileBufferPtrIterator;
		const chunkType: usize =  mem.bytesToValue(u16, fileBufferPtrIterator);
		fileBufferPtrIterator+=4;
		if(chunkType == 0x0035)
		{
			read_Mesh_Chunk(fileBuffer, fileBufferPtrIterator, &meshes[meshesCount], &meshesCount);
			print("\n", .{});
			break;
		}
	}
	// Materials
	chunk_index=0;
	while(chunk_index <= chunks_count) : (chunk_index+=1)
	{
		fileBufferPtrIterator = Ptr_on_ZeroChunk + mem.bytesToValue(u32, Ptr_on_offsetsTable+chunk_index*8);
		// const chunkHeaderPtr: [*]u8 = fileBufferPtrIterator;
		const chunkType: usize =  mem.bytesToValue(u16, fileBufferPtrIterator);
		fileBufferPtrIterator+=4;
		if(chunkType == 0x166f)
		{
			print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
// 			var table: Table = undefined;
// 			readTables(fileBuffer, fileBufferPtrIterator, &table, 0);
// 			var offsetsTable: [*]u32 = undefined;
// 			var blocksCount: usize = undefined;
// 			readChunkTable(fileBuffer, &fileBufferPtrIterator, &libraryName, libraryNameLength, &offsetsTable, &blocksCount);
			read_Material_Chunk(fileBuffer, fileBufferPtrIterator);
			materialsCount+=1;
			print("\n", .{});
			break;
		}
	}
	// Textures
	chunk_index=0;
	while(chunk_index <= chunks_count) : (chunk_index+=1)
	{
		fileBufferPtrIterator = Ptr_on_ZeroChunk + mem.bytesToValue(u32, Ptr_on_offsetsTable+chunk_index*8);
		// 		const chunkHeaderPtr: [*]u8 = fileBufferPtrIterator;
		const chunkType: usize =  mem.bytesToValue(u16, fileBufferPtrIterator);
		fileBufferPtrIterator+=4;
		if(chunkType == 0x003d)
		{
			read_Texture_Chunk(fileBuffer, fileBufferPtrIterator, &textures[texturesCount]);
			texturesCount+=1;
			print("\n", .{});
			break;
		}
	}
}
