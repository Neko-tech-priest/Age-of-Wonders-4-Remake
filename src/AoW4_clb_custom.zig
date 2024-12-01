const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const linux = std.os.linux;

const customMem = @import("customMem.zig");
const memcpy = customMem.memcpy;
const memcpyDstAlign = customMem.memcpyDstAlign;

const lz4 = @import("lz4.zig");

const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");

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
const Texture_ChunkData = struct
{
    const MipLevel = struct
    {
        data: [*]u8,
        size: u32,
        width: u16,
        height: u16,
        format: u32,
    };
    name: [*]u8,
    nameLen: u8,
    mipLevels: [*]MipLevel,
    mipLevelsCount: u8,
};
const Mesh_ChunkData = struct
{
    name: [*]u8,
    nameLen: u32,
    verticesBuffer: [*]u8,
    verticesBufferSize: u32,
    vertexSize: u32,
    verticesCount: u16,
    indicesBuffer: [*]u8,
    indicesBufferSize: u32,
    indicesCount: u16,
};
const Material_ChunkData = struct
{
    name: [*]u8,
    nameLen: u32,
};
const Model_ChunkData = struct
{
    name: [*]u8,
    nameLen: u32,
//     meshes: [*]*Mesh_ChunkData,
    meshesIndices: [*]u8,
    meshesCount: u8,
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
inline fn readChunk_Texture(allocator: std.mem.Allocator, fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, texture: *Texture_ChunkData) void
{
//     _ = allocator;
//     _ = fileBufferPtrIteratorIn;
//     _ = texture;
    
    var fileBufferPtrIterator: [*]u8 = undefined;
    const textureBlockTable: Table = readTable(fileBufferPtrIteratorIn);
    {
        fileBufferPtrIterator = textureBlockTable.dataAfterHeaderPtr + textureBlockTable.header[1][1];
        const LibraryNameLen: u64 = fileBufferPtrIterator[0];
        const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
        fileBufferPtrIterator+=8;
        const NameLen: u64 = fileBufferPtrIterator[0];
        const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
        texture.name = stringsOffsetPtr+NameOffset;
        texture.nameLen = @intCast(NameLen);
    }
    fileBufferPtrIterator = textureBlockTable.dataAfterHeaderPtr + textureBlockTable.header[textureBlockTable.tablesCount-1][1];
    fileBufferPtrIterator+=3;
//     print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
    const mipmapsHeaderOffsetsTable: Table = readTable(fileBufferPtrIterator);
    {
        print("{x}\n", .{@intFromPtr(mipmapsHeaderOffsetsTable.dataAfterHeaderPtr) - @intFromPtr(fileBuffer)});
        texture.mipLevels = (allocator.alignedAlloc(Texture_ChunkData.MipLevel, customMem.alingment, mipmapsHeaderOffsetsTable.tablesCount) catch unreachable).ptr;
        texture.mipLevelsCount = @intCast(mipmapsHeaderOffsetsTable.tablesCount);
        for(0..mipmapsHeaderOffsetsTable.tablesCount) |tableIndex|
        {
            const currentMip: *Texture_ChunkData.MipLevel = &texture.mipLevels[tableIndex];
            fileBufferPtrIterator = mipmapsHeaderOffsetsTable.dataAfterHeaderPtr + mipmapsHeaderOffsetsTable.header[tableIndex][1];
            fileBufferPtrIterator+=4;
            const mipmapTable: Table = readTable(fileBufferPtrIterator);
            const tex_width: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 0);
            const tex_height: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 4);
            const tex_format: u64 = mem.bytesToValue(u8, mipmapTable.dataAfterHeaderPtr + 12);
            
            const dataOffset: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17);
            const dataSize: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17+8);
            const dataCompressedSize: u64 = mem.bytesToValue(u32, mipmapTable.dataAfterHeaderPtr + 17+12);
            
            currentMip.width = @intCast(tex_width);
            currentMip.height = @intCast(tex_height);
            currentMip.size = @intCast(dataSize);
            if(log_Texture)
            {
                print("width: {d}\n", .{tex_width});
                print("height: {d}\n", .{tex_height});
//                 print("offset: {x}\n", .{dataOffset});
                print("size: {d}\n", .{dataSize});
                print("compressed size: {d}\n", .{dataCompressedSize});
            }
            switch(tex_format)
            {
                0x83 =>
                {
                    currentMip.format = VulkanInclude.VK_FORMAT_BC1_RGB_SRGB_BLOCK;
                },
                0x97 =>
                {
                    currentMip.format = VulkanInclude.VK_FORMAT_BC3_UNORM_BLOCK;
                    //                         texture.*.format = VulkanInclude.VK_FORMAT_BC5_SNORM_BLOCK;
                },
                0xAC =>
                {
                    //                         texture.*.format = VulkanInclude.VK_FORMAT_A8B8G8R8_SRGB_PACK32;
                    currentMip.format = VulkanInclude.VK_FORMAT_BC5_SNORM_BLOCK;
                },
                else =>
                {
                    print("unknown texture image format\n", .{});
                    std.process.exit(0);
                }
            }
            if(dataCompressedSize != dataSize)
            {
                currentMip.data = (allocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                const resultSize: i32 = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, currentMip.data, @intCast(dataCompressedSize), @intCast(dataSize));
                if(log_Texture)
                    print("resultSize: {d}\n", .{resultSize});
            }
            else
            {
                currentMip.data = dataBlockPtr+dataOffset;
            }
            if(log_Texture)
                print("\n", .{});
//             if(textureFormat != tex_format)
//             {
//                 print("textureFormat != tex_format!\n{x} {x}", .{textureFormat, tex_format});
//                 std.process.exit(0);
//             }
        }
    }
}
inline fn readChunk_Mesh(allocator: std.mem.Allocator, fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, mesh: *Mesh_ChunkData) void
{
    var fileBufferPtrIterator: [*]u8 = undefined;
    const BlockTable: Table = readTable(fileBufferPtrIteratorIn);
    {
        fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
        const LibraryNameLen: u64 = fileBufferPtrIterator[0];
        const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
        fileBufferPtrIterator+=8;
        const NameLen: u64 = fileBufferPtrIterator[0];
        const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
        mesh.name = stringsOffsetPtr+NameOffset;
        mesh.nameLen = @intCast(NameLen);
        
        for(3..BlockTable.tablesCount) |tableIndex|
        {
            fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
//             print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
            if(mem.bytesToValue(u16, fileBufferPtrIterator) == 0x1403)
            {
//                 print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
                switch(BlockTable.header[tableIndex][0])
                {
                    0x3d =>
                    {
                        print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
                        const dataTable: TableNear = readTableNear(fileBufferPtrIterator);
                        {
                            const elementsCount: u32 = mem.bytesToValue(u32, dataTable.dataAfterHeaderPtr + 1);
                            const dataOffset: u64 = mem.bytesToValue(u32, dataTable.dataAfterHeaderPtr + 5);
                            fileBufferPtrIterator = dataTable.dataAfterHeaderPtr + 9;
                            const dataSize: u32 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
                            const dataCompressedSize: u32 = mem.bytesToValue(u32, fileBufferPtrIterator+8);
                            print("indicesCount: {d}\n", .{elementsCount});
                            print("indicesSize: {d}\n", .{dataSize});
                            mesh.indicesBuffer = (allocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                            mesh.indicesBufferSize = dataSize;
                            mesh.indicesCount = @intCast(elementsCount);
                            _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, mesh.indicesBuffer, @intCast(dataCompressedSize), @intCast(dataSize));
                        }
//                             print("resultSize: {d}\n", .{resultSize});
                    },
                    0x3e =>
                    {
                        print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
                        const dataTable: TableNear = readTableNear(fileBufferPtrIterator);
                        {
                            const vertexTypeTable: TableNear = readTableNear(dataTable.dataAfterHeaderPtr);
                            {
                                const vertexSize: u64 = vertexTypeTable.dataAfterHeaderPtr[0];
                                const vertexAttributesCount: u64 = vertexTypeTable.dataAfterHeaderPtr[4]<<1;
                                fileBufferPtrIterator = vertexTypeTable.dataAfterHeaderPtr+12;
                                var indexVertexAttributesCount: u64 = 0;
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
                                print("vertexSize: {d}\n", .{vertexSize});
                                print("vertex format: {s}\n", .{vertexTypeString[0..indexVertexAttributesCount]});
                            }
                            const elementsCount: u32 = mem.bytesToValue(u32, dataTable.dataAfterHeaderPtr + dataTable.dataPtr[1*2+1]);
                            const dataOffset: u64 = mem.bytesToValue(u32, dataTable.dataAfterHeaderPtr + dataTable.dataPtr[2*2+1]);
                            fileBufferPtrIterator = dataTable.dataAfterHeaderPtr + dataTable.dataPtr[2*2+1] + 4;
                            print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
                            const dataSize: u32 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
                            const dataCompressedSize: u32 = mem.bytesToValue(u32, fileBufferPtrIterator+8);
                            
                            mesh.verticesBuffer = (allocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
                            mesh.verticesBufferSize = dataSize;
                            mesh.verticesCount = @intCast(elementsCount);
                            _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, mesh.verticesBuffer, @intCast(dataCompressedSize), @intCast(dataSize));
                            print("verticesCount: {d}\n", .{elementsCount});
                            print("verticesSize: {d}\n", .{dataSize});
                        }
//                         mesh.verticesBuffer = (globalState.arenaAllocator.alignedAlloc(u8, customMem.alingment, dataSize) catch unreachable).ptr;
//                         mesh.verticesBufferSize = @intCast(dataSize);
//                         _ = lz4.LZ4_decompress_safe(dataBlockPtr+dataOffset, mesh.verticesBuffer, @intCast(dataCompressedSize), @intCast(dataSize));
                        //                         print("resultSize: {d}\n", .{resultSize});
                        //                     const mode: std.os.linux.mode_t = 0o755;
                        //                     const texture_fd: i32 = @intCast(std.os.linux.open("verticesData.raw", .{.ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true}, mode));
                        //                     defer _ = std.os.linux.close(texture_fd);
                        //                     _ = std.os.linux.write(texture_fd, meshData, @intCast(dataSize));
                        //                     break;
                    },
                    else =>
                    {
                        print("skip 0x1403 chunk: {x}\n", .{BlockTable.header[tableIndex][0]});
                    }
                }
            }
        }
    }
}
inline fn readChunk_Material(allocator: std.mem.Allocator, fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, material: *Material_ChunkData) void
{
    _ = allocator;
    _ = fileBuffer;
//     _ = fileBufferPtrIteratorIn;
//     _ = stringsOffsetPtr;
    _ = dataBlockPtr;
    _ = material;
    var fileBufferPtrIterator: [*]u8 = undefined;
    const BlockTable: Table = readTable(fileBufferPtrIteratorIn);
    {
        fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
        const LibraryNameLen: u64 = fileBufferPtrIterator[0];
        const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
        fileBufferPtrIterator+=8;
        const NameLen: u64 = fileBufferPtrIterator[0];
        const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
    }
}
inline fn readChunk_Model(allocator: std.mem.Allocator, fileBuffer: [*]u8, fileBufferPtrIteratorIn: [*]u8, stringsOffsetPtr: [*]u8, dataBlockPtr: [*]u8, meshes: [*]Mesh_ChunkData, meshesCount: u64, model: *Model_ChunkData) void
{
    _ = allocator;
//     _ = fileBuffer;
    //     _ = fileBufferPtrIteratorIn;
    //     _ = stringsOffsetPtr;
    _ = dataBlockPtr;
//     _ = model;
    var fileBufferPtrIterator: [*]u8 = undefined;
    const BlockTable: Table = readTable(fileBufferPtrIteratorIn);
    {
        fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[1][1];
        const LibraryNameLen: u64 = fileBufferPtrIterator[0];
        const LibraryNameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+LibraryNameOffset)[0..LibraryNameLen]});
        fileBufferPtrIterator+=8;
        const NameLen: u64 = fileBufferPtrIterator[0];
        const NameOffset: u64 = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        print("{s}\n", .{(stringsOffsetPtr+NameOffset)[0..NameLen]});
        model.name = stringsOffsetPtr+NameOffset;
        model.nameLen = @intCast(NameLen);
        
        var tableIndex: u64 = 3;
        while(tableIndex < BlockTable.tablesCount) : (tableIndex+=1)
        {
            fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex][1];
            print("offset: {x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
            print("type: {x}\n", .{BlockTable.header[tableIndex][0]});
        }
        fileBufferPtrIterator = BlockTable.dataAfterHeaderPtr + BlockTable.header[tableIndex-1][1] + 3 + 7;
        const unknownTable_1: TableNear = readTableNear(fileBufferPtrIterator);
        {
            fileBufferPtrIterator = unknownTable_1.dataAfterHeaderPtr + 3;
            const meshTablesOffsetsTable: TableNear = readTableNear(fileBufferPtrIterator);
            {
                fileBufferPtrIterator = meshTablesOffsetsTable.dataAfterHeaderPtr;
                const chunkType = mem.bytesToValue(u32, fileBufferPtrIterator);
                if(chunkType != 0x00410067)
                {
                    print("!= 0x00410067\n", .{});
                    std.process.exit(0);
                }
                fileBufferPtrIterator+=4;
                const meshAnotherTablesOffsetsTable: TableNear = readTableNear(fileBufferPtrIterator);
                {
                    fileBufferPtrIterator = meshAnotherTablesOffsetsTable.dataAfterHeaderPtr;
                    
                    print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
                    print("meshesCount: {d}\n", .{meshTablesOffsetsTable.tablesCount});
                    model.meshesCount = @intCast(meshTablesOffsetsTable.tablesCount);
                    model.meshesIndices = (globalState.arenaAllocator.alloc(u8, model.meshesCount) catch unreachable).ptr;
                    for(0..meshTablesOffsetsTable.tablesCount) |modelMeshIndex|
                    {
                        fileBufferPtrIterator = meshAnotherTablesOffsetsTable.dataAfterHeaderPtr + meshTablesOffsetsTable.dataPtr[1+(modelMeshIndex<<1)];
                        if(mem.bytesToValue(u16, fileBufferPtrIterator) != 0x1402)
                        {
                            print("!= 0x1402\n", .{});
                            std.process.exit(0);
                        }
                        const meshInfoTable: TableNear = readTableNear(fileBufferPtrIterator);
                        {
                            fileBufferPtrIterator = meshInfoTable.dataAfterHeaderPtr;
                            const meshNameLength = fileBufferPtrIterator[8];
                            const meshNameOffset = mem.bytesToValue(u16, fileBufferPtrIterator+12);
                            var meshNameFound: bool = false;
                            var archiveMeshIndex: u64 = 0;
                            while(archiveMeshIndex < meshesCount) : (archiveMeshIndex+=1)
                            {
                                if(customMem.memcmp(stringsOffsetPtr+meshNameOffset, meshes[archiveMeshIndex].name, meshNameLength))
                                {
                                    model.meshesIndices[modelMeshIndex] = @intCast(archiveMeshIndex);
                                    meshNameFound = true;
                                    break;
                                }
                            }
                            if(!meshNameFound)
                            {
                                print("model: mesh not found!\n", .{});
                                std.process.exit(0);
                            }
                            print("{s}\n", .{meshes[archiveMeshIndex].name[0..meshes[archiveMeshIndex].nameLen]});
                        }
                    }
                }
            }
        }
//         while(mem.bytesToValue(u16, fileBufferPtrIterator) != 0x0101)
//             fileBufferPtrIterator+=1;
//         fileBufferPtrIterator+=3;
    }
    print("{x}\n", .{@intFromPtr(fileBufferPtrIterator) - @intFromPtr(fileBuffer)});
}
pub fn clb_convert(path: [*:0]const u8,) !void
{
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arenaAllocator = arena.allocator();
    
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
    //     const clb_TablesNames = fileBuffer+32;
    fileBufferPtrIterator+=32;
    print("{s}\n", .{fileBufferPtrIterator[0..libraryNameLength]});
    fileBufferPtrIterator += mem.bytesToValue(u32, clb_TablesOffsetsPtr);
    const stringsOffsetPtr: [*]u8 = fileBuffer+0x20;
    const dataOffsetPtr = fileBufferPtrIterator + mem.bytesToValue(u32, clb_TablesOffsetsPtr+4);
    //     print("dataOffset: {x}\n", .{@intFromPtr(dataOffsetPtr)-@intFromPtr(fileBuffer)});
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
    
    var texturesCount: u64 = 0;
    var meshesCount: u64 = 0;
    var materialsCount: u64 = 0;
    var modelsCount: u64 = 0;
    
    var textures: [*]Texture_ChunkData = undefined;
    var meshes: [*]Mesh_ChunkData = undefined;
    var materials: [*]Material_ChunkData = undefined;
    var models: [*]Model_ChunkData = undefined;
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
    textures = (arenaAllocator.alloc(Texture_ChunkData, texturesCount) catch unreachable).ptr;
    texturesCount = 0;
    print("meshesCount: {d}\n", .{meshesCount});
    meshes = (arenaAllocator.alloc(Mesh_ChunkData, meshesCount) catch unreachable).ptr;
    meshesCount = 0;
    print("materialsCount: {d}\n", .{materialsCount});
    materials = (arenaAllocator.alloc(Material_ChunkData, materialsCount) catch unreachable).ptr;
    materialsCount = 0;
    print("modelsCount: {d}\n", .{modelsCount});
    models = (arenaAllocator.alloc(Model_ChunkData, modelsCount) catch unreachable).ptr;
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
            readChunk_Texture(arenaAllocator, fileBuffer, fileBufferPtrIterator, stringsOffsetPtr, dataOffsetPtr, &textures[texturesCount]);
//             readChunk_Texture(fileBuffer, fileBufferPtrIterator,  stringsOffsetPtr, dataOffsetPtr, &textures[texturesCount]);
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
            readChunk_Mesh(arenaAllocator, fileBuffer, fileBufferPtrIterator,  stringsOffsetPtr, dataOffsetPtr, &meshes[meshesCount]);
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
            readChunk_Material(arenaAllocator, fileBuffer, fileBufferPtrIterator, stringsOffsetPtr, dataOffsetPtr, &materials[materialsCount]);
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
            readChunk_Model(arenaAllocator, fileBuffer, fileBufferPtrIterator,  stringsOffsetPtr, dataOffsetPtr, meshes, meshesCount, &models[modelsCount]);
            modelsCount+=1;
            print("\n", .{});
        }
    }
    // Write
    
    const mode: linux.mode_t = 0o755;
    const clb_custom_fd: i32 = @intCast(linux.open("clb_custom.raw", .{.ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true}, mode));
    defer _ = linux.close(clb_custom_fd);
    var fileBufferStack: [4096]u8 = undefined;
    mem.bytesAsValue([4]u8, &fileBufferStack).* = [4]u8{'C', 'R', 'L', 'C'};
    var fileBufferStackPtr: [*]u8 = &fileBufferStack;
    mem.bytesAsValue(u16, fileBufferStackPtr+4).* = @intCast(texturesCount);
    mem.bytesAsValue(u16, fileBufferStackPtr+6).* = @intCast(meshesCount);
    mem.bytesAsValue(u16, fileBufferStackPtr+8).* = @intCast(modelsCount);
    _ = linux.write(clb_custom_fd, &fileBufferStack, 10);
    for(textures[0..texturesCount]) |texture|
    {
        fileBufferStackPtr = &fileBufferStack;
        fileBufferStackPtr[0] = @intCast(texture.nameLen);
        memcpy(fileBufferStackPtr+1, texture.name, texture.nameLen);
        fileBufferStackPtr+=texture.nameLen+1;
        mem.bytesAsValue(u32, fileBufferStackPtr).* = texture.mipLevels[0].format;
        fileBufferStackPtr[4] = texture.mipLevelsCount;
        fileBufferStackPtr+=5;
        for(texture.mipLevels[0..texture.mipLevelsCount]) |mipLevel|
        {
            mem.bytesAsValue(u16, fileBufferStackPtr+0).* = mipLevel.width;
            mem.bytesAsValue(u16, fileBufferStackPtr+2).* = mipLevel.height;
            mem.bytesAsValue(u32, fileBufferStackPtr+4).* = mipLevel.size;
            fileBufferStackPtr+=8;
        }
        _ = linux.write(clb_custom_fd, &fileBufferStack, 1+texture.nameLen+4+1+texture.mipLevelsCount*8);
        for(texture.mipLevels[0..texture.mipLevelsCount]) |mipLevel|
        {
            _ = linux.write(clb_custom_fd, mipLevel.data, mipLevel.size);
        }
    }
    for(meshes[0..meshesCount]) |mesh|
    {
        fileBufferStackPtr = &fileBufferStack;
        fileBufferStackPtr[0] = @intCast(mesh.nameLen);
        memcpy(fileBufferStackPtr+1, mesh.name, mesh.nameLen);
        fileBufferStackPtr+=mesh.nameLen+1;
        mem.bytesAsValue(u16, fileBufferStackPtr).* = mesh.verticesCount;
        mem.bytesAsValue(u16, fileBufferStackPtr+2).* = mesh.indicesCount;
        mem.bytesAsValue(u32, fileBufferStackPtr+4).* = mesh.verticesBufferSize;
        mem.bytesAsValue(u32, fileBufferStackPtr+8).* = mesh.indicesBufferSize;
        _ = linux.write(clb_custom_fd, &fileBufferStack, 1+mesh.nameLen+12);
        _ = linux.write(clb_custom_fd, mesh.verticesBuffer, mesh.verticesBufferSize);
        _ = linux.write(clb_custom_fd, mesh.indicesBuffer, mesh.indicesBufferSize);
    }
    for(models[0..modelsCount]) |model|
    {
        fileBufferStackPtr = &fileBufferStack;
        fileBufferStackPtr[0] = @intCast(model.nameLen);
        memcpy(fileBufferStackPtr+1, model.name, model.nameLen);
        fileBufferStackPtr+=model.nameLen+1;
        fileBufferStackPtr[0] = model.meshesCount;
        fileBufferStackPtr+=1;
        for(0..model.meshesCount) |meshIndex|
            fileBufferStackPtr[meshIndex] = model.meshesIndices[meshIndex];
        _ = linux.write(clb_custom_fd, &fileBufferStack, 1+model.nameLen+1+model.meshesCount);
    }
//     print("\n", .{});
}
