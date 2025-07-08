pub fn Vec2(T: type) type {
    return packed struct {
        const Self = @This();

        x: T,
        y: T,

        pub const up: Self = .{ .x = 0, .y = 1 };
        pub const down: Self = .{ .x = 0, .y = -1 };
        pub const right: Self = .{ .x = 1, .y = 0 };
        pub const left: Self = .{ .x = -1, .y = 0 };

        pub inline fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub inline fn splat(scalar: T) Self {
            return .{ .x = scalar, .y = scalar };
        }

        pub inline fn add(lhs: Self, rhs: Self) Self {
            return .{ .x = lhs.x + rhs.x, .y = lhs.y + rhs.y };
        }

        pub inline fn sub(lhs: Self, rhs: Self) Self {
            return .{ .x = lhs.x - rhs.x, .y = lhs.y - rhs.y };
        }

        pub inline fn mul(lhs: Self, rhs: Self) Self {
            return .{ .x = lhs.x * rhs.x, .y = lhs.y * rhs.y };
        }

        pub inline fn div(lhs: Self, rhs: Self) Self {
            return .{ .x = lhs.x / rhs.x, .y = lhs.y / rhs.y };
        }

        pub inline fn scale(vec: Self, scalar: T) Self {
            return .{ .x = vec.x * scalar, .y = vec.y * scalar };
        }

        pub fn lerp(a: Self, b: Self, t: T) Self {
            const SimdVec2 = @Vector(2, T);

            const vec_a: SimdVec2 = @bitCast(a);
            const vec_b: SimdVec2 = @bitCast(b);
            return @bitCast(@mulAdd(
                SimdVec2,
                vec_b - vec_a,
                @splat(t),
                vec_a,
            ));
        }
    };
}

pub fn Vec4(T: type) type {
    return packed struct {
        const Self = @This();
        x: T,
        y: T,
        z: T,
        w: T,

        pub inline fn init(x: T, y: T, z: T, w: T) Self {
            return .{ .x = x, .y = y, .z = z, .w = w };
        }

        pub inline fn splat(scalar: T) Self {
            return .init(scalar, scalar, scalar, scalar);
        }

        pub inline fn add(lhs: Self, rhs: Self) Self {
            return .init(
                lhs.x + rhs.x,
                lhs.y + rhs.y,
                lhs.z + rhs.z,
                lhs.w + rhs.w,
            );
        }

        pub inline fn sub(lhs: Self, rhs: Self) Self {
            return .init(
                lhs.x - rhs.x,
                lhs.y - rhs.y,
                lhs.z - rhs.z,
                lhs.w - rhs.w,
            );
        }

        pub inline fn mul(lhs: Self, rhs: Self) Self {
            return .init(
                lhs.x * rhs.x,
                lhs.y * rhs.y,
                lhs.z * rhs.z,
                lhs.w * rhs.w,
            );
        }

        pub inline fn div(lhs: Self, rhs: Self) Self {
            return .init(
                lhs.x / rhs.x,
                lhs.y / rhs.y,
                lhs.z / rhs.z,
                lhs.w / rhs.w,
            );
        }

        pub inline fn scale(vec: Self, scalar: T) Self {
            return .mul(vec, .splat(scalar));
        }

        pub fn lerp(a: Self, b: Self, t: T) Self {
            const SimdVec4 = @Vector(4, T);

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
}
