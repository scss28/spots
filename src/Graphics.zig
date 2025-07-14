const std = @import("std");
const unicode = std.unicode;
const fs = std.fs;
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const heap = std.heap;
const math = std.math;

const assert = std.debug.assert;
const panic = std.debug.panic;

const gl = @import("gl");
const TrueType = @import("TrueType");

const linalg = @import("linalg.zig");

pub const Vec2f = linalg.Vec2(f32);
pub const Vec4f = linalg.Vec4(f32);

const Graphics = @This();

pub const Color = packed struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub const white: Color = .hex("ffffff");
    pub const black: Color = .hex("000000");

    pub const red: Color = .hex("ff0000");
    pub const green: Color = .hex("00ff00");
    pub const blue: Color = .hex("0000ff");

    pub const transparent: Color = .hex("00000000");

    pub const yellow: Color = .hex("ffff00");
    pub const magenta: Color = .hex("ff00ff");
    pub const orange: Color = .hex("ffa500");

    pub const cornflower_blue: Color = .hex("6495ed");

    pub fn init(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn hex(comptime code: []const u8) Color {
        if (code.len != 8 and code.len != 6) {
            @compileError("'code' must have 8 or 6 elements.");
        }

        comptime var buf: [code.len / 2]u8 = undefined;
        _ = comptime fmt.hexToBytes(&buf, code) catch {
            @compileError("Invalid hex code: '" ++ code ++ "'");
        };

        return .{
            .r = @as(f32, @floatFromInt(buf[0])) / 255,
            .g = @as(f32, @floatFromInt(buf[1])) / 255,
            .b = @as(f32, @floatFromInt(buf[2])) / 255,
            .a = if (code.len == 6) 1 else @as(f32, @floatFromInt(buf[3])) / 255,
        };
    }

    pub fn lerp(a: Color, b: Color, t: f32) Color {
        const SimdVec4 = @Vector(4, f32);
        const vec_a: SimdVec4 = @bitCast(a);
        const vec_b: SimdVec4 = @bitCast(b);
        return @bitCast(@mulAdd(
            SimdVec4,
            vec_b - vec_a,
            @splat(t),
            vec_a,
        ));
    }
};

pub const Sprite = struct {
    texture: gl.Texture,
    width: u32,
    height: u32,

    pub const Index = enum(u32) {
        white_pixel,
        _,

        pub fn texture(i: Index, graphics: *const Graphics) gl.Texture {
            return graphics.sprites.items[@intFromEnum(i)].texture;
        }

        pub fn width(i: Index, graphics: *const Graphics) u32 {
            return graphics.sprites.items[@intFromEnum(i)].width;
        }

        pub fn height(i: Index, graphics: *const Graphics) u32 {
            return graphics.sprites.items[@intFromEnum(i)].height;
        }

        pub fn size(i: Index, graphics: *const Graphics) Vec2f {
            const sprite = graphics.sprites.items[@intFromEnum(i)];
            return .init(@floatFromInt(sprite.width), @floatFromInt(sprite.height));
        }
    };
};

pub const Font = struct {
    texture: TextureArray.Index,
    descent: f32,
    glyphs: std.AutoHashMapUnmanaged(Codepoint, Glyph),

    pub const Codepoint = u21;
    pub const Glyph = struct {
        bearing: Vec2f,
        advance: f32,
        sub_index: TextureArray.SubTexture.Index,
    };

    pub const Index = enum(u32) { _ };

    pub fn calculateWidth(f: Font, text: []const u8) f32 {
        const default_glyph = f.defaultGlyph();
        var line_width: f32 = 0;

        var it: std.unicode.Utf8Iterator = .{ .bytes = text, .i = 0 };
        while (it.nextCodepoint()) |codepoint| {
            const glyph = f.glyphs.get(codepoint) orelse default_glyph;
            line_width += glyph.advance;
        }

        return line_width;
    }

    pub inline fn defaultGlyph(f: Font) Glyph {
        return f.glyphs.get(32).?;
    }
};

pub const Target = union {
    screen: struct {
        width: u32,
        height: u32,
    },
    custom: struct {
        sprite: Sprite.Index,
        buffer: gl.Framebuffer,
    },

    pub const Index = enum(u32) {
        screen,
        _,

        pub fn buffer(i: Index, graphics: *const Graphics) gl.Framebuffer {
            assert(i != .screen);
            return graphics.targets.items[@intFromEnum(i)].custom.buffer;
        }

        pub fn sprite(i: Index, graphics: *const Graphics) Sprite.Index {
            assert(i != .screen);
            return graphics.targets.items[@intFromEnum(i)].custom.sprite;
        }

        pub fn width(i: Index, graphics: *const Graphics) u32 {
            return switch (i) {
                .screen => graphics.targets.items[@intFromEnum(i)].screen.width,
                else => i.sprite(graphics).width(graphics),
            };
        }

        pub fn height(i: Index, graphics: *const Graphics) u32 {
            return switch (i) {
                .screen => graphics.targets.items[@intFromEnum(i)].screen.height,
                else => i.sprite(graphics).height(graphics),
            };
        }

        pub fn size(i: Index, graphics: *const Graphics) Vec2f {
            switch (i) {
                .screen => {
                    const screen = graphics.targets.items[@intFromEnum(i)].screen;
                    return .init(@floatFromInt(screen.width), @floatFromInt(screen.height));
                },
                else => {
                    return i.sprite(graphics).size(graphics);
                },
            }
        }
    };
};

pub const TextureArray = struct {
    texture: gl.Texture,
    width: u32,
    height: u32,
    depth: u32,

    sub_textures_index: u32,

    pub const Index = enum(u32) {
        white_pixel,
        _,

        pub fn subTexture(
            i: Index,
            graphics: *const Graphics,
            sub_index: SubTexture.Index,
        ) SubTexture {
            const sub_i = graphics.texture_arrays.items[@intFromEnum(i)].sub_textures_index;
            return graphics.sub_textures.items[sub_i + @intFromEnum(sub_index)];
        }

        pub fn subTextureSize(
            i: Index,
            graphics: *const Graphics,
            sub_index: SubTexture.Index,
        ) Vec2f {
            const sub_texture = i.subTexture(graphics, sub_index);
            return .init(@floatFromInt(sub_texture.width), @floatFromInt(sub_texture.height));
        }

        pub fn texture(i: Index, graphics: *const Graphics) gl.Texture {
            return graphics.texture_arrays.items[@intFromEnum(i)].texture;
        }

        pub fn size(i: Index, graphics: *const Graphics) Vec2f {
            const t = graphics.texture_arrays.items[@intFromEnum(i)];
            return .init(@floatFromInt(t.width), @floatFromInt(t.height));
        }
    };

    pub const SubTexture = struct {
        width: u32,
        height: u32,

        pub const Index = enum(u32) {
            _,

            pub fn size(
                i: SubTexture.Index,
                graphics: *const Graphics,
                texture_index: TextureArray.Index,
            ) Vec2f {
                return texture_index.subTextureSize(graphics, i);
            }

            pub fn nth(i: u32) SubTexture.Index {
                return @enumFromInt(i);
            }

            pub fn offset(i: SubTexture.Index, off: u32) SubTexture.Index {
                return @enumFromInt(@intFromEnum(i) + off);
            }
        };
    };
};

gpa: mem.Allocator,
quad_program: gl.Program,

sprites: std.ArrayListUnmanaged(Sprite),

texture_arrays: std.ArrayListUnmanaged(TextureArray),
sub_textures: std.ArrayListUnmanaged(TextureArray.SubTexture),

/// Target being drawn to.
target: Target.Index,
targets: std.ArrayListUnmanaged(Target),

instance_program: gl.Program,
instance_vao: gl.VertexArray,
instance_buffer: gl.Buffer,

batch_buf: []InstanceData,
batch_buf_used: bool,

text_program: gl.Program,
fonts: std.ArrayListUnmanaged(Font),

const instances_per_draw = 8_192;
pub const InstanceData = struct {
    index: f32,
    color: Color,
    source: Vec4f,
    matrix: [4][4]f32,
};

pub const GetProcAddressFn = fn ([*:0]const u8) ?*const fn () callconv(.c) void;
fn getProcAddressWrapper(
    getProcAddress: *const GetProcAddressFn,
    proc: [:0]const u8,
) ?gl.binding.FunctionPointer {
    return getProcAddress(proc);
}

pub const Options = struct {
    batch_buf_size: u32 = 8_192,
};

pub fn init(
    gpa: mem.Allocator,
    getProcAddress: *const GetProcAddressFn,
    options: Options,
) mem.Allocator.Error!Graphics {
    gl.loadExtensions(getProcAddress, getProcAddressWrapper) catch unreachable;

    gl.enable(.blend);
    gl.blendFunc(.src_alpha, .one_minus_src_alpha);

    var arena_state: heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();

    const arena = arena_state.allocator();

    const quad_program = try compileProgram(arena, &.{
        .{ .vertex, @embedFile("shaders/quad.vert") },
        .{ .fragment, @embedFile("shaders/quad.frag") },
    });

    const instance_program = try compileProgram(arena, &.{
        .{ .vertex, @embedFile("shaders/instance.vert") },
        .{ .fragment, @embedFile("shaders/instance.frag") },
    });

    const text_program = try compileProgram(arena, &.{
        .{ .vertex, @embedFile("shaders/instance.vert") },
        .{ .fragment, @embedFile("shaders/text.frag") },
    });

    const instance_vao = gl.createVertexArray();

    gl.bindVertexArray(instance_vao);
    defer gl.bindVertexArray(.invalid);

    const instance_buffer = gl.createBuffer();
    gl.bindBuffer(instance_buffer, .array_buffer);
    gl.bufferUninitialized(
        .array_buffer,
        InstanceData,
        instances_per_draw,
        .dynamic_draw,
    );

    // iIndex
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(
        0,
        1,
        .float,
        false,
        @sizeOf(InstanceData),
        @offsetOf(InstanceData, "index"),
    );
    gl.vertexAttribDivisor(0, 1);

    // iColor
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(
        1,
        4,
        .float,
        false,
        @sizeOf(InstanceData),
        @offsetOf(InstanceData, "color"),
    );
    gl.vertexAttribDivisor(1, 1);

    // iSource
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(
        2,
        4,
        .float,
        false,
        @sizeOf(InstanceData),
        @offsetOf(InstanceData, "source"),
    );
    gl.vertexAttribDivisor(2, 1);

    // iMatrix
    for (0..4) |i| {
        const index: u32 = @intCast(i + 3);
        gl.enableVertexAttribArray(index);
        gl.vertexAttribPointer(
            index,
            4,
            .float,
            false,
            @sizeOf(InstanceData),
            @offsetOf(InstanceData, "matrix") + i * @sizeOf([4]f32),
        );
        gl.vertexAttribDivisor(index, 1);
    }

    const sprites_capacity = @typeInfo(Sprite.Index).@"enum".fields.len;
    var sprites: std.ArrayListUnmanaged(Sprite) = try .initCapacity(gpa, sprites_capacity);
    sprites.items.len = sprites_capacity;

    const white_pixel_texture = createTexture(1, 1, .rgba8);

    gl.bindTexture(white_pixel_texture, .@"2d");
    defer gl.bindTexture(.invalid, .@"2d");

    gl.texSubImage2D(
        .@"2d",
        0,
        0,
        0,
        1,
        1,
        .rgba,
        .unsigned_byte,
        &.{ 255, 255, 255, 255 },
    );

    sprites.items[@intFromEnum(Sprite.Index.white_pixel)] = .{
        .texture = white_pixel_texture,
        .width = 1,
        .height = 1,
    };

    const targets_capacity = @typeInfo(Sprite.Index).@"enum".fields.len;
    var targets: std.ArrayListUnmanaged(Target) = try .initCapacity(gpa, targets_capacity);
    targets.items.len = targets_capacity;

    targets.items[@intFromEnum(Target.Index.screen)] = .{
        .screen = .{
            .width = 1,
            .height = 1,
        },
    };

    const texture_arrays_capacity = @typeInfo(TextureArray.Index).@"enum".fields.len;
    const texture_arrays: std.ArrayListUnmanaged(
        TextureArray,
    ) = try .initCapacity(gpa, texture_arrays_capacity);

    var g: Graphics = .{
        .gpa = gpa,
        .quad_program = quad_program,
        .sprites = sprites,
        .texture_arrays = texture_arrays,
        .sub_textures = .empty,
        .target = .screen,
        .targets = targets,
        .instance_program = instance_program,
        .instance_vao = instance_vao,
        .instance_buffer = instance_buffer,
        .batch_buf = try gpa.alloc(InstanceData, options.batch_buf_size),
        .batch_buf_used = false,
        .text_program = text_program,
        .fonts = .empty,
    };

    const white_pixel_texture_array = try g.createTextureArray(gpa, 1, 1, 1, .{});
    assert(white_pixel_texture_array == TextureArray.Index.white_pixel);

    _ = g.setSubTexture(white_pixel_texture_array, 0, 1, 1, .rgba8(&.{ 255, 255, 255, 255 }));
    return g;
}

pub const PixelData = struct {
    data: [*]const u8,

    format: Format,
    type: Type,

    pub const Format = enum {
        red,
        green,
        blue,
        rgba,

        inline fn glPixelFormat(f: Format) gl.PixelFormat {
            return switch (f) {
                .red => .red,
                .green => .green,
                .blue => .blue,
                .rgba => .rgba,
            };
        }
    };

    pub const Type = enum {
        u8,

        inline fn glPixelType(t: Type) gl.PixelType {
            return switch (t) {
                .u8 => .unsigned_byte,
            };
        }
    };

    pub inline fn r8(data: [*]const u8) PixelData {
        return .{
            .data = data,
            .format = .red,
            .type = .u8,
        };
    }

    pub inline fn g8(data: [*]const u8) PixelData {
        return .{
            .data = data,
            .format = .green,
            .type = .u8,
        };
    }

    pub inline fn b8(data: [*]const u8) PixelData {
        return .{
            .data = data,
            .format = .blue,
            .type = .u8,
        };
    }

    pub inline fn rgba8(data: [*]const u8) PixelData {
        return .{
            .data = data,
            .format = .rgba,
            .type = .u8,
        };
    }
};

pub const Filter = enum {
    nearest,
    linear,

    inline fn glMinFilter(f: Filter) gl.TextureParameterType(.min_filter) {
        return switch (f) {
            .linear => .linear,
            .nearest => .nearest,
        };
    }

    inline fn glMagFilter(f: Filter) gl.TextureParameterType(.mag_filter) {
        return switch (f) {
            .linear => .linear,
            .nearest => .nearest,
        };
    }
};

pub const InternalFormat = enum {
    rgba,
    red,

    inline fn glInternalFormat(f: InternalFormat) gl.TextureInternalFormat {
        return switch (f) {
            .rgba => .rgba8,
            .red => .r8,
        };
    }
};

pub const CreateSpriteOptions = struct {
    format: InternalFormat = .rgba,
};

pub fn createSprite(
    g: *Graphics,
    gpa: mem.Allocator,
    width: u32,
    height: u32,
    pixel_data: ?PixelData,
    options: CreateSpriteOptions,
) mem.Allocator.Error!Sprite.Index {
    const texture = createTexture(
        width,
        height,
        options.format.glInternalFormat(),
    );

    if (pixel_data) |data| {
        gl.bindTexture(texture, .@"2d");
        defer gl.bindTexture(.invalid, .@"2d");

        const pixel_format = data.format.glPixelFormat();

        if (pixel_format != .rgba) gl.pixelStore(.unpack_alignment, 1);
        defer gl.pixelStore(.unpack_alignment, 4);

        gl.texSubImage2D(
            .@"2d",
            0,
            0,
            0,
            width,
            height,
            pixel_format,
            data.type.glPixelType(),
            data.data,
        );
    }

    const index: Sprite.Index = @enumFromInt(g.sprites.items.len);
    try g.sprites.append(gpa, .{
        .texture = texture,
        .width = width,
        .height = height,
    });

    return index;
}

pub const CreateTextureArrayOptions = struct {
    format: InternalFormat = .rgba,
};

pub fn createTextureArray(
    g: *Graphics,
    gpa: mem.Allocator,
    width: u32,
    height: u32,
    depth: u32,
    options: CreateTextureArrayOptions,
) mem.Allocator.Error!TextureArray.Index {
    const texture = gl.createTexture(.@"2d_array");

    gl.bindTexture(texture, .@"2d_array");
    defer gl.bindTexture(.invalid, .@"2d_array");

    gl.textureStorage3D(texture, 1, options.format.glInternalFormat(), width, height, depth);

    gl.textureParameter(texture, .wrap_s, .clamp_to_edge);
    gl.textureParameter(texture, .wrap_t, .clamp_to_edge);

    const sub_textures_index: u32 = @intCast(g.sub_textures.items.len);
    try g.sub_textures.appendNTimes(gpa, undefined, depth);

    const index: TextureArray.Index = @enumFromInt(g.texture_arrays.items.len);
    try g.texture_arrays.append(gpa, .{
        .texture = texture,
        .width = width,
        .height = height,
        .depth = depth,
        .sub_textures_index = sub_textures_index,
    });

    return index;
}

pub fn setSubTexture(
    g: *Graphics,
    texture: TextureArray.Index,
    index: u32,
    width: u32,
    height: u32,
    pixel_data: PixelData,
) TextureArray.SubTexture.Index {
    const t = g.texture_arrays.items[@intFromEnum(texture)];
    assert(index < t.depth);
    assert(width <= t.width);
    assert(height <= t.height);

    const pixel_format = pixel_data.format.glPixelFormat();

    if (pixel_format != .rgba) gl.pixelStore(.unpack_alignment, 1);
    defer gl.pixelStore(.unpack_alignment, 4);

    gl.textureSubImage3D(
        t.texture,
        0,
        0,
        0,
        index,
        width,
        height,
        1,
        pixel_format,
        pixel_data.type.glPixelType(),
        pixel_data.data,
    );

    g.sub_textures.items[t.sub_textures_index + index] = .{
        .width = width,
        .height = height,
    };

    return @enumFromInt(index);
}

pub fn createTarget(
    g: *Graphics,
    gpa: mem.Allocator,
    width: u32,
    height: u32,
) mem.Allocator.Error!Target.Index {
    const sprite = try g.createSprite(gpa, width, height, null, .{});
    const buffer = gl.genFramebuffer();

    gl.bindFramebuffer(buffer, .buffer);
    defer gl.bindFramebuffer(.invalid, .buffer);

    gl.framebufferTexture2D(buffer, .buffer, .color0, .@"2d", sprite.texture(g), 0);

    const index: Target.Index = @enumFromInt(g.targets.items.len);
    try g.targets.append(gpa, .{
        .custom = .{
            .sprite = sprite,
            .buffer = buffer,
        },
    });

    return index;
}

pub fn loadFontFile(
    g: *Graphics,
    gpa: mem.Allocator,
    path: []const u8,
    options: LoadFontOptions,
) !Font.Index {
    const bytes = try fs.cwd().readFileAlloc(gpa, path, 1_024_000);
    return g.loadFont(gpa, bytes, options);
}

pub const LoadFontError = error{TrueTypeLoadFailed} || mem.Allocator.Error;
pub const LoadFontOptions = struct {
    codepoints: []const Font.Codepoint = blk: {
        var default: [95]Font.Codepoint = undefined;
        for (0..default.len) |i| default[i] = i + 32;

        const points = default;
        break :blk &points;
    },
    size: f32 = 32,
};

pub fn loadFont(
    g: *Graphics,
    gpa: mem.Allocator,
    bytes: []const u8,
    options: LoadFontOptions,
) LoadFontError!Font.Index {
    const ttf = TrueType.load(bytes) catch return error.TrueTypeLoadFailed;
    const scale = ttf.scaleForPixelHeight(options.size);

    const Bitmap = struct {
        index: u32,
        width: u16,
        height: u16,
    };

    var bitmaps: std.ArrayListUnmanaged(Bitmap) = .empty;
    defer bitmaps.deinit(gpa);

    var bitmap_bytes: std.ArrayListUnmanaged(u8) = .empty;
    defer bitmap_bytes.deinit(gpa);

    var max_width: u16 = 0;
    var max_height: u16 = 0;

    var glyphs: std.AutoHashMapUnmanaged(Font.Codepoint, Font.Glyph) = .empty;
    for (options.codepoints) |codepoint| if (ttf.codepointGlyphIndex(codepoint)) |glyph| {
        const bitmap_bytes_index: u32 = @intCast(bitmap_bytes.items.len);
        const bitmap = ttf.glyphBitmap(
            gpa,
            &bitmap_bytes,
            glyph,
            scale,
            scale,
        ) catch continue;

        if (bitmap.width > max_width) max_width = bitmap.width;
        if (bitmap.height > max_height) max_height = bitmap.height;

        const advance = ttf.glyphHMetrics(glyph).advance_width;
        try glyphs.put(gpa, codepoint, .{
            .bearing = .init(@floatFromInt(bitmap.off_x), @floatFromInt(bitmap.off_y)),
            .advance = @as(f32, @floatFromInt(advance)) * scale,
            .sub_index = @enumFromInt(bitmaps.items.len),
        });

        try bitmaps.append(gpa, .{
            .index = bitmap_bytes_index,
            .width = bitmap.width,
            .height = bitmap.height,
        });
    };

    if (!glyphs.contains(32)) {
        try glyphs.put(gpa, 32, .{
            .bearing = .init(0, 0),
            .advance = @floatFromInt(max_width),
            .sub_index = @enumFromInt(bitmaps.items.len),
        });

        const bitmap_bytes_index: u32 = @intCast(bitmap_bytes.items.len);
        try bitmap_bytes.append(gpa, 255);
        try bitmaps.append(gpa, .{
            .index = bitmap_bytes_index,
            .width = 1,
            .height = 1,
        });
    }

    const texture = try g.createTextureArray(
        gpa,
        max_width,
        max_height,
        @intCast(bitmaps.items.len),
        .{
            .format = .red,
        },
    );

    for (bitmaps.items, 0..) |bitmap, i| {
        const data = bitmap_bytes.items[bitmap.index..].ptr;
        _ = g.setSubTexture(texture, @intCast(i), bitmap.width, bitmap.height, .r8(data));
    }

    const metrics = ttf.verticalMetrics();
    const index: Font.Index = @enumFromInt(g.fonts.items.len);
    try g.fonts.append(gpa, .{
        .texture = texture,
        .descent = @as(f32, @floatFromInt(metrics.descent)) * scale,
        .glyphs = glyphs,
    });

    return index;
}

pub fn setTarget(g: *Graphics, target: Target.Index) void {
    g.target = target;
    gl.viewport(0, 0, g.target.width(g), g.target.height(g));
    switch (target) {
        .screen => {
            gl.bindFramebuffer(.invalid, .buffer);
        },
        else => {
            gl.bindFramebuffer(target.buffer(g), .buffer);
        },
    }
}

pub fn setScreenSize(g: *Graphics, width: u32, height: u32) void {
    g.targets.items[@intFromEnum(Target.Index.screen)].screen = .{
        .width = width,
        .height = height,
    };
}

pub inline fn screenSize(g: *const Graphics) Vec2f {
    const screen = g.targets.items[@intFromEnum(Target.Index.screen)].screen;
    return .init(@floatFromInt(screen.width), @floatFromInt(screen.height));
}

pub fn clearColor(_: Graphics, color: Color) void {
    gl.clearColor(color.r, color.g, color.b, color.a);
    gl.clear(.{ .color = true });
}

pub const DrawQuadOptions = struct {
    position: Vec2f,
    rotation: f32 = 0,
    origin: Vec2f = .splat(0),
    sprite: Sprite.Index = .white_pixel,
    color: Color = .white,
    source: ?Vec4f = null,
    scale: Vec2f = .splat(1),
    mirroring: Mirroring = .none,
    zoom: f32 = 1,
    filter: Filter = .nearest,
};

pub const Mirroring = enum {
    none,
    vertical,
    horizontal,
};

pub fn drawQuad(g: *const Graphics, options: DrawQuadOptions) void {
    gl.useProgram(g.quad_program);
    defer gl.useProgram(.invalid);

    const sprite_size = options.sprite.size(g);
    const source = normalizeSource(options.source, sprite_size, options.mirroring);

    // `uSource`
    gl.uniform4f(0, source.x, source.y, source.z, source.w);

    // `uMatrix`
    const matrix = quadMatrix(
        options.position,
        options.origin,
        options.rotation,
        sprite_size,
        options.scale,
        g.target.size(g),
        options.zoom,
    );
    gl.uniformMatrix4fv(1, false, &.{matrix});

    // `uColor`
    gl.uniform4f(5, options.color.r, options.color.g, options.color.b, options.color.a);

    // `uTexture`
    const texture = options.sprite.texture(g);
    gl.bindTexture(texture, .@"2d");
    gl.textureParameter(texture, .min_filter, options.filter.glMinFilter());
    gl.textureParameter(texture, .mag_filter, options.filter.glMagFilter());

    gl.drawArrays(.triangle_strip, 0, 4);
}

fn normalizeSource(
    source: ?Vec4f,
    sprite_size: Vec2f,
    mirroring: Mirroring,
) Vec4f {
    var out_source: Vec4f = .init(0, 0, 1, 1);
    if (source) |opt_source| {
        out_source = .init(
            opt_source.x / sprite_size.x,
            opt_source.y / sprite_size.y,
            opt_source.z / sprite_size.x,
            opt_source.w / sprite_size.y,
        );
    }

    return switch (mirroring) {
        .none => out_source,
        .vertical => .init(
            out_source.x,
            out_source.y + out_source.w,
            out_source.z,
            -out_source.w,
        ),
        .horizontal => .init(
            out_source.x + out_source.z,
            out_source.y,
            -out_source.z,
            out_source.w,
        ),
    };
}

pub const DrawTextOptions = struct {
    font: Font.Index,
    position: Vec2f,
    pivot: Vec2f = .init(0, 1),
    scale: Vec2f = .splat(1),
    padding: Vec2f = .splat(0),
    color: Color = .white,
};

pub fn drawText(
    g: *Graphics,
    text: []const u8,
    options: DrawTextOptions,
) error{BufferInUse}!void {
    const font = g.fonts.items[@intFromEnum(options.font)];
    var b = try g.batch(.{
        .texture_array = font.texture,
    });
    b.program = g.text_program;
    defer b.flush();

    g.drawTextBatch(&b, text, options);
}

pub fn drawTextBuf(
    g: *Graphics,
    text: []const u8,
    buf: []InstanceData,
    options: DrawTextOptions,
) void {
    const font = g.fonts.items[@intFromEnum(options.font)];
    var b = g.batchBuf(buf, .{
        .texture_array = font.texture,
    });
    b.program = g.text_program;
    defer b.flush();

    g.drawTextBatch(&b, text, options);
}

fn drawTextBatch(
    g: *Graphics,
    b: *Batch,
    text: []const u8,
    options: DrawTextOptions,
) void {
    const font = g.fonts.items[@intFromEnum(options.font)];
    const default_glyph = font.defaultGlyph();

    const font_texture_size = font.texture.size(g);
    const line_height = (font_texture_size.y - font.descent) * options.scale.y +
        options.padding.y;

    var y = options.position.y - line_height;
    if (options.pivot.y != 1) {
        const text_height = @as(
            f32,
            @floatFromInt(mem.count(u8, text, "\n") + 1),
        ) * line_height;
        y += text_height * (1 - options.pivot.y);
    }
    var lines = mem.tokenizeScalar(u8, text, '\n');

    while (lines.next()) |line| {
        var x = options.position.x;
        if (options.pivot.y != 0) {
            const line_width: f32 = font.calculateWidth(line) * options.scale.x;
            x -= line_width * options.pivot.x;
        }

        var it: unicode.Utf8Iterator = .{ .bytes = line, .i = 0 };
        while (it.nextCodepoint()) |codepoint| {
            const glyph = font.glyphs.get(codepoint) orelse default_glyph;
            const glyph_size = glyph.sub_index.size(g, font.texture);

            const position: Vec2f = .init(
                x + glyph.bearing.x * options.scale.x,
                y - (font_texture_size.y + glyph.bearing.y) * options.scale.y,
            );

            x += glyph.advance * options.scale.x + options.padding.x;
            switch (codepoint) {
                '\t', ' ' => continue,
                else => {
                    b.draw(glyph.sub_index, .{
                        .position = position,
                        .scale = .mul(.div(font_texture_size, glyph_size), options.scale),
                    });
                },
            }
        }

        y -= line_height;
    }
}

const Batch = struct {
    graphics: *Graphics,
    texture: TextureArray.Index,
    program: gl.Program,
    filter: Filter,

    len: u32,
    buf: []InstanceData,

    pub const DrawOptions = struct {
        position: Vec2f,
        rotation: f32 = 0,
        origin: Vec2f = .splat(0),
        color: Color = .white,
        source: ?Vec4f = null,
        scale: Vec2f = .splat(1),
        mirroring: Mirroring = .none,
        zoom: f32 = 1,
    };

    /// May do a draw call or not depending if the batch buffer is filled. \
    /// Call `flush` after all draws to make sure the draw call actually happens.
    pub fn draw(b: *Batch, index: TextureArray.SubTexture.Index, options: DrawOptions) void {
        if (b.buf.ptr == b.graphics.batch_buf.ptr) b.graphics.batch_buf_used = true;
        if (b.len == b.buf.len) b.flush();

        const sub_size = b.texture.subTextureSize(b.graphics, index);
        const source = normalizeSource(options.source, sub_size, options.mirroring);
        const matrix = quadMatrix(
            options.position,
            options.origin,
            options.rotation,
            sub_size,
            options.scale,
            b.graphics.target.size(b.graphics),
            options.zoom,
        );

        b.buf[b.len] = .{
            .index = @floatFromInt(@intFromEnum(index)),
            .color = options.color,
            .source = source,
            .matrix = matrix,
        };
        b.len += 1;
    }

    /// If there is anything in the buffer performs a draw call.
    pub fn flush(b: *Batch) void {
        if (b.buf.ptr == b.graphics.batch_buf.ptr) b.graphics.batch_buf_used = false;
        if (b.len == 0) return;
        defer b.len = 0;

        const g = b.graphics;

        gl.bindVertexArray(g.instance_vao);
        defer gl.bindVertexArray(.invalid);

        gl.bindBuffer(g.instance_buffer, .array_buffer);
        defer gl.bindBuffer(.invalid, .array_buffer);

        gl.bufferSubData(.array_buffer, 0, InstanceData, b.buf[0..b.len]);

        const texture = b.texture.texture(b.graphics);
        gl.bindTexture(texture, .@"2d_array");
        gl.textureParameter(texture, .min_filter, b.filter.glMinFilter());
        gl.textureParameter(texture, .mag_filter, b.filter.glMagFilter());

        gl.useProgram(b.program);
        defer gl.useProgram(.invalid);

        gl.drawArraysInstanced(.triangle_strip, 0, 4, b.len);
    }
};

pub const BatchOptions = struct {
    texture_array: TextureArray.Index = .white_pixel,
    filter: Filter = .nearest,
};

/// Creates a batch with a provided buffer. Useful if the default buffer is
/// currently in use.
pub inline fn batchBuf(g: *Graphics, buf: []InstanceData, options: BatchOptions) Batch {
    assert(buf.len > 0);
    return .{
        .graphics = g,
        .texture = options.texture_array,
        .program = g.instance_program,
        .filter = options.filter,

        .buf = buf,
        .len = 0,
    };
}

/// Returns `error.BufferInUse` if the default batch buffer is currently in use.
pub fn batch(
    g: *Graphics,
    options: BatchOptions,
) error{BufferInUse}!Batch {
    if (g.batch_buf_used) return error.BufferInUse;
    g.batch_buf_used = true;

    return .{
        .graphics = g,
        .texture = options.texture_array,
        .program = g.instance_program,
        .filter = options.filter,

        .buf = g.batch_buf,
        .len = 0,
    };
}

fn createTexture(
    width: u32,
    height: u32,
    format: gl.TextureInternalFormat,
) gl.Texture {
    const texture = gl.createTexture(.@"2d");

    gl.bindTexture(texture, .@"2d");
    defer gl.bindTexture(.invalid, .@"2d");

    gl.textureStorage2D(texture, 1, format, width, height);

    gl.textureParameter(texture, .wrap_s, .repeat);
    gl.textureParameter(texture, .wrap_t, .repeat);

    return texture;
}

fn compileProgram(
    arena: mem.Allocator,
    shaders: []const struct { gl.ShaderType, [:0]const u8 },
) mem.Allocator.Error!gl.Program {
    const program = gl.createProgram();
    for (shaders) |s| {
        const ty, const src = s;

        const shader = gl.createShader(ty);
        defer gl.deleteShader(shader);

        gl.shaderSource(shader, 1, &.{src});
        gl.compileShader(shader);

        const info = try gl.getShaderInfoLog(shader, arena);
        if (info.len > 0) log.err("{s}", .{info});

        gl.attachShader(program, shader);
    }

    gl.linkProgram(program);

    const info = try gl.getProgramInfoLog(program, arena);
    if (info.len > 0) log.err("{s}", .{info});

    return program;
}

fn quadMatrix(
    position: Vec2f,
    origin: Vec2f,
    rotation: f32,
    size: Vec2f,
    scale: Vec2f,
    viewport: Vec2f,
    zoom: f32,
) [4][4]f32 {
    const sin = @sin(rotation);
    const cos = @cos(rotation);

    const vx = zoom * 2 / viewport.x;
    const vy = zoom * 2 / viewport.y;

    const px = position.x - viewport.x / 2;
    const py = position.y - viewport.y / 2;

    // zig fmt: off
    return .{
        .{
            // cosr*ssx*sx*vx
            cos * size.x * scale.x * vx,
            // -sinr*ssy*sy*vx
            -sin * size.y * scale.y * vx,
            // 0
            0,
            // cosr*ox*sx*vx - oy*sinr*sy*vx + px*vx
            cos * -origin.x * scale.x * vx
                + origin.y * sin * scale.y * vx
                + px * vx,
        },
        .{
            // sinr*ssx*sx*vy
            sin * size.x * scale.x * vy,
            // cosr*ssy*sy*vy
            cos * size.y * scale.y * vy,
            // 0
            0,
            // cosr*oy*sy*vy + ox*sinr*sx*vy + py*vy
            cos * -origin.y * scale.y * vy
                - origin.x * sin * scale.x * vy
                + py * vy,
        },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
    // zig fmt: on
}
