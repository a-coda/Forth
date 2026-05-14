const std = @import("std");

pub const demo_source =
    \\: square dup * ;
    \\5 square .
    \\2 3 + .s
    \\words
;

pub const Vm = struct {
    allocator: std.mem.Allocator,
    stack: std.ArrayList(i64),
    dictionary: std.ArrayList(Word),
    output: std.ArrayList(u8),
    current_definition: ?usize,
    expecting_name: bool,

    const Self = @This();

    const Primitive = enum {
        dup,
        drop,
        swap,
        over,
        add,
        sub,
        mul,
        div,
        eq,
        lt,
        dot,
        dot_s,
        emit,
        cr,
        words,
    };

    const Instruction = union(enum) {
        call: usize,
        lit: i64,
        exit,
    };

    const WordKind = union(enum) {
        primitive: Primitive,
        colon: std.ArrayList(Instruction),
    };

    const Word = struct {
        name: []const u8,
        kind: WordKind,
    };

    pub fn init(allocator: std.mem.Allocator) !Self {
        var vm = Self{
            .allocator = allocator,
            .stack = .empty,
            .dictionary = .empty,
            .output = .empty,
            .current_definition = null,
            .expecting_name = false,
        };
        try vm.installPrimitives();
        return vm;
    }

    pub fn deinit(self: *Self) void {
        for (self.dictionary.items) |*word| {
            self.allocator.free(word.name);
            switch (word.kind) {
                .primitive => {},
                .colon => |*code| code.deinit(self.allocator),
            }
        }
        self.dictionary.deinit(self.allocator);
        self.stack.deinit(self.allocator);
        self.output.deinit(self.allocator);
    }

    pub fn interpret(self: *Self, source: []const u8) !void {
        var tokens = std.mem.tokenizeAny(u8, source, " \t\r\n");
        while (tokens.next()) |token| {
            try self.handleToken(token);
        }
    }

    pub fn finish(self: *Self) !void {
        if (self.expecting_name) return error.ExpectedWordName;
        if (self.current_definition != null) return error.UnterminatedDefinition;
    }

    pub fn outputSlice(self: *const Self) []const u8 {
        return self.output.items;
    }

    pub fn stackSlice(self: *const Self) []const i64 {
        return self.stack.items;
    }

    fn installPrimitives(self: *Self) !void {
        try self.addPrimitive("dup", .dup);
        try self.addPrimitive("drop", .drop);
        try self.addPrimitive("swap", .swap);
        try self.addPrimitive("over", .over);
        try self.addPrimitive("+", .add);
        try self.addPrimitive("-", .sub);
        try self.addPrimitive("*", .mul);
        try self.addPrimitive("/", .div);
        try self.addPrimitive("=", .eq);
        try self.addPrimitive("<", .lt);
        try self.addPrimitive(".", .dot);
        try self.addPrimitive(".s", .dot_s);
        try self.addPrimitive("emit", .emit);
        try self.addPrimitive("cr", .cr);
        try self.addPrimitive("words", .words);
    }

    fn addPrimitive(self: *Self, name: []const u8, primitive: Primitive) !void {
        _ = try self.appendWord(name, .{ .primitive = primitive });
    }

    fn appendWord(self: *Self, name: []const u8, kind: WordKind) !usize {
        const owned_name = try self.allocator.dupe(u8, name);
        try self.dictionary.append(self.allocator, .{
            .name = owned_name,
            .kind = kind,
        });
        return self.dictionary.items.len - 1;
    }

    fn handleToken(self: *Self, token: []const u8) !void {
        if (self.expecting_name) {
            try self.beginDefinition(token);
            return;
        }

        if (std.mem.eql(u8, token, ":")) {
            if (self.current_definition != null) return error.NestedDefinition;
            self.expecting_name = true;
            return;
        }

        if (std.mem.eql(u8, token, ";")) {
            try self.endDefinition();
            return;
        }

        if (self.current_definition != null) {
            try self.compileToken(token);
            return;
        }

        try self.executeToken(token);
    }

    fn beginDefinition(self: *Self, name: []const u8) !void {
        if (std.mem.eql(u8, name, ";")) return error.ExpectedWordName;
        const index = try self.appendWord(name, .{ .colon = .empty });
        self.current_definition = index;
        self.expecting_name = false;
    }

    fn endDefinition(self: *Self) !void {
        const code = self.currentCode() orelse return error.UnexpectedSemicolon;
        try code.append(self.allocator, .{ .exit = {} });
        self.current_definition = null;
    }

    fn currentCode(self: *Self) ?*std.ArrayList(Instruction) {
        const index = self.current_definition orelse return null;
        return &self.dictionary.items[index].kind.colon;
    }

    fn compileToken(self: *Self, token: []const u8) !void {
        const code = self.currentCode() orelse return error.UnexpectedSemicolon;
        if (parseNumber(token)) |number| {
            try code.append(self.allocator, .{ .lit = number });
            return;
        }

        const word_index = self.lookupWord(token) orelse return error.UnknownWord;
        try code.append(self.allocator, .{ .call = word_index });
    }

    fn executeToken(self: *Self, token: []const u8) !void {
        if (parseNumber(token)) |number| {
            try self.push(number);
            return;
        }

        const word_index = self.lookupWord(token) orelse return error.UnknownWord;
        try self.executeWord(word_index);
    }

    fn executeWord(self: *Self, word_index: usize) anyerror!void {
        const word = &self.dictionary.items[word_index];
        switch (word.kind) {
            .primitive => |primitive| try self.executePrimitive(primitive),
            .colon => |code| try self.executeThread(code.items),
        }
    }

    fn executeThread(self: *Self, code: []const Instruction) anyerror!void {
        var pc: usize = 0;
        while (pc < code.len) : (pc += 1) {
            switch (code[pc]) {
                .lit => |value| try self.push(value),
                .call => |word_index| try self.executeWord(word_index),
                .exit => return,
            }
        }
    }

    fn executePrimitive(self: *Self, primitive: Primitive) anyerror!void {
        switch (primitive) {
            .dup => {
                try self.push(try self.peek());
            },
            .drop => {
                _ = try self.pop();
            },
            .swap => {
                const first = try self.pop();
                const second = try self.pop();
                try self.push(first);
                try self.push(second);
            },
            .over => {
                if (self.stack.items.len < 2) return error.StackUnderflow;
                try self.push(self.stack.items[self.stack.items.len - 2]);
            },
            .add => {
                const rhs = try self.pop();
                const lhs = try self.pop();
                try self.push(lhs + rhs);
            },
            .sub => {
                const rhs = try self.pop();
                const lhs = try self.pop();
                try self.push(lhs - rhs);
            },
            .mul => {
                const rhs = try self.pop();
                const lhs = try self.pop();
                try self.push(lhs * rhs);
            },
            .div => {
                const rhs = try self.pop();
                const lhs = try self.pop();
                if (rhs == 0) return error.DivisionByZero;
                try self.push(@divTrunc(lhs, rhs));
            },
            .eq => {
                const rhs = try self.pop();
                const lhs = try self.pop();
                try self.push(if (lhs == rhs) -1 else 0);
            },
            .lt => {
                const rhs = try self.pop();
                const lhs = try self.pop();
                try self.push(if (lhs < rhs) -1 else 0);
            },
            .dot => {
                const value = try self.pop();
                try self.writeInt(value);
                try self.writeString(" ");
            },
            .dot_s => {
                try self.writeString("<");
                try self.writeInt(@intCast(self.stack.items.len));
                try self.writeString("> ");
                for (self.stack.items, 0..) |value, index| {
                    if (index != 0) try self.writeString(" ");
                    try self.writeInt(value);
                }
                try self.writeString("\n");
            },
            .emit => {
                const value = try self.pop();
                if (value < 0 or value > 255) return error.InvalidCharacter;
                try self.output.append(self.allocator, @intCast(value));
            },
            .cr => try self.writeString("\n"),
            .words => {
                for (self.dictionary.items, 0..) |word, index| {
                    if (index != 0) try self.writeString(" ");
                    try self.writeString(word.name);
                }
                try self.writeString("\n");
            },
        }
    }

    fn lookupWord(self: *Self, name: []const u8) ?usize {
        var index = self.dictionary.items.len;
        while (index > 0) {
            index -= 1;
            if (std.mem.eql(u8, self.dictionary.items[index].name, name)) return index;
        }
        return null;
    }

    fn push(self: *Self, value: i64) !void {
        try self.stack.append(self.allocator, value);
    }

    fn pop(self: *Self) !i64 {
        if (self.stack.items.len == 0) return error.StackUnderflow;
        return self.stack.pop().?;
    }

    fn peek(self: *Self) !i64 {
        if (self.stack.items.len == 0) return error.StackUnderflow;
        return self.stack.items[self.stack.items.len - 1];
    }

    fn writeString(self: *Self, text: []const u8) !void {
        try self.output.appendSlice(self.allocator, text);
    }

    fn writeInt(self: *Self, value: i64) !void {
        var buffer: [64]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&buffer, "{d}", .{value});
        try self.writeString(formatted);
    }
};

fn parseNumber(token: []const u8) ?i64 {
    return std.fmt.parseInt(i64, token, 10) catch null;
}
