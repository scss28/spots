const std = @import("std");
const time = std.time;
const mem = std.mem;
const heap = std.heap;

const spots = @import("spots");
const glfw = @import("glfw");

const Tilemap = struct {
    tiles: [*]Tile,
    width: u32,
    height: u32,

    fn init(gpa: mem.Allocator, width: u32, height: u32) mem.Allocator.Error!Tilemap {
        const tiles = try gpa.alloc(Tile, width * height);
        @memset(tiles, .air);
        return .{
            .tiles = tiles.ptr,
            .width = width,
            .height = height,
        };
    }
};

const Tile = struct {
    tag: Tag,

    const air: Tile = .{ .tag = .air };
    const Tag = enum {
        air,
    };
};

pub fn main() !void {
    const gpa = heap.smp_allocator;

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.Resizable, 0);

    const window_size = 640;

    const window = try glfw.createWindow(window_size, window_size, "Terra", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);

    var g: spots.Graphics = try .init(gpa, glfw.getProcAddress, .{});
    g.setScreenSize(window_size, window_size);

    const downscaled_ratio = 8;
    const target_size = window_size / downscaled_ratio;

    const downscaled_target = try g.createTarget(gpa, target_size, target_size);
    g.setTarget(downscaled_target);

    const tile_size = target_size / 10;
    var tilemap: Tilemap = try .init(gpa, 10, 4);
    _ = &tilemap;

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        g.clearColor(.cornflower_blue);

        {
            var b = g.batch(.{});
            defer b.flush();

            for (0..tilemap.height) |j| for (0..tilemap.width) |i| {
                b.draw(.nth(0), .{
                    .position = .init(
                        @floatFromInt(i * tile_size),
                        @floatFromInt(j * tile_size),
                    ),
                    .scale = .splat(tile_size),
                    .color = .lerp(.lerp(.green, .red, 0.2), .black, 0.4),
                });
            };
        }

        {
            g.setTarget(.screen);
            defer g.setTarget(downscaled_target);

            g.drawQuad(.{
                .position = .splat(0),
                .sprite = downscaled_target.sprite(&g),
                .scale = .splat(downscaled_ratio),
                .mirroring = .vertical,
            });
        }

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}
