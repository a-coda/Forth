const std = @import("std");
const Io = std.Io;

const Forth = @import("Forth");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    const stderr_writer = &stderr_file_writer.interface;

    var vm = try Forth.Vm.init(arena);
    defer vm.deinit();

    const source = if (args.len > 1)
        try std.mem.join(arena, " ", args[1..])
    else
        Forth.demo_source;

    if (args.len == 1) {
        try stdout_writer.writeAll("Simple token-threaded Forth in Zig\n\n");
        try stdout_writer.writeAll("Demo source:\n");
        try stdout_writer.writeAll(Forth.demo_source);
        try stdout_writer.writeAll("\nOutput:\n");
    }

    vm.interpret(source) catch |err| {
        try stderr_writer.print("error: {s}\n", .{@errorName(err)});
        try stderr_writer.flush();
        return err;
    };
    try vm.finish();

    try stdout_writer.writeAll(vm.outputSlice());
    if (vm.stackSlice().len > 0) {
        try stdout_writer.print("\nStack: <{d}>", .{vm.stackSlice().len});
        for (vm.stackSlice()) |value| {
            try stdout_writer.print(" {d}", .{value});
        }
        try stdout_writer.writeAll("\n");
    }

    if (args.len == 1) {
        try stdout_writer.writeAll("\nRun `zig build run -- : square dup * ; 9 square .` to execute your own source.\n");
    }

    try stdout_writer.flush();
}
