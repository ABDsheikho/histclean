const std = @import("std");
const testing = std.testing;
const histclean = @import("histclean");

test "fuzz: filterLines with arbitrary bytes" {
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    var i: usize = 0;
    while (i < 200) : (i += 1) {
        const len = random.uintLessThan(usize, 512);
        const input = try testing.allocator.alloc(u8, len);
        defer testing.allocator.free(input);

        for (input) |*byte| byte.* = random.int(u8);

        var result = histclean.filterLines(input, testing.allocator) catch continue;
        defer result.deinit(testing.allocator);

        // Every returned slice must point into the input
        for (result.items) |item| {
            const s = @intFromPtr(item.ptr);
            const start = @intFromPtr(input.ptr);
            try testing.expect(s >= start and s + item.len <= start + input.len);
        }
    }
}

test "fuzz: filterLines results are deterministic" {
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const len = random.uintLessThan(usize, 256);
        const input = try testing.allocator.alloc(u8, len);
        defer testing.allocator.free(input);

        for (input) |*byte| byte.* = random.int(u8);

        var r1 = try histclean.filterLines(input, testing.allocator);
        defer r1.deinit(testing.allocator);

        var r2 = try histclean.filterLines(input, testing.allocator);
        defer r2.deinit(testing.allocator);

        try testing.expectEqual(r1.items.len, r2.items.len);
    }
}

test "fuzz: filterLines with shell-like data has no duplicates" {
    var prng = std.Random.DefaultPrng.init(99);
    const random = prng.random();
    const chars = "echo ls cd cat #1234567890\n";

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const len = random.uintLessThan(usize, 256);
        const input = try testing.allocator.alloc(u8, len);
        defer testing.allocator.free(input);

        for (input) |*byte| byte.* = chars[random.uintLessThan(usize, chars.len)];

        var result = histclean.filterLines(input, testing.allocator) catch continue;
        defer result.deinit(testing.allocator);

        for (result.items, 0..) |a, i_| {
            var j: usize = i_ + 1;
            while (j < result.items.len) : (j += 1) {
                const dup = std.mem.eql(u8, a, result.items[j]);
                // Empty lines (from consecutive newlines) are allowed dupes
                if (dup and a.len != 0) {
                    try testing.expect(false);
                }
            }
        }
    }
}
