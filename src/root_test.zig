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

test "nested colon calls resume caller after return" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret(": double 2 * ; : fourth double double ; 5 fourth");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 20), vm.stackSlice()[0]);
}

test "deep colon call chain uses runtime return stack" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    var source = std.ArrayList(u8).empty;
    defer source.deinit(std.testing.allocator);

    const depth: usize = 2048;

    var remaining = depth;
    while (remaining > 0) {
        remaining -= 1;
        const index = remaining;

        var buffer: [64]u8 = undefined;
        const definition = try std.fmt.bufPrint(&buffer, ": w{d} ", .{index});
        try source.appendSlice(std.testing.allocator, definition);
        if (index + 1 < depth) {
            const callee = try std.fmt.bufPrint(&buffer, "w{d}", .{index + 1});
            try source.appendSlice(std.testing.allocator, callee);
        } else {
            try source.appendSlice(std.testing.allocator, "1");
        }
        try source.appendSlice(std.testing.allocator, " ; ");
    }

    try source.appendSlice(std.testing.allocator, "w0");

    try vm.interpret(source.items);
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 1), vm.stackSlice()[0]);
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

test "if then executes body for true flag" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret(": maybe-add 1 = if 10 + then ; 5 1 maybe-add");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 15), vm.stackSlice()[0]);
}

test "if then skips body for false flag" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret(": maybe-add 1 = if 10 + then ; 5 2 maybe-add");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 5), vm.stackSlice()[0]);
}

test "if else then selects true branch" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret(": choose 1 = if 100 else 200 then ; 1 choose");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 100), vm.stackSlice()[0]);
}

test "if else then selects false branch" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret(": choose 1 = if 100 else 200 then ; 2 choose");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 1), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, 200), vm.stackSlice()[0]);
}

test "nested if else then works" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.interpret(": classify dup 0 < if drop -1 else dup 0 = if drop 0 else drop 1 then then ; -5 classify 0 classify 9 classify");
    try vm.finish();

    try std.testing.expectEqual(@as(usize, 3), vm.stackSlice().len);
    try std.testing.expectEqual(@as(i64, -1), vm.stackSlice()[0]);
    try std.testing.expectEqual(@as(i64, 0), vm.stackSlice()[1]);
    try std.testing.expectEqual(@as(i64, 1), vm.stackSlice()[2]);
}

test "else without if reports error" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(error.UnexpectedElse, vm.interpret(": bad else ;"));
}

test "then without if reports error" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(error.UnexpectedThen, vm.interpret(": bad then ;"));
}

test "unterminated if reports error when ending definition" {
    var vm = try Forth.Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(error.UnmatchedIf, vm.interpret(": bad if 1 ;"));
}
