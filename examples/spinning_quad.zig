const std = @import("std");
const heap = std.heap;

const spots = @import("spots");
const glfw = @import("glfw");

pub fn main() !void {
    const gpa = heap.smp_allocator;

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.Resizable, 0);

    const window_width = 640;
    const window_height = 640;

    const window = try glfw.createWindow(window_width, window_height, "Spin", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);

    var g: spots.Graphics = try .init(gpa, glfw.getProcAddress, .{});
    g.setScreenSize(window_width, window_height);

    const downscaled_ratio = 16;
    const target_width = window_width / downscaled_ratio;
    const target_height = window_height / downscaled_ratio;

    const downscaled_target = try g.createTarget(gpa, target_width, target_height);
    g.setTarget(downscaled_target);

    var t: f32 = 0;
    while (!glfw.windowShouldClose(window)) {
        defer t += 0.015;

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        g.clearColor(.cornflower_blue);
        g.drawQuad(.{
            .position = .init(target_width / 2, target_height / 2),
            .origin = .splat(0.5),
            .scale = .init(20, 20),
            .rotation = t,
            .color = .lerp(.blue, .yellow, @sin(t)),
        });

        g.setTarget(.screen);
        defer g.setTarget(downscaled_target);

        g.drawQuad(.{
            .position = .splat(0),
            .sprite = downscaled_target.sprite(&g),
            .scale = .div(g.screenSize(), downscaled_target.size(&g)),
            .mirroring = .vertical,
        });

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}
