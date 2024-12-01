const std = @import("std");
const mem = std.mem;
const c = std.c;
const print = std.debug.print;
const exit = std.process.exit;

const lz4 = @import("lz4.zig");
const VulkanInclude = @import("VulkanInclude.zig");

const globalState = @import("globalState.zig");
const VulkanGlobalState = @import("VulkanGlobalState.zig");

const customMem = @import("customMem.zig");

const VkImage = @import("VkImage.zig");
const VkBuffer = @import("VkBuffer.zig");
const Image = @import("Image.zig");

const AoW4 = @import("AoW4.zig");

const Table = struct
{
    dataAfterHeaderPtr: [*]u8,
    header: [*][2]u32,
    tablesCount: u64,
};
const TableNear = struct
{
    dataPtr: [*]u8,
    dataAfterHeaderPtr: [*]u8,
    tablesCount: u64,
};
const Model_temp = struct
{
    meshesNames: [*][]u8,
    meshes: [*]*AoW4.Mesh,
    meshesCount: u32,
};
const Material_temp = struct
{
    DiffuseTexture: [*]u8,
    DiffuseTextureLen: u32,
    texture: *AoW4.DiffuseMaterial,
};
const Texture_temp = packed struct
{
    image: Image.Image,
    name: [*]u8,
};
const Mesh_temp = packed struct
{
    verticesBuffer: [*]u8,
    indicesBuffer: [*]u8,
    verticesBufferSize: u32,
    indicesBufferSize: u32,
    indicesCount: u16,
    name: [*]u8,
};
pub const Texture = struct
{
    vkImage: VulkanInclude.VkImage,
    vkImageView: VulkanInclude.VkImageView,
    pub fn unload(self: Texture) void
    {
        VulkanInclude.vkDestroyImage(VulkanGlobalState._device, self.vkImage, null);
        VulkanInclude.vkDestroyImageView(VulkanGlobalState._device, self.vkImageView, null);
    }
};
pub const Mesh = struct
{
    vertexVkBuffer: VulkanInclude.VkBuffer,
    indexVkBuffer: VulkanInclude.VkBuffer,
    indicesCount: u16,
    pub fn unload(self: Mesh) void
    {
        VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, self.vertexVkBuffer, null);
        VulkanInclude.vkDestroyBuffer(VulkanGlobalState._device, self.indexVkBuffer, null);
    }
};
const log_Texture: bool = true;
const log_Mesh: bool = false;
fn readTable(arenaAllocator: std.mem.Allocator, fileBufferPtrIteratorIn: [*]u8) Table
{
    var bufferPtrItr = fileBufferPtrIteratorIn;
    var table: Table = undefined;
    //     defer fileBufferPtrIteratorPtr.* = fileBufferPtrIterator;
    
    var nearBlocksCount: u64 = bufferPtrItr[0];
    bufferPtrItr+=1;
    var farBlocksCount: u64 = 0;
    var nearBlocksPtr: [*]u8 = undefined;
    var farBlocksPtr: [*]u8 = undefined;
    if(nearBlocksCount > 0x80)
    {
        farBlocksCount = @as(u32, @bitCast(bufferPtrItr[0..4].*));
        bufferPtrItr+=4;
        nearBlocksCount = nearBlocksCount & 127;
    }
    nearBlocksPtr = bufferPtrItr;
    bufferPtrItr+=(nearBlocksCount<<1);
    farBlocksPtr = bufferPtrItr;
    bufferPtrItr+=(farBlocksCount<<3);
    
    const blocksCount: u64 = nearBlocksCount+farBlocksCount;
    var header: [*][2]u32 = (arenaAllocator.alloc([2]u32, blocksCount) catch unreachable).ptr;
    //     table.*.tables = (globalState.arenaAllocator.alloc(Table, blocksCount) catch unreachable).ptr;
    table.header = header;
    table.dataAfterHeaderPtr = bufferPtrItr;
    table.tablesCount = blocksCount;
    //     table.*.header = (globalState.arenaAllocator.alloc([2]u32, blocksCount) catch unreachable).ptr;
    var i: usize = 0;
    while(i < nearBlocksCount) : (i+=1)
    {
        header[i][0] = ((nearBlocksPtr+(i<<1)))[0];
        header[i][1] = ((nearBlocksPtr+(i<<1))+1)[0];
    }
    i = 0;
    while(i < farBlocksCount) : (i+=1)
    {
        header[nearBlocksCount+i][0] = @as(u32, @bitCast((farBlocksPtr+(i<<3))[0..4].*));//mem.bytesToValue(u32, ((farBlocksPtr+(i<<3))));
        header[nearBlocksCount+i][1] = @as(u32, @bitCast((farBlocksPtr+(i<<3))[4..8].*));
    }
    return table;
}
fn readTableNear(fileBufferPtrIteratorIn: [*]u8) TableNear
{
    var table: TableNear = undefined;
    
    table.tablesCount = fileBufferPtrIteratorIn[0];
    if(table.tablesCount >= 0x80)
    {
        print("it is a big table!\n", .{});
        exit(0);
    }
    table.dataPtr = fileBufferPtrIteratorIn+1;
    table.dataAfterHeaderPtr = table.dataPtr+(table.tablesCount<<1);
    
    return table;
}
fn readChunk_Texture(arenaAllocator: std.mem.Allocator, fileBuffer: [*]u8, bufferPtrItrPtr: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, texture: *Texture_temp) void
{
    _ = fileBuffer;
//     _ = dataBlockPtr;
    var bufferPtrItr: [*]u8 = undefined;
    const BlockTable: Table = readTable(arenaAllocator, bufferPtrItrPtr);
    bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
    const LibraryNameLen: u64 = bufferPtrItr[0];
    const LibraryNameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    bufferPtrItr+=8;
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    const NameLen: u64 = bufferPtrItr[0];
    const NameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
    texture.name = (arenaAllocator.alignedAlloc(u8, customMem.alingment, NameLen) catch unreachable).ptr;
    customMem.memcpyDstAlign(texture.name, stringsOffsetPtr+NameOffset, NameLen);
    
//     print("{x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
    var tableIndex: u64 = BlockTable.tablesCount-1;
    bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
    bufferPtrItr+=3;
//     print("{x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
    {
        const mipmapsHeaderOffsetsTable: Table = readTable(arenaAllocator, bufferPtrItr);
        tableIndex = 0;
        var mipSizes: [16]u64 = undefined;
        var dataOffsets: [16]u64 = undefined;
        var dataCompressedSizes: [16]u64 = undefined;
        texture.image.mipsCount = @intCast(mipmapsHeaderOffsetsTable.tablesCount);
        while(tableIndex < mipmapsHeaderOffsetsTable.tablesCount) : (tableIndex+=1)
        {
            bufferPtrItr = mipmapsHeaderOffsetsTable.dataAfterHeaderPtr + mipmapsHeaderOffsetsTable.header[tableIndex][1];
            bufferPtrItr+=4;
            const mipmapTable: Table = readTable(arenaAllocator, bufferPtrItr);
//             print("{x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
            const tex_width: u64 = @as(u32, @bitCast(mipmapTable.dataAfterHeaderPtr[0..4].*));
            const tex_height: u64 = @as(u32, @bitCast(mipmapTable.dataAfterHeaderPtr[4..8].*));
            const tex_format: u64 = mipmapTable.dataAfterHeaderPtr[12];
            
            const dataOffset: u64 = @as(u32, @bitCast(mipmapTable.dataAfterHeaderPtr[17..21].*));
            const dataSize: u64 = @as(u32, @bitCast(mipmapTable.dataAfterHeaderPtr[25..29].*));
            const dataCompressedSize: u64 = @as(u32, @bitCast(mipmapTable.dataAfterHeaderPtr[29..33].*));
            
            if(tableIndex == 0)
            {
                texture.image.mipSize = @intCast(dataSize);
                texture.image.width = @intCast(tex_width);
                texture.image.height = @intCast(tex_height);
                texture.image.format = @intCast(tex_format);
                if(log_Texture)
                {
                    print("width: {d}\n", .{tex_width});
                    print("height: {d}\n", .{tex_height});
                    //                 print("offset: {x}\n", .{dataOffset});
                    print("size: {d}\n", .{dataSize});
                    print("mipsCount: {d}\n", .{mipmapsHeaderOffsetsTable.tablesCount});
                    //                 print("compressed size: {d}\n", .{dataCompressedSize});
                    print("\n", .{});
                }
            }
            mipSizes[tableIndex] = dataSize;
            dataOffsets[tableIndex] = dataOffset;
            dataCompressedSizes[tableIndex] = dataCompressedSize;
            switch(tex_format)
            {
//                 0x53 =>
//                 {
//                     texture.image.format = VulkanInclude.VK_FORMAT_R8G8B8A8_SRGB;
//                     texture.image.alignment = 1;
// //                     texture.image.format = VulkanInclude.VK_FORMAT_BC3_UNORM_BLOCK;
// //                     texture.image.alignment = 16;
//                 },
                0x83 =>
                {
                    texture.image.format = VulkanInclude.VK_FORMAT_BC1_RGB_UNORM_BLOCK;
                    //VK_FORMAT_BC1_RGB_SRGB_BLOCK
                    texture.image.alignment = 8;
                },
                0x97 =>
                {
                    texture.image.format = VulkanInclude.VK_FORMAT_BC3_UNORM_BLOCK;
                    texture.image.alignment = 16;
                    //                         texture.*.format = VulkanInclude.VK_FORMAT_BC5_SNORM_BLOCK;
                },
                0xAC =>
                {
                    //                         texture.*.format = VulkanInclude.VK_FORMAT_A8B8G8R8_SRGB_PACK32;
                    texture.image.format = VulkanInclude.VK_FORMAT_BC5_SNORM_BLOCK;
                    texture.image.alignment = 16;
                },
                else =>
                {
                    print("unknown texture image format!\n{x}\n", .{tex_format});
                    std.process.exit(0);
                }
            }
            //                 totalCompressedTexturesSize+=(dataCompressedSize + dataCompressedSize % 16);
            //                 const mode: std.os.linux.mode_t = 0o755;
            //                 const texture_fd: i32 = @intCast(std.os.linux.open("texture.raw", .{.ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true}, mode));
            //                 defer _ = std.os.linux.close(texture_fd);
            //                 _ = std.os.linux.write(texture_fd, texture.*.data, @intCast(dataSize));
//             break;
        }
        texture.image.size = 0;
        for(0..mipmapsHeaderOffsetsTable.tablesCount) |i|
        {
            texture.image.size += @intCast(mipSizes[i]);
        }
        texture.image.data = (arenaAllocator.alignedAlloc(u8, customMem.alingment, texture.image.size) catch unreachable).ptr;
        var currentOffset: u64 = 0;
        for(0..mipmapsHeaderOffsetsTable.tablesCount) |i|
        {
            if(dataCompressedSizes[i] != mipSizes[i])
            {
                _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffsets[i], texture.image.data+currentOffset, @intCast(dataCompressedSizes[i]), @intCast(mipSizes[i]));
            }
            else
            {
                customMem.memcpyDstAlign8(texture.image.data+currentOffset, dataBlockPtr+dataOffsets[i], mipSizes[i]);
            }
            currentOffset += mipSizes[i];
        }
    }
}
fn readChunk_Mesh(arenaAllocator: std.mem.Allocator, fileBuffer: [*]u8, bufferPtrItrPtr: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, mesh: *Mesh_temp) void
{
//     _ = dataBlockPtr;
    var bufferPtrItr: [*]u8 = undefined;
    const BlockTable: Table = readTable(arenaAllocator, bufferPtrItrPtr);
    bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
    const LibraryNameLen: u64 = bufferPtrItr[0];
    const LibraryNameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    bufferPtrItr+=8;
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    const NameLen: u64 = bufferPtrItr[0];
    const NameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
    mesh.name = (arenaAllocator.alignedAlloc(u8, customMem.alingment, NameLen) catch unreachable).ptr;
    customMem.memcpyDstAlign(mesh.*.name, stringsOffsetPtr+NameOffset, NameLen);
    
    var tableIndex: u64 = 3;
    while(tableIndex < BlockTable.tablesCount) : (tableIndex+=1)
    {
        bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
        //         print("offset: {x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
        if(@as(u16, @bitCast(bufferPtrItr[0..2].*)) == 0x1403)
        {
//             print("{x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
            switch(BlockTable.header[tableIndex][0])
            {
                // indices
                0x3d =>
                {
                    const dataTable: Table = readTable(arenaAllocator, bufferPtrItr);
                    const elementsCount: u64 = @as(u32, @bitCast((dataTable.dataAfterHeaderPtr + dataTable.header[1][1])[0..4].*));
                    bufferPtrItr = dataTable.dataAfterHeaderPtr + dataTable.header[2][1];
                    const dataOffset: u64 = @as(u32, @bitCast(bufferPtrItr[0..4].*));
                    const dataSize: u64 = @as(u32, @bitCast(bufferPtrItr[8..12].*));
                    const dataCompressedSize: u64 = @as(u32, @bitCast(bufferPtrItr[12..16].*));
                    if(log_Mesh)
                    {
                        print("indicesCount: {d}\n", .{elementsCount});
                        print("indicesSize: {d}\n", .{dataSize});
                    }
                    mesh.indicesBuffer = (arenaAllocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                    mesh.indicesBufferSize = @intCast(dataSize);
                    mesh.indicesCount = @intCast(elementsCount);
                    _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, mesh.indicesBuffer, @intCast(dataCompressedSize), @intCast(dataSize));
                },
                // vertices
                0x3e =>
                {
                    const dataTable: Table = readTable(arenaAllocator, bufferPtrItr);
                    const vertexTypeTable: Table = readTable(arenaAllocator, dataTable.dataAfterHeaderPtr);
                    const elementsCount: u64 = @as(u32, @bitCast((dataTable.dataAfterHeaderPtr + dataTable.header[1][1])[0..4].*));
                    bufferPtrItr = dataTable.dataAfterHeaderPtr + dataTable.header[2][1];
                    const dataOffset: u64 = @as(u32, @bitCast(bufferPtrItr[0..4].*));
                    const dataSize: u64 = @as(u32, @bitCast(bufferPtrItr[8..12].*));
                    const dataCompressedSize: u64 = @as(u32, @bitCast(bufferPtrItr[12..16].*));
                    //                     fileBufferPtrIterator = vertexTypeTable.dataAfterHeaderPtr;
                    const vertexSize: u64 = vertexTypeTable.dataAfterHeaderPtr[0];
                    const vertexAttributesCount: u64 = vertexTypeTable.dataAfterHeaderPtr[4]<<1;
                    var indexVertexAttributesCount: u64 = 0;
                    bufferPtrItr = vertexTypeTable.dataAfterHeaderPtr+12;
                    var vertexTypeString: [16]u8 = undefined;
                    var unknownVertexAttribute: bool = false;
                    while(indexVertexAttributesCount < vertexAttributesCount) : (indexVertexAttributesCount+=2)
                    {
                        switch(@as(u32, @bitCast(bufferPtrItr[0..4].*)))
                        {
                            0x10 =>
                            {
                                vertexTypeString[indexVertexAttributesCount] = 'P';
                            },
                            0x40 =>
                            {
                                vertexTypeString[indexVertexAttributesCount] = 'N';
                            },
                            0x30 =>
                            {
                                vertexTypeString[indexVertexAttributesCount] = 'U';
                            },
                            0x20 =>
                            {
                                vertexTypeString[indexVertexAttributesCount] = 'C';
                            },
                            0x70 =>
                            {
                                vertexTypeString[indexVertexAttributesCount] = 'T';
                            },
//                             0x21 =>
//                             {
//                                 vertexTypeString[indexVertexAttributesCount] = 'z';
//                             },
                            else =>
                            {
                                print("\nunknown vertex attribute: {x}!\n", .{@as(u32, @bitCast(bufferPtrItr[0..4].*))});
                                print("{x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
                                unknownVertexAttribute = true;
//                                 exit(0);
                                vertexTypeString[indexVertexAttributesCount] = '0';
                            }
                        }
                        var attributeElementsCount = bufferPtrItr[4];
                        while(attributeElementsCount > 0x10){attributeElementsCount-=0x10;}
                        vertexTypeString[indexVertexAttributesCount+1] = attributeElementsCount+0x30;
                        bufferPtrItr+=8;
                    }
                    if(log_Mesh)
                    {
                        print("verticesCount: {d}\n", .{elementsCount});
                        print("verticesSize: {d}\n", .{dataSize});
                        print("vertexSize: {d}\n", .{vertexSize});
                        print("vertex format: {s}\n", .{vertexTypeString[0..indexVertexAttributesCount]});
                    }
                    mesh.verticesBuffer = (arenaAllocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                    mesh.verticesBufferSize = @intCast(dataSize);
                    _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, mesh.verticesBuffer, @intCast(dataCompressedSize), @intCast(dataSize));
                    if(unknownVertexAttribute)
                    {
                        const mode: std.os.linux.mode_t = 0o755;
                        const fd: i32 = @intCast(std.os.linux.open("verticesData.raw", .{.ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true}, mode));
                        defer _ = std.os.linux.close(fd);
                        _ = std.os.linux.write(fd, mesh.verticesBuffer, @intCast(dataSize));
                        exit(0);
                    }
                    //                     break;
                },
                else =>
                {
                    if(log_Mesh)
                        print("skip type: {x}\n", .{BlockTable.header[tableIndex][0]});
                }
            }
        }
    }
}
fn readChunk_Material(arenaAllocator: std.mem.Allocator, fileBuffer: [*]u8, bufferPtrItrPtr: [*]u8, stringsOffsetPtr: [*]u8, material: *Material_temp) void
{
    var bufferPtrItr: [*]u8 = undefined;
    const BlockTable: Table = readTable(arenaAllocator, bufferPtrItrPtr);
    //     print("{x}\n", .{@intFromPtr(BlockTable.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
    bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
    const LibraryNameLen: u64 = bufferPtrItr[0];
    const LibraryNameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    bufferPtrItr+=8;
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    const NameLen: u64 = bufferPtrItr[0];
    const NameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
    //     print("{x}\n{x}\n\n", .{LibraryNameOffset, NameOffset});
    
    var tableIndex: u64 = 3;
    while(tableIndex < BlockTable.tablesCount) : (tableIndex+=1)
    {
        bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
        //         if(mem.bytesToValue(u16, fileBufferPtrIterator) == 0x1403)
        //         {
        print("{x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
        print("type: {x}\n", .{BlockTable.header[tableIndex][0]});
    }
    const mainMaterialChunk = readTable(arenaAllocator, BlockTable.dataAfterHeaderPtr + BlockTable.header[4][1]+3);
    print("{x}\n", .{@intFromPtr(mainMaterialChunk.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
    print("materialFieldsCount: {d}\n", .{mainMaterialChunk.tablesCount});
    
    switch(mainMaterialChunk.tablesCount)
    {
        113 =>
        {
            const textureNameSize: u64 = @as(u32, @bitCast((mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+22+8)[0..4].*));
            material.DiffuseTexture = (arenaAllocator.alignedAlloc(u8, customMem.alingment, textureNameSize) catch unreachable).ptr;
            material.DiffuseTextureLen = @intCast(textureNameSize);
            customMem.memcpyDstAlign(material.DiffuseTexture, stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+26+8), textureNameSize);
            //             material.DiffuseTexture = stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+26+8);
            print("{s}\n", .{material.DiffuseTexture[0..textureNameSize]});
        },
        43 =>
        {
            for(0..43) |fieldIndex|
            {
//                 _ = fieldIndex;
                bufferPtrItr = mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[fieldIndex][1];
                switch(@as(u32, @bitCast(bufferPtrItr[4..8].*)))
                {
                    0x00411696 =>
                    {
//                         const stringSize: u64 = bufferPtrItr[9];
//                         print("0x1696: {s}\n", .{(stringsOffsetPtr+mem.bytesToValue(u32, bufferPtrItr+13))});
                    },
//                     0x00411695 =>
//                     {
//                         
//                     },
                    else =>
                    {
                        print("unknown material field type\n", .{});
//                         break;
                    }
                }
            }
//             const textureNameSize: u64 = @as(u32, @bitCast((mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+22+8)[0..4].*));
//             material.DiffuseTexture = (arenaAllocator.alignedAlloc(u8, customMem.alingment, textureNameSize) catch unreachable).ptr;
//             material.DiffuseTextureLen = @intCast(textureNameSize);
//             customMem.memcpyDstAlign(material.DiffuseTexture, stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[2][1]+26+8), textureNameSize);
            //             material.DiffuseTexture = stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+26+8);
//             print("{s}\n", .{material.DiffuseTexture[0..textureNameSize]});
        },
        else =>
        {
            print("unknown material table!\n{x}\n", .{@intFromPtr(mainMaterialChunk.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
        }
    }
    //     tableIndex = 0;
    //     while(tableIndex < mainMaterialChunk.tablesCount) : (tableIndex+=1)
    //     {
    //         fileBufferPtrIterator = mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[tableIndex][1];
    //         switch(mem.bytesToValue(u32, fileBufferPtrIterator))
    //         {
    //             0x00411696 =>
    //             {
    //                 const stringSize: u64 = fileBufferPtrIterator[9];
    //                 print("0x1696: {s}\n", .{(stringsOffsetPtr+mem.bytesToValue(u32, fileBufferPtrIterator+13))[0..stringSize]});
    //             },
    //             0x00411695 =>
    //             {
    //                 print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
    //                 const stringSize: u64 = fileBufferPtrIterator[9];
    //                 print("0x1695: {s}\n", .{(stringsOffsetPtr+mem.bytesToValue(u32, fileBufferPtrIterator+13))[0..stringSize]});
    //             },
    //             else =>
    //             {
    //                 print("unknown chunk material type\n", .{});
    //                 break;
    //             }
    //         }
    // //             fileBufferPtrIterator+=4;
    // //             break;
    // //             const materialFieldTable: Table = readTable(fileBufferPtrIterator);
    // //             _ = materialFieldTable;
    //     }
}
fn readChunk_Model(arenaAllocator: std.mem.Allocator, fileBuffer: [*]u8, bufferPtrItrPtr: [*]u8, stringsOffsetPtr: [*]u8, model: *Model_temp) void
{
//     _ = model;
    var bufferPtrItr: [*]u8 = undefined;
    const BlockTable = readTable(arenaAllocator, bufferPtrItrPtr);
    bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
    const LibraryNameLen: u64 = bufferPtrItr[0];
    const LibraryNameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    bufferPtrItr+=8;
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    const NameLen: u64 = bufferPtrItr[0];
    const NameOffset: u64 = @as(u32, @bitCast(bufferPtrItr[4..8].*));
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
    
//     var tableIndex: u64 = 3;
//     while(tableIndex < BlockTable.tablesCount) : (tableIndex+=1)
//     {
//         bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
//         //         if(mem.bytesToValue(u16, fileBufferPtrIterator) == 0x1403)
//         //         {
//         print("offset: {x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
//         print("type: {x}\n", .{BlockTable.header[tableIndex][0]});
//     }
    bufferPtrItr = BlockTable.dataAfterHeaderPtr + BlockTable.header[BlockTable.tablesCount-1][1];
//     print("{x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
    if(@as(u16, @bitCast(bufferPtrItr[0..2].*)) != 0x0101)
    {
        print("!= 0x0101\n", .{});
        std.process.exit(0);
    }
    bufferPtrItr += 3+7;
    const Table_1 = readTable(arenaAllocator, bufferPtrItr);
    bufferPtrItr = Table_1.dataAfterHeaderPtr;
    if(@as(u16, @bitCast(bufferPtrItr[0..2].*)) != 0x0101)
    {
        print("!= 0x0101\n", .{});
        std.process.exit(0);
    }
    bufferPtrItr+=3;
    const Table_2 = readTableNear(bufferPtrItr);
    bufferPtrItr = Table_2.dataAfterHeaderPtr;
    print("meshesCount: {d}\n", .{Table_2.tablesCount});
    model.meshesCount = @intCast(Table_2.tablesCount);
//     model.meshes = (arenaAllocator.alloc(*AoW4.Mesh, model.meshesCount) catch unreachable).ptr;
//     model.meshesNames = (arenaAllocator.alloc([]u8, model.meshesCount) catch unreachable).ptr;
    for(0..Table_2.tablesCount) |meshIndex|
    {
        bufferPtrItr = Table_2.dataAfterHeaderPtr + Table_2.dataPtr[meshIndex*2+1];
        if(@as(u32, @bitCast(bufferPtrItr[0..4].*)) != 0x00410067)
        {
            print("!= 0x00410067\n", .{});
            std.process.exit(0);
        }
        print("    {x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
        bufferPtrItr+=4;
        const Table_3 = readTableNear(bufferPtrItr);
        bufferPtrItr = Table_3.dataAfterHeaderPtr;
        if(@as(u16, @bitCast(bufferPtrItr[0..2].*)) != 0x1402)
        {
            print("!= 0x1402\n", .{});
            std.process.exit(0);
        }
        for(0..2) |i|
        {
            bufferPtrItr = Table_3.dataAfterHeaderPtr + Table_3.dataPtr[i*2+1];
            const meshInfoTable = readTableNear(bufferPtrItr);
            bufferPtrItr = meshInfoTable.dataAfterHeaderPtr;
//             print("    {x}\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
            const meshNameLength = bufferPtrItr[8];
            const meshNameOffset = @as(u16, @bitCast(bufferPtrItr[12..14].*));
            print("    {s}\n", .{(stringsOffsetPtr+meshNameOffset)[0..meshNameLength]});
//             model.meshesNames[meshIndex].ptr = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, meshNameLength) catch unreachable).ptr;
        }
    }
}
pub fn load(arenaAllocator: std.mem.Allocator, path: [*:0]const u8, textures: *[*]Texture, texturesVkDeviceMemory: *VulkanInclude.VkDeviceMemory, texturesCountPtr: *u64, meshes: *[*]Mesh, meshesVerticesVkDeviceMemory: *VulkanInclude.VkDeviceMemory, meshesIndicesVkDeviceMemory: *VulkanInclude.VkDeviceMemory, meshesCountPtr: *u64, modelsCountPtr: *u64, materialsCountPtr: *u64) void
{
//     _ = meshesIndicesVkDeviceMemory;
//     texturesPtr.* = 0;
    var modelsCount: u64 = 0;
    defer modelsCountPtr.* = @intCast(modelsCount);
    var meshesCount: u64 = 0;
    defer meshesCountPtr.* = @intCast(meshesCount);
    var texturesCount: u64 = 0;
    defer texturesCountPtr.* = @intCast(texturesCount);
    var materialsCount: u64 = 0;
    defer materialsCountPtr.* = @intCast(materialsCount);
    
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
    const libraryNameLength: u64 = @intFromPtr(path_ptr_null)-@intFromPtr(path_ptr_iterator)-4;
    
    const file: std.fs.File = std.fs.cwd().openFileZ(@ptrCast(path), .{}) catch
    {
        print(".model not found!\n", .{});exit(0);
    };
    defer file.close();
    const stat = file.stat() catch unreachable;
    const fileSize: usize = stat.size;
    const fileBuffer = (arenaAllocator.alignedAlloc(u8, customMem.alingment, fileSize) catch unreachable).ptr;
    _ = file.read(fileBuffer[0..fileSize]) catch unreachable;
    var bufferPtrItr: [*]u8 = fileBuffer;
    
    const clb_Signature: [8]u8 = .{0x43, 0x52, 0x4c, 0x00, 0x60, 0x00, 0x41, 0x00};
    if(@as(*u64, @alignCast(@ptrCast(bufferPtrItr))).* != @as(u64, @bitCast(clb_Signature)))
    {
        print("incorrect clb signature!", .{});
        std.process.exit(0);
    }
    if(fileBuffer[8] != 8)
    {
        print("!= 8\n", .{});
        std.process.exit(0);
    }
    const clb_TablesOffsetsPtr: [*]align(4)u8 = fileBuffer+12;
    bufferPtrItr+=32;
    print("{s}\n", .{bufferPtrItr[0..libraryNameLength]});
    bufferPtrItr += @as(*u32, @ptrCast(clb_TablesOffsetsPtr)).*;
    const stringsOffsetPtr: [*]u8 = fileBuffer+0x20;
    const dataOffsetPtr = bufferPtrItr + @as(*u32, @ptrCast(clb_TablesOffsetsPtr+4)).*;
    print("{x}\n\n", .{@intFromPtr(bufferPtrItr) - @intFromPtr(fileBuffer)});
    
    if(@as(u16, @bitCast(bufferPtrItr[0..2].*)) != 0x0383)
    {
        print("!= 0x0383\n", .{});
        std.process.exit(0);
    }
    const clb_Table: Table = readTable(arenaAllocator, bufferPtrItr);
    // header tables
    if(@as(u16, @bitCast((clb_Table.dataAfterHeaderPtr + clb_Table.header[2][1])[0..2].*)) != 0x0101)
    {
        print("!= 0x0101\n", .{});
        std.process.exit(0);
    }
    
    const headersTable: Table = readTable(arenaAllocator, clb_Table.dataAfterHeaderPtr + clb_Table.header[2][1] + 3);
//     print("{d}\n", .{headersTable.tablesCount});
    for(0..headersTable.tablesCount) |tableIndex|
    {
        bufferPtrItr = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 =  @as(u16, @bitCast(bufferPtrItr[0..2].*));
        switch(chunkType)
        {
            //             0x0005 =>//ANIM
            //             {
            //
            //             },
            0x004b =>//OBJ
            {
                modelsCount+=1;
            },
            0x166f =>//MAT
            {
                materialsCount+=1;
            },
            0x0035 =>//MESH
            {
                meshesCount+=1;
            },
            0x003d =>//TX
            {
                texturesCount+=1;
            },
            else =>
            {
                print("unknown chunk type: {x}\n", .{chunkType});
                print("{x}\n", .{@intFromPtr(bufferPtrItr)-@intFromPtr(fileBuffer)});
            }
        }
    }
    print("texturesCount: {d}\n", .{texturesCount});
    const textures_temp = (arenaAllocator.alloc(Texture_temp, texturesCount) catch unreachable).ptr;
    textures.* = (arenaAllocator.alloc(Texture, texturesCount) catch unreachable).ptr;
//     const textures_temp = (arenaAllocator.alloc(Texture_temp, texturesCount) catch unreachable).ptr;
    texturesCount = 0;
    print("meshesCount: {d}\n", .{meshesCount});
    const meshes_temp = (arenaAllocator.alloc(Mesh_temp, meshesCount) catch unreachable).ptr;
    meshes.* = (arenaAllocator.alloc(Mesh, meshesCount) catch unreachable).ptr;
    meshesCount = 0;
    print("materialsCount: {d}\n", .{materialsCount});
    const materials = (arenaAllocator.alloc(Material_temp, materialsCount) catch unreachable).ptr;
    materialsCount = 0;
    print("modelsCount: {d}\n", .{modelsCount});
//     const models = (arenaAllocator.alloc(Model_temp, modelsCount) catch unreachable).ptr;
    modelsCount = 0;
    
    // textures
    for(0..headersTable.tablesCount) |tableIndex|
    {
        bufferPtrItr = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 = @as(u32, @bitCast(bufferPtrItr[0..4].*));
        if(chunkType == 0x0041003d)
        {
//             print("{x}\n", .{@intFromPtr(bufferPtrItr)-@intFromPtr(fileBuffer)});
            bufferPtrItr+=4;
            readChunk_Texture(arenaAllocator, fileBuffer, bufferPtrItr,  stringsOffsetPtr, dataOffsetPtr, &textures_temp[texturesCount]);
            texturesCount+=1;
            print("\n", .{});
            //             std.process.exit(0);
//             break;
        }
    }
//     // meshes
//     for(0..headersTable.tablesCount) |tableIndex|
//     {
//         bufferPtrItr = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
//         const chunkType: u64 = @as(u32, @bitCast(bufferPtrItr[0..4].*));
//         if(chunkType == 0x00410035)
//         {
// //             print("{x}\n", .{@intFromPtr(bufferPtrItr)-@intFromPtr(fileBuffer)});
//             bufferPtrItr+=4;
//             readChunk_Mesh(arenaAllocator, fileBuffer, bufferPtrItr,  stringsOffsetPtr, dataOffsetPtr, &meshes_temp[meshesCount]);
//             meshesCount+=1;
//             print("\n", .{});
//         }
//     }
    // materials
    for(0..headersTable.tablesCount) |tableIndex|
    {
        bufferPtrItr = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 =  mem.bytesToValue(u32, bufferPtrItr);
        if(chunkType == 0x0041166f)
        {
            print("{x}\n", .{@intFromPtr(bufferPtrItr)-@intFromPtr(fileBuffer)});
            bufferPtrItr+=4;
            readChunk_Material(arenaAllocator, fileBuffer, bufferPtrItr, stringsOffsetPtr, &materials[materialsCount]);
            materialsCount+=1;
            print("\n", .{});
        }
    }
    // models
//     for(0..headersTable.tablesCount) |tableIndex|
//     {
//         bufferPtrItr = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
//         const chunkType: u64 = @as(u32, @bitCast(bufferPtrItr[0..4].*));
//         if(chunkType == 0x0041004b)
//         {
//             print("{x}\n", .{@intFromPtr(bufferPtrItr)-@intFromPtr(fileBuffer)});
//             bufferPtrItr+=4;
//             readChunk_Model(arenaAllocator, fileBuffer, bufferPtrItr,  stringsOffsetPtr, &models[modelsCount]);
//             modelsCount+=1;
//             print("\n", .{});
// //             break;
//         }
//     }
//     var texturesVkDeviceMemory: VulkanInclude.VkDeviceMemory = undefined;
    if(texturesCount > 0)
    {
        VkImage.createVkImages__VkImageViews__VkDeviceMemory_AoS(@ptrCast(textures_temp), @sizeOf(Texture_temp), @ptrCast(textures.*), @sizeOf(Texture), texturesCount, texturesVkDeviceMemory);
    }
    if(meshesCount > 0)
    {
        VkBuffer.createVkBuffers__VkDeviceMemory_AoS(VulkanInclude.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, @ptrCast(meshes_temp), @sizeOf(Mesh_temp), @offsetOf(Mesh_temp, "verticesBufferSize"), @ptrCast(meshes.*), @sizeOf(Mesh), meshesCount, meshesVerticesVkDeviceMemory);
        VkBuffer.createVkBuffers__VkDeviceMemory_AoS(VulkanInclude.VK_BUFFER_USAGE_INDEX_BUFFER_BIT, @as([*]u8, @ptrCast(meshes_temp))+8, @sizeOf(Mesh_temp), @offsetOf(Mesh_temp, "indicesBufferSize")-8, @as([*]u8, @ptrCast(meshes.*))+8, @sizeOf(Mesh), meshesCount, meshesIndicesVkDeviceMemory);
    }
    
}
