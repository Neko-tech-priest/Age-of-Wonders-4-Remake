

const SDL = @import("SDL.zig");
const VulkanInclude = @import("VulkanInclude.zig");

pub var _windowExtent = VulkanInclude.VkExtent2D{.width = 512, .height = 512};
pub var _window: ?*SDL.SDL_Window = null;
pub const _window_flags: SDL.SDL_WindowFlags = (SDL.SDL_WINDOW_RESIZABLE | SDL.SDL_WINDOW_VULKAN);
