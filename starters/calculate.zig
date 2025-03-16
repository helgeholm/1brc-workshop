pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}).init;
    const alloc = da.allocator();
    defer _ = da.deinit();
    var aa = std.heap.ArenaAllocator.init(alloc);
    const key_alloc = aa.allocator();
    defer aa.deinit();
    var file = try std.fs.cwd().openFile("measurements.txt", .{});
    defer file.close();
    var results = std.StringHashMap(StationData).init(alloc);
    defer results.deinit();

    var br = std.io.bufferedReader(file.reader());
    var brr = br.reader();
    var buf: [128]u8 = undefined;
    while (try brr.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const key = std.mem.sliceTo(line, ';');
        const val = try std.fmt.parseFloat(f64, line[key.len + 1 ..]);
        var entry = try results.getOrPutAdapted(key, results.ctx);
        if (entry.found_existing) {
            entry.value_ptr.sum += val;
            entry.value_ptr.min = @min(entry.value_ptr.min, val);
            entry.value_ptr.max = @max(entry.value_ptr.max, val);
            entry.value_ptr.count += 1;
        } else {
            const alloc_key = try key_alloc.dupe(u8, key);
            entry.key_ptr.* = alloc_key;
            entry.value_ptr.sum = val;
            entry.value_ptr.min = val;
            entry.value_ptr.max = val;
            entry.value_ptr.count = 1;
        }
    }

    var it = results.iterator();
    while (it.next()) |entry| {
        std.debug.print("{s};{}\n", .{ entry.key_ptr.*, entry.value_ptr });
    }
}

const StationData = struct {
    sum: f64,
    min: f64,
    max: f64,
    count: usize,
    pub fn format(self: StationData, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const mean = self.sum / @as(f64, @floatFromInt(self.count));
        try writer.print("{d:.2};{d:.2};{d:.2}", .{ self.min, mean, self.max });
    }
};

const std = @import("std");
