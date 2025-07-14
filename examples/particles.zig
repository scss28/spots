const std = @import("std");
const Random = std.Random;
const time = std.time;
const mem = std.mem;
const heap = std.heap;

const spots = @import("spots");
const Graphics = spots.Graphics;
const Vec2f = spots.Vec2(f32);

const glfw = @import("glfw");

const Particle = struct {
    spawn_time: f32,
    color: Graphics.Color,

    position: Vec2f,
    velocity: Vec2f,
    rotation: f32,
    size: f32,
};

pub fn main() !void {
    const gpa = heap.smp_allocator;

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.Resizable, 0);

    const window_size = 800;

    const window = try glfw.createWindow(window_size, window_size, "Particles", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);

    var g: Graphics = try .init(gpa, glfw.getProcAddress, .{});
    g.setScreenSize(window_size, window_size);

    const downscaled_ratio = 4;
    const target_size = window_size / downscaled_ratio;

    const downscaled_target = try g.createTarget(gpa, target_size, target_size);
    g.setTarget(downscaled_target);

    const font = try g.loadFont(gpa, @embedFile("Minecraft.ttf"), .{});

    var particles: std.ArrayListUnmanaged(Particle) = .empty;

    var random_state: Random.DefaultPrng = .init(0);
    const random = random_state.random();

    while (!glfw.windowShouldClose(window)) {
        const t: f32 = @floatCast(glfw.getTime());

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        var text: []const u8 = "Press space!";
        if (glfw.getKey(window, glfw.KeySpace) == glfw.Press) {
            text = "Particles!";

            for (0..3) |_| {
                const color = ([_]Graphics.Color{
                    .red,
                    .green,
                    .blue,
                })[random.intRangeLessThan(usize, 0, 3)];

                try particles.append(gpa, .{
                    .position = .splat(target_size / 2),
                    .velocity = .add(
                        .scale(.up, random.floatNorm(f32) * 10),
                        .scale(.right, random.floatNorm(f32) * 5),
                    ),
                    .color = color,
                    .rotation = random.floatNorm(f32),
                    .spawn_time = t,
                    .size = 5 + 10 * random.floatNorm(f32),
                });
            }
        }

        var i: usize = 0;
        while (i < particles.items.len) {
            const p = &particles.items[i];

            if (p.spawn_time + 5 < t) {
                _ = particles.swapRemove(i);
                continue;
            }

            p.position = .add(p.position, p.velocity);
            p.velocity.y -= 0.3;
            p.velocity = .scale(p.velocity, 0.95);
            p.rotation += 0.01;

            i += 1;
        }

        g.clearColor(.cornflower_blue);

        {
            var b = try g.batch(.{});
            defer b.flush();

            for (particles.items) |p| {
                b.draw(.nth(0), .{
                    .position = p.position,
                    .origin = .splat(0.5),
                    .scale = .splat(p.size),
                    .color = p.color,
                    .rotation = p.rotation,
                });
            }
        }

        try g.drawText(text, .{
            .font = font,
            .position = .splat(target_size / 2),
            .pivot = .splat(0.5),
            .scale = .splat(0.3 + 0.3 * @sin(t)),
        });

        g.setTarget(.screen);
        defer g.setTarget(downscaled_target);

        g.drawQuad(.{
            .position = .splat(0),
            .sprite = downscaled_target.sprite(&g),
            .scale = .splat(downscaled_ratio),
            .mirroring = .vertical,
        });

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}
