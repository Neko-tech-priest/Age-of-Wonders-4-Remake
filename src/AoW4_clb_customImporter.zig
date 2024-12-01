const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

const customMem = @import("customMem.zig");
const memcpy = customMem.memcpy;
const memcpyDstAlign = customMem.memcpyDstAlign;

const globalState = @import("globalState.zig");
const VulkanInclude = @import("VulkanInclude.zig");
const Image = @import("Image.zig");

pub const Texture_data = packed struct
{
    image: Image.Image,
    name: [*]u8,
    nameLen: u8,
};
pub const Mesh_data = packed struct
{
//     image: Image.Image,
    verticesBuffer: [*]u8,
    indicesBuffer: [*]u8,
    verticesBufferSize: u32,
    indicesBufferSize: u32,
    verticesCount: u16,
    indicesCount: u16,
    name: [*]u8,
    nameLen: u8,
};
pub const Model_data = struct
{
    name: [*]u8,
    nameLen: u8,
    meshesIndices: [*]u8,
    meshesCount: u8,
};
pub fn clb_custom_read(arenaAllocator: std.mem.Allocator, path: [*:0]const u8, texturesPtr: *[*]Texture_data, texturesCountPtr: *usize, meshesPtr: *[*]Mesh_data, meshesCountPtr: *usize, modelsPtr: *[*]Model_data, modelsCountPtr: *usize,) !void
{    
    var textures: [*]Texture_data = texturesPtr.*;
    defer texturesPtr.* = textures;
    var texturesCount: usize = texturesCountPtr.*;
    defer texturesCountPtr.* = texturesCount;
    
    var meshes: [*]Mesh_data = meshesPtr.*;
    defer meshesPtr.* = meshes;
    var meshesCount: usize = meshesCountPtr.*;
    defer meshesCountPtr.* = meshesCount;
    
    var models: [*]Model_data = modelsPtr.*;
    defer modelsPtr.* = models;
    var modelsCount: usize = modelsCountPtr.*;
    defer modelsCountPtr.* = modelsCount;
    
    var path_ptr_iterator: [*]const u8 = path;
    while(path_ptr_iterator[0] != 0)
    {
        path_ptr_iterator+=1;
    }
    print("{s}\n", .{path[0..@intFromPtr(path_ptr_iterator)-@intFromPtr(path)]});
    
    const file: std.fs.File = try std.fs.cwd().openFileZ(path, .{});
    defer file.close();
    
    const stat = file.stat() catch unreachable;
    const file_size: usize = stat.size;
    const fileBuffer: [*]u8 = (arenaAllocator.alignedAlloc(u8, customMem.alingment, file_size) catch unreachable).ptr;
    _ = file.read(fileBuffer[0..file_size]) catch unreachable;
    var fileBufferPtrIterator = fileBuffer;
    if(mem.bytesToValue(u32, fileBufferPtrIterator) != mem.bytesToValue(u32, &[4]u8{'C', 'R', 'L', 'C'}))
    {
        print("incorrect clb signature!", .{});
        std.process.exit(0);
    }
    texturesCount = mem.bytesToValue(u16, fileBufferPtrIterator+4);
    meshesCount = mem.bytesToValue(u16, fileBufferPtrIterator+6);
    modelsCount = mem.bytesToValue(u16, fileBufferPtrIterator+8);
    fileBufferPtrIterator+=10;
    print("texturesCount: {d}\n", .{texturesCount});
    print("meshesCount: {d}\n", .{meshesCount});
    print("modelsCount: {d}\n", .{modelsCount});
    
    textures = (arenaAllocator.alloc(Texture_data, texturesCount) catch unreachable).ptr;
    meshes = (arenaAllocator.alloc(Mesh_data, meshesCount) catch unreachable).ptr;
    models = (arenaAllocator.alloc(Model_data, modelsCount) catch unreachable).ptr;
    for(textures[0..texturesCount]) |*texture|
    {
//         _ = texture;
        texture.nameLen = fileBufferPtrIterator[0];
//         texture.name = (arenaAllocator.alignedAlloc(u8, customMem.alingment, texture.nameLen) catch unreachable).ptr;
        print("{s}\n", .{(fileBufferPtrIterator+1)[0..texture.nameLen]});
        fileBufferPtrIterator+=1+texture.nameLen;
        texture.image.format = mem.bytesToValue(u32, fileBufferPtrIterator);
        const mipsCount = fileBufferPtrIterator[4];
        fileBufferPtrIterator+=5;
        texture.image.width = mem.bytesToValue(u16, fileBufferPtrIterator);
        texture.image.height = mem.bytesToValue(u16, fileBufferPtrIterator+2);
        texture.image.size = mem.bytesToValue(u32, fileBufferPtrIterator+4);
//         print("{d}\n", .{texture.image.width});
//         print("{d}\n", .{texture.image.height});
//         print("{d}\n", .{texture.image.size});
//         print("format: {d}\n", .{texture.image.format});
        var imageHeaderPtr = fileBufferPtrIterator;
        fileBufferPtrIterator+=(mipsCount*8);
//         print("{x}\n", .{@intFromPtr(fileBufferPtrIterator)-@intFromPtr(fileBuffer)});
        texture.image.data = (arenaAllocator.alignedAlloc(u8, customMem.alingment, texture.image.size) catch
        unreachable).ptr;
        memcpyDstAlign(texture.image.data, fileBufferPtrIterator, texture.image.size);
        for(0..mipsCount) |mipLevelIndex|
        {
            _ = mipLevelIndex;
//             print("{d}\n", .{mem.bytesToValue(u16, imageHeaderPtr)});
            fileBufferPtrIterator+=mem.bytesToValue(u32, imageHeaderPtr+4);
            imageHeaderPtr+=8;
        }
    }
    for(meshes[0..meshesCount]) |*mesh|
    {
        mesh.nameLen = fileBufferPtrIterator[0];
        print("{s}\n", .{(fileBufferPtrIterator+1)[0..mesh.nameLen]});
        fileBufferPtrIterator+=1+mesh.nameLen;
        mesh.verticesCount = mem.bytesToValue(u16, fileBufferPtrIterator);
        mesh.indicesCount = mem.bytesToValue(u16, fileBufferPtrIterator+2);
        mesh.verticesBufferSize = mem.bytesToValue(u32, fileBufferPtrIterator+4);
        mesh.indicesBufferSize = mem.bytesToValue(u32, fileBufferPtrIterator+8);
        fileBufferPtrIterator+=12;
        mesh.verticesBuffer = (arenaAllocator.alignedAlloc(u8, customMem.alingment, mesh.verticesBufferSize) catch unreachable).ptr;
        mesh.indicesBuffer = (arenaAllocator.alignedAlloc(u8, customMem.alingment, mesh.indicesBufferSize) catch unreachable).ptr;
        memcpyDstAlign(mesh.verticesBuffer, fileBufferPtrIterator, mesh.verticesBufferSize);
        fileBufferPtrIterator+=mesh.verticesBufferSize;
        memcpyDstAlign(mesh.indicesBuffer, fileBufferPtrIterator, mesh.indicesBufferSize);
        fileBufferPtrIterator+=mesh.indicesBufferSize;
        print("verticesCount: {d}\n", .{mesh.verticesCount});
        print("indicesCount: {d}\n", .{mesh.indicesCount});
    }
    for(models[0..modelsCount]) |*model|
    {
        model.nameLen = fileBufferPtrIterator[0];
        print("{s}\n", .{(fileBufferPtrIterator+1)[0..model.nameLen]});
        fileBufferPtrIterator+=1+model.nameLen;
        model.meshesCount = fileBufferPtrIterator[0];
        fileBufferPtrIterator+=1;
        model.meshesIndices = (arenaAllocator.alloc(u8, model.meshesCount) catch unreachable).ptr;
        for(0..model.meshesCount) |meshIndex|
            model.meshesIndices[meshIndex] = fileBufferPtrIterator[meshIndex];
        fileBufferPtrIterator+=model.meshesCount;
    }
    print("\n", .{});
}
