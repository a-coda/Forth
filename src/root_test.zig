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

test "drop removes the top value" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("1 2 drop");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 1), vm.stackSlice()[0]);
}

test "swap exchanges top two values" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("10 20 swap");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 2), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 20), vm.stackSlice()[0]);
    try std.testing.expectEqual(@as(i64, 10), vm.stackSlice()[1]);
}

test "over copies second item to top" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("3 7 over");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 3), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 3), vm.stackSlice()[0]);
    try std.testing.expectEqual(@as(i64, 7), vm.stackSlice()[1]);
    try std.testing.expectEqual(@as(i64, 3), vm.stackSlice()[2]);
}

test "subtraction and division work" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("10 3 - 14 3 /");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 2), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 7), vm.stackSlice()[0]);
    try std.testing.expectEqual(@as(i64, 4), vm.stackSlice()[1]);
}

test "dot_s prints stack snapshot" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("2 3 4 .s");
    try vm.finish();

    try std.testing.expectEqualStrings("<3> 2 3 4\n", vm.outputSlice());
    try std.testing.expectEqual(@as(usize, 3), vm.stackSlice().len);
}

test "emit and cr produce characters" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("65 emit cr");
    try vm.finish();

    try std.testing.expectEqualStrings("A\n", vm.outputSlice());
}

test "words lists dictionary entries" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("words");
    try vm.finish();

    const expected = "dup drop swap over + - * / = < . .s emit cr words\n";
    try std.testing.expectEqualStrings(expected, vm.outputSlice());
}

test "division by zero returns error" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(error.DivisionByZero, vm.interpret("1 0 /"));
}

test "stack underflow is reported" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(error.StackUnderflow, vm.interpret("drop"));
}

test "emit validates character range" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(error.InvalidCharacter, vm.interpret("256 emit"));
}

test "equality comparison = returns -1 for true" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("5 5 =");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, -1), vm.stackSlice()[0]);
}

test "equality comparison = returns 0 for false" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("5 3 =");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 0), vm.stackSlice()[0]);
}

test "less-than comparison < returns -1 for true" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("3 5 <");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, -1), vm.stackSlice()[0]);
}

test "less-than comparison < returns 0 for false" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("5 3 <");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 0), vm.stackSlice()[0]);
}

test "less-than comparison < returns 0 when equal" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret("5 5 <");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 0), vm.stackSlice()[0]);
}
