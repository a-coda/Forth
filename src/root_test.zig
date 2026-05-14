const std = @import("std");
const Forth = @import("Forth");

test "primitives manipulate the stack" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("2 3 + 4 *");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 20), vm.stackSlice()[0]);
}

test "colon definitions compile threaded code" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret(": square dup * ; 5 square .");
    try vm.finish();

    try std.testing.expectEqualStrings("25 ", vm.outputSlice());
    try std.testing.expectEqual(@as(usize, 0), vm.stackSlice().len);
}
