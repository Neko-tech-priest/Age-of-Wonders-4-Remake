const std = @import("std");
const mem = std.mem;
const c = std.c;
const print = std.debug.print;

const customMem = @import("customMem.zig");
const memcpyDstAlign = customMem.memcpyDstAlign;

const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");
const Image = @import("Image.zig");
const AoW4 = @import("AoW4.zig");

const lz4 = @import("lz4.zig");

// var totalCompressedTexturesSize: u64 = 0;

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
pub const Model_temp = struct
{
    meshesNames: [*][]u8,
    meshes: [*]*AoW4.Mesh,
    meshesCount: u32,
};
pub const Mesh_temp = packed struct
{
    verticesBuffer: [*]u8,
    indicesBuffer: [*]u8,
    verticesBufferSize: u32,
    indicesBufferSize: u32,
    name: [*]u8,
};
pub const Material_temp = struct
{
    DiffuseTexture: [*]u8,
    DiffuseTextureLen: u32,
    texture: *AoW4.DiffuseMaterial,
};
pub const Texture_temp = packed struct
{
    texture: Image.Image,
    name: [*]u8,
};
const log_Texture: bool = false;
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
    var header: [*][2]u32 = (globalState.arenaAllocator.alloc([2]u32, blocksCount) catch unreachable).ptr;
//     table.*.tables = (globalState.arenaAllocator.alloc(Table, blocksCount) catch unreachable).ptr;
    table.header = header;
    table.dataAfterHeaderPtr = fileBufferPtrIterator;
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
        header[nearBlocksCount+i][0] = mem.bytesToValue(u32, ((farBlocksPtr+(i<<3))));
        header[nearBlocksCount+i][1] = mem.bytesToValue(u32, ((farBlocksPtr+(i<<3))+4));
    }
    return table;
}
fn readTableNear(fileBufferPtrIteratorIn: [*]u8) TableNear
{
    var table: TableNear = undefined;
    
    table.tablesCount = fileBufferPtrIteratorIn[0];
    table.dataPtr = fileBufferPtrIteratorIn+1;
    table.dataAfterHeaderPtr = table.dataPtr+(table.tablesCount<<1);

    return table;
}
inline fn readChunk_Mesh(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, mesh: *Mesh_temp) void
{
//     _ = fileBuffer;
//     _ = fileBufferPtrIteratorIn;
//     _ = stringsOffsetPtr;
//     _  = dataBlockPtr;
//     _ = mesh;
    var fileBufferPtrIterator: [*]u8 = undefined;
    const BlockTable: Table = readTable(fileBufferPtrIteratorIn);
//     print("{x}\n", .{@intFromPtr(BlockTable.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
    fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
    const LibraryNameLen: u64 = fileBufferPtrIterator[0];
    const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    fileBufferPtrIterator+=8;
    const NameLen: u64 = fileBufferPtrIterator[0];
    const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
    print("NameOffset: {x}\n", .{NameOffset});
    mesh.*.name = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, NameLen) catch unreachable).ptr;
    memcpyDstAlign(mesh.*.name, stringsOffsetPtr+NameOffset, NameLen);

//     var indexReadingDataBlock: u64 = 0;
    var tableIndex: u64 = 3;
    while(tableIndex < BlockTable.tablesCount) : (tableIndex+=1)
    {
        fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
//         print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
        if(mem.bytesToValue(u16, fileBufferPtrIterator) == 0x1403)
        {
            print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
            switch(BlockTable.header[tableIndex][0])
            {
                0x3d =>
                {
                    const dataTable: Table = readTable(fileBufferPtrIterator);
                    const elementsCount: u64 = mem.bytesToValue(u32, dataTable.dataAfterHeaderPtr + dataTable.header[1][1]);
                    fileBufferPtrIterator = dataTable.dataAfterHeaderPtr + dataTable.header[2][1];
                    const dataOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator);
                    const dataSize: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+8);
                    const dataCompressedSize: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+12);
                    print("indicesCount: {d}\n", .{elementsCount});
                    print("indicesSize: {d}\n", .{dataSize});
                    mesh.indicesBuffer = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                    mesh.indicesBufferSize = @intCast(dataSize);
                    _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, mesh.indicesBuffer, @intCast(dataCompressedSize), @intCast(dataSize));
//                     print("resultSize: {d}\n", .{resultSize});
                },
                0x3e =>
                {
                    const dataTable: Table = readTable(fileBufferPtrIterator);
                    const vertexTypeTable: Table = readTable(dataTable.dataAfterHeaderPtr);
                    const elementsCount: u64 = mem.bytesToValue(u32, dataTable.dataAfterHeaderPtr + dataTable.header[1][1]);
                    fileBufferPtrIterator = dataTable.dataAfterHeaderPtr + dataTable.header[2][1];
                    const dataSize: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+8);

                    const dataOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator);
                    const dataCompressedSize: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+12);
                    print("verticesCount: {d}\n", .{elementsCount});
                    print("verticesSize: {d}\n", .{dataSize});
//                     fileBufferPtrIterator = vertexTypeTable.dataAfterHeaderPtr;
                    const vertexSize: u64 = vertexTypeTable.dataAfterHeaderPtr[0];
                    print("vertexSize: {d}\n", .{vertexSize});
                    const vertexAttributesCount: u64 = vertexTypeTable.dataAfterHeaderPtr[4]<<1;
                    var indexVertexAttributesCount: u64 = 0;
                    fileBufferPtrIterator = vertexTypeTable.dataAfterHeaderPtr+12;
                    var vertexTypeString: [16]u8 = undefined;
                    while(indexVertexAttributesCount < vertexAttributesCount) : (indexVertexAttributesCount+=2)
                    {
                        switch(mem.bytesToValue(u32, fileBufferPtrIterator))
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
                            else =>
                            {
                                vertexTypeString[indexVertexAttributesCount] = '0';
                            }
                        }
                        var attributeElementsCount = fileBufferPtrIterator[4];
                        while(attributeElementsCount > 0x10){attributeElementsCount-=0x10;}
                        vertexTypeString[indexVertexAttributesCount+1] = attributeElementsCount+0x30;
                        fileBufferPtrIterator+=8;
                    }
                    print("vertex format: {s}\n", .{vertexTypeString[0..indexVertexAttributesCount]});
                    mesh.verticesBuffer = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                    mesh.verticesBufferSize = @intCast(dataSize);
                    _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, mesh.verticesBuffer, @intCast(dataCompressedSize), @intCast(dataSize));
//                         print("resultSize: {d}\n", .{resultSize});
//                     const mode: std.os.linux.mode_t = 0o755;
//                     const texture_fd: i32 = @intCast(std.os.linux.open("verticesData.raw", .{.ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true}, mode));
//                     defer _ = std.os.linux.close(texture_fd);
//                     _ = std.os.linux.write(texture_fd, meshData, @intCast(dataSize));
//                     break;
                },
                else =>
                {
                    print("skip type: {x}\n", .{BlockTable.header[tableIndex][0]});
//                     print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
//                     print("type: {x}\n", .{BlockTable.header[tableIndex][0]});
//                     const dataTable: Table = readTable(fileBufferPtrIterator);
//                     const elementsCount: u64 = mem.bytesToValue(u32, dataTable.dataAfterHeaderPtr + dataTable.header[1][1]);
//                     fileBufferPtrIterator = dataTable.dataAfterHeaderPtr + dataTable.header[2][1];
//                                 const dataOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator);
//                     const dataSize: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+8);
//                     const dataCompressedSize: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+12);
//                     print("elementsCount: {d}\n", .{elementsCount});
//                     print("dataOffset: {x}\n", .{dataOffset});
//                     print("dataSize: {d}\n", .{dataSize});
//                     print("dataCompressedSize: {d}\n", .{dataCompressedSize});
                }
            }
        }
    }
}
inline fn readChunk_Texture(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, texture: *Texture_temp) void
{
    _ = fileBuffer;
    var fileBufferPtrIterator: [*]u8 = undefined;
    const textureBlockTable: Table = readTable(fileBufferPtrIteratorIn);
    var tableIndex: u64 = 0;
//     _ = stringsOffsetPtr;
    fileBufferPtrIterator = textureBlockTable.dataAfterHeaderPtr + textureBlockTable.header[1][1];
    const LibraryNameLen: u64 = fileBufferPtrIterator[0];
    const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    fileBufferPtrIterator+=8;
    const NameLen: u64 = fileBufferPtrIterator[0];
    const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
//     texture.*.name = stringsOffsetPtr+NameOffset;
    texture.*.name = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, NameLen) catch unreachable).ptr;
    memcpyDstAlign(texture.*.name, stringsOffsetPtr+NameOffset, NameLen);
//     while(textureBlockTable.header[tableIndex][0] != 0x21) : (tableIndex+=1){}
//     const tex_format: u64 = (textureBlockTable.dataAfterHeaderPtr + textureBlockTable.header[tableIndex][1])[0];
//     print("DXT{d}\n", .{tex_format-6});
//     texture.*.format = textureBlockTable.dataAfterHeaderPtr + textureBlockTable.header[tableIndex][1];
//     print("format: {x}\n", .{mem.bytesToValue(u32, textureBlockTable.dataAfterHeaderPtr + 0x2b)});
//     print("{x}\n", .{@intFromPtr(textureBlockTable.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
//     var tableIndex: u64 = undefined;
    // 0x0101
    tableIndex = textureBlockTable.tablesCount-1;
    fileBufferPtrIterator = textureBlockTable.dataAfterHeaderPtr + textureBlockTable.header[tableIndex][1];
//     print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
    fileBufferPtrIterator+=3;
    {
        const mipmapsHeaderOffsetsTable: Table = readTable(fileBufferPtrIterator);
        {
            tableIndex = 0;
            while(tableIndex < mipmapsHeaderOffsetsTable.tablesCount) : (tableIndex+=1)
            {
                fileBufferPtrIterator = mipmapsHeaderOffsetsTable.dataAfterHeaderPtr + mipmapsHeaderOffsetsTable.header[tableIndex][1];
//                 print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
                fileBufferPtrIterator+=4;
                const mipmapTable: Table = readTable(fileBufferPtrIterator);
//                 print("{x}\n", .{@intFromPtr(mipmapTable.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
                const tex_width: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 0);
                const tex_height: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 4);
                const tex_format: u64 = mem.bytesToValue(u8, mipmapTable.dataAfterHeaderPtr + 12);

                const dataOffset: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17);
                const dataSize: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17+8);
                const dataCompressedSize: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17+12);

                texture.*.texture.data = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                texture.*.texture.size = @intCast(dataSize);
                texture.*.texture.width = @intCast(tex_width);
                texture.*.texture.height = @intCast(tex_height);
                if(log_Texture)
                {
                    print("width: {d}\n", .{texture.*.texture.width});
                    print("height: {d}\n", .{texture.*.texture.height});

                    print("offset: {x}\n", .{dataOffset});
                    print("size: {d}\n", .{dataSize});
                    print("compressed size: {d}\n", .{dataCompressedSize});
                }
                switch(tex_format)
                {
                    0x83 =>
                    {
                        texture.*.texture.format = VulkanInclude.VK_FORMAT_BC1_RGB_SRGB_BLOCK;
                    },
                    0x97 =>
                    {
                        texture.*.texture.format = VulkanInclude.VK_FORMAT_BC3_UNORM_BLOCK;
//                         texture.*.format = VulkanInclude.VK_FORMAT_BC5_SNORM_BLOCK;
                    },
                    0xAC =>
                    {
//                         texture.*.format = VulkanInclude.VK_FORMAT_A8B8G8R8_SRGB_PACK32;
                        texture.*.texture.format = VulkanInclude.VK_FORMAT_BC5_SNORM_BLOCK;
                    },
                    else =>
                    {
                        print("unknown texture image format\n", .{});
                        std.process.exit(0);
                    }
                }
                if(dataCompressedSize != dataSize)
                {
                    const resultSize: i32 = lz4.LZ4_decompress_safe(dataBlockPtr+mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17), texture.*.texture.data, @intCast(dataCompressedSize), @intCast(dataSize));
                    if(log_Texture)
                        print("resultSize: {d}\n", .{resultSize});
                }
                else
                {
                    memcpyDstAlign(texture.*.texture.data, dataBlockPtr+mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17), dataSize);
//                     break;
                }
//                 totalCompressedTexturesSize+=(dataCompressedSize + dataCompressedSize % 16);
//                 const mode: std.os.linux.mode_t = 0o755;
//                 const texture_fd: i32 = @intCast(std.os.linux.open("texture.raw", .{.ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true}, mode));
//                 defer _ = std.os.linux.close(texture_fd);
//                 _ = std.os.linux.write(texture_fd, texture.*.data, @intCast(dataSize));
                print("\n", .{});
                break;
            }
        }
    }
}
inline fn readChunk_Material(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, material: *Material_temp) void
{
    var fileBufferPtrIterator: [*]u8 = undefined;
    const BlockTable: Table = readTable(fileBufferPtrIteratorIn);
    //     print("{x}\n", .{@intFromPtr(BlockTable.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
    fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
    const LibraryNameLen: u64 = fileBufferPtrIterator[0];
    const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    fileBufferPtrIterator+=8;
    const NameLen: u64 = fileBufferPtrIterator[0];
    const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
//     print("{x}\n{x}\n\n", .{LibraryNameOffset, NameOffset});

    var tableIndex: u64 = 3;
    while(tableIndex < BlockTable.tablesCount) : (tableIndex+=1)
    {
        fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
//         if(mem.bytesToValue(u16, fileBufferPtrIterator) == 0x1403)
//         {
        print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
        print("type: {x}\n", .{BlockTable.header[tableIndex][0]});
    }
    const mainMaterialChunk = readTable(BlockTable.dataAfterHeaderPtr + BlockTable.header[4][1]+3);
//     print("{x}\n", .{@intFromPtr(mainMaterialChunk.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
    print("materialFieldsCount: {d}\n", .{mainMaterialChunk.tablesCount});

    switch(mainMaterialChunk.tablesCount)
    {
        113 =>
        {
            const textureNameSize: u64 = mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+22+8);
            material.DiffuseTexture = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, textureNameSize) catch unreachable).ptr;
            material.DiffuseTextureLen = @intCast(textureNameSize);
            memcpyDstAlign(material.DiffuseTexture, stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+26+8), textureNameSize);
//             material.DiffuseTexture = stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+26+8);
            print("{s}\n", .{material.DiffuseTexture[0..textureNameSize]});
        },
        43 =>
        {
            const textureNameSize: u64 = mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[2][1]+22+8);
            material.DiffuseTexture = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, textureNameSize) catch unreachable).ptr;
            material.DiffuseTextureLen = @intCast(textureNameSize);
            memcpyDstAlign(material.DiffuseTexture, stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[2][1]+26+8), textureNameSize);
            //             material.DiffuseTexture = stringsOffsetPtr + mem.bytesToValue(u32, mainMaterialChunk.dataAfterHeaderPtr + mainMaterialChunk.header[13][1]+26+8);
            print("{s}\n", .{material.DiffuseTexture[0..textureNameSize]});
        },
        else =>
        {
            print("unknown material table: {x}\n", .{@intFromPtr(mainMaterialChunk.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
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
inline fn readChunk_Model(fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, model: *Model_temp) void
{
    var fileBufferPtrIterator: [*]u8 = undefined;
    const BlockTable: Table = readTable(fileBufferPtrIteratorIn);
    //     print("{x}\n", .{@intFromPtr(BlockTable.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
    fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
    const LibraryNameLen: u64 = fileBufferPtrIterator[0];
    const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
    fileBufferPtrIterator+=8;
    const NameLen: u64 = fileBufferPtrIterator[0];
    const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
    print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
    print("NameOffset: {x}\n", .{NameOffset});
//     model.name = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, NameLen) catch unreachable).ptr;
//     memcpyDstAlign(model.name, stringsOffsetPtr+NameOffset, NameLen);
    
    var tableIndex: u64 = 3;
    while(tableIndex < BlockTable.tablesCount) : (tableIndex+=1)
    {
        fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
        //         if(mem.bytesToValue(u16, fileBufferPtrIterator) == 0x1403)
        //         {
        print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
        print("type: {x}\n", .{BlockTable.header[tableIndex][0]});
    }
    var currentPtr = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex-1][1] + 3;
    while(mem.bytesToValue(u16, currentPtr) != 0x0101)
        currentPtr+=1;
    currentPtr+=3;
//     const meshesCount = currentPtr[0];
    const meshTablesOffsetsTable: TableNear = readTableNear(currentPtr);
    currentPtr = meshTablesOffsetsTable.dataAfterHeaderPtr;
    const chunkType = mem.bytesToValue(u32, currentPtr);
    if(chunkType != 0x00410067)
    {
        print("!= 0x00410067\n", .{});
        std.process.exit(0);
    }
    currentPtr+=4;
    const meshAnotherTablesOffsetsTable: TableNear = readTableNear(currentPtr);
    currentPtr = meshAnotherTablesOffsetsTable.dataAfterHeaderPtr;
    
    print("{x}\n", .{@intFromPtr(currentPtr) - @intFromPtr(fileBuffer)});
    print("meshesCount: {d}\n", .{meshTablesOffsetsTable.tablesCount});
    
    model.meshesCount = @intCast(meshTablesOffsetsTable.tablesCount);
    model.meshes = (globalState.arenaAllocator.alloc(*AoW4.Mesh, model.meshesCount) catch unreachable).ptr;
    model.meshesNames = (globalState.arenaAllocator.alloc([]u8, model.meshesCount) catch unreachable).ptr;
    var meshIndex: u64 = 0;
    while(meshIndex < meshTablesOffsetsTable.tablesCount) : (meshIndex+=1)
    {
        currentPtr = meshAnotherTablesOffsetsTable.dataAfterHeaderPtr + meshTablesOffsetsTable.dataPtr[1+(meshIndex<<1)];
        if(mem.bytesToValue(u16, currentPtr) != 0x1402)
        {
            print("!= 0x1402\n", .{});
            std.process.exit(0);
        }
        const meshInfoTable: TableNear = readTableNear(currentPtr);
        currentPtr = meshInfoTable.dataAfterHeaderPtr;
        const meshNameLength = currentPtr[8];
        const meshNameOffset = mem.bytesToValue(u16, currentPtr+12);
        
        model.meshesNames[meshIndex].ptr = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, meshNameLength) catch unreachable).ptr;
        model.meshesNames[meshIndex].len = meshNameLength;
        memcpyDstAlign(model.meshesNames[meshIndex].ptr, stringsOffsetPtr+meshNameOffset, meshNameLength);
        print("{s}\n", .{model.meshesNames[meshIndex]});
//         break;
    }
}
pub fn clb_read(path: [*:0]const u8, modelsPtr: *[*]Model_temp, modelsCountPtr: *u32, meshesPtr: *[*]Mesh_temp, meshesCountPtr: *u32, texturesPtr: *[*]Texture_temp, texturesCountPtr: *u32, materialsPtr: *[*]Material_temp, materialsCountPtr: *u32) !void
{
    var models: [*]Model_temp = modelsPtr.*;
    defer modelsPtr.* = models;
    var modelsCount: usize = modelsCountPtr.*;
    defer modelsCountPtr.* = @intCast(modelsCount);
    
    var meshes: [*]Mesh_temp = meshesPtr.*;
    defer meshesPtr.* = meshes;
    var meshesCount: usize = meshesCountPtr.*;
    defer meshesCountPtr.* = @intCast(meshesCount);

    var textures: [*]Texture_temp = texturesPtr.*;
    defer texturesPtr.* = textures;
    var texturesCount: u32 = texturesCountPtr.*;
    defer texturesCountPtr.* = texturesCount;

    var materials: [*]Material_temp = materialsPtr.*;
    defer materialsPtr.* = materials;
    var materialsCount: u32 = materialsCountPtr.*;
    defer materialsCountPtr.* = materialsCount;

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
//     const pathLen: u64 = mem.len(path);
    var fileBufferPtrIterator: [*]u8 = undefined;
    const file: std.fs.File = try std.fs.cwd().openFileZ(path, .{});
    defer file.close();

    const stat = file.stat() catch unreachable;
    const file_size: u64 = stat.size;
    const fileBuffer: [*]u8 = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, file_size) catch unreachable).ptr;
    _ = file.read(fileBuffer[0..file_size]) catch unreachable;
    fileBufferPtrIterator = fileBuffer;

    const clb_Signature: [8]u8 = .{0x43, 0x52, 0x4c, 0x00, 0x60, 0x00, 0x41, 0x00};
    if(mem.bytesToValue(u64, fileBufferPtrIterator) != mem.bytesToValue(u64, &clb_Signature))
    {
        print("incorrect clb signature!", .{});
        std.process.exit(0);
    }
    if(fileBuffer[8] != 8)
    {
        print("!= 8\n", .{});
        std.process.exit(0);
    }
    const clb_TablesOffsetsPtr: [*]u8 = fileBuffer+12;
    fileBufferPtrIterator+=32;
    print("{s}\n", .{fileBufferPtrIterator[0..libraryNameLength]});
    fileBufferPtrIterator += mem.bytesToValue(u32, clb_TablesOffsetsPtr);
    const stringsOffsetPtr: [*]u8 = fileBuffer+0x20;
    const dataOffsetPtr = fileBufferPtrIterator + mem.bytesToValue(u32, clb_TablesOffsetsPtr+4);
    print("{x}\n\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});

    if(mem.bytesToValue(u16, fileBufferPtrIterator) != 0x0383)
    {
        print("!= 0x0383\n", .{});
        std.process.exit(0);
    }
    const clb_Table: Table = readTable(fileBufferPtrIterator);
    // header tables
    if(mem.bytesToValue(u16, clb_Table.dataAfterHeaderPtr + clb_Table.header[2][1]) != 0x0101)
    {
        print("!= 0x0101\n", .{});
        std.process.exit(0);
    }

    const headersTable: Table = readTable(clb_Table.dataAfterHeaderPtr + clb_Table.header[2][1] + 3);
    for(0..headersTable.tablesCount) |tableIndex|
    {
        fileBufferPtrIterator = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 =  mem.bytesToValue(u16, fileBufferPtrIterator);
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
                print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
            }
        }
    }
    print("texturesCount: {d}\n", .{texturesCount});
    textures = (globalState.arenaAllocator.alloc(Texture_temp, texturesCount) catch unreachable).ptr;
    texturesCount = 0;
    print("meshesCount: {d}\n", .{meshesCount});
    meshes = (globalState.arenaAllocator.alloc(Mesh_temp, meshesCount) catch unreachable).ptr;
    meshesCount = 0;
    print("materialsCount: {d}\n", .{materialsCount});
    materials = (globalState.arenaAllocator.alloc(Material_temp, materialsCount) catch unreachable).ptr;
    materialsCount = 0;
    print("modelsCount: {d}\n", .{modelsCount});
    models = (globalState.arenaAllocator.alloc(Model_temp, modelsCount) catch unreachable).ptr;
    modelsCount = 0;
    
    // textures
    for(0..headersTable.tablesCount) |tableIndex|
    {
        fileBufferPtrIterator = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 =  mem.bytesToValue(u32, fileBufferPtrIterator);
        if(chunkType == 0x0041003d)
        {
            print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
            fileBufferPtrIterator+=4;
            readChunk_Texture(fileBuffer, fileBufferPtrIterator,  stringsOffsetPtr, dataOffsetPtr, &textures[texturesCount]);
            texturesCount+=1;
            print("\n", .{});
//             std.process.exit(0);
        }
    }
    // meshes
    for(0..headersTable.tablesCount) |tableIndex|
    {
        fileBufferPtrIterator = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 =  mem.bytesToValue(u32, fileBufferPtrIterator);
        if(chunkType == 0x00410035)
        {
            print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
            fileBufferPtrIterator+=4;
            readChunk_Mesh(fileBuffer, fileBufferPtrIterator,  stringsOffsetPtr, dataOffsetPtr, &meshes[meshesCount]);
            meshesCount+=1;
            print("\n", .{});
        }
    }
    // materials
    for(0..headersTable.tablesCount) |tableIndex|
    {
        fileBufferPtrIterator = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 =  mem.bytesToValue(u32, fileBufferPtrIterator);
        if(chunkType == 0x0041166f)
        {
            print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
            fileBufferPtrIterator+=4;
            readChunk_Material(fileBuffer, fileBufferPtrIterator, stringsOffsetPtr, &materials[materialsCount]);
            materialsCount+=1;
            print("\n", .{});
        }
    }
    // models
    for(0..headersTable.tablesCount) |tableIndex|
    {
        fileBufferPtrIterator = headersTable.dataAfterHeaderPtr + headersTable.header[tableIndex][1];
        const chunkType: u64 =  mem.bytesToValue(u32, fileBufferPtrIterator);
        if(chunkType == 0x0041004b)
        {
            print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
            fileBufferPtrIterator+=4;
            readChunk_Model(fileBuffer, fileBufferPtrIterator,  stringsOffsetPtr, &models[modelsCount]);
            modelsCount+=1;
            print("\n", .{});
        }
    }
}
