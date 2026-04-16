const std = @import("std");

const line_length = 12;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    _ = args.next() orelse @panic("invalid arguments. requries fake-xxd <input> <output>");
    const input_path = args.next() orelse @panic("invalid arguments. requries fake-xxd <input> <output>");
    const output_path = args.next() orelse @panic("invalid arguments. requries fake-xxd <input> <output>");
    if (args.next() != null)
        @panic("invalid arguments. requries fake-xxd <input> <output>");

    const blob = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, allocator, .limited(1 << 20));
    defer allocator.free(blob);

    const symbol_name = try allocator.dupe(u8, std.Io.Dir.path.basename(input_path));
    defer allocator.free(symbol_name);

    for (symbol_name) |*c| {
        c.* = switch (c.*) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => c.*,
            else => '_',
        };
    }

    var output_buffer: [1024]u8 = undefined;
    var output = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output.deinit(init.io);

    var file_writer = output.file.writer(init.io, &output_buffer);
    const writer = &file_writer.interface;

    try writer.print("unsigned char {s}[] = {{\n", .{symbol_name});

    for (blob, 0..blob.len) |char, index| {
        if ((index % line_length) == 0) {
            if (index > 0) {
                try writer.writeAll(",\n  ");
            } else {
                try writer.writeAll("  ");
            }
        } else {
            try writer.writeAll(", ");
        }

        try writer.print("0x{X:0>2}", .{char});
    }
    if ((blob.len % line_length) == 0) {
        try writer.writeAll("\n");
    }

    try writer.print("}};\nunsigned int {s}_len = {d};\n", .{ symbol_name, blob.len });

    try file_writer.flush();
    try output.replace(init.io);

    //

}
