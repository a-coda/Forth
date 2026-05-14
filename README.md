# Simple Forth in Zig

This repository builds a small token-threaded Forth interpreter in Zig 0.16.
The point is to make both systems easy to inspect:

- Zig side: a small `Vm` struct, explicit memory ownership, tagged unions for words and instructions, and a tiny buildable CLI.
- Forth side: a data stack, a dictionary, colon definitions, and an inner interpreter that walks threaded code.

## How it works

Each dictionary entry is a `Word`.
A word is either:

- a primitive such as `dup`, `swap`, `+`, or `.`
- a colon definition containing an array of threaded instructions

The compiled instruction stream uses three instruction kinds:

- `lit` pushes a literal number
- `call` executes another word by dictionary index
- `exit` returns from the current colon definition

That makes the inner interpreter small: it advances a program counter through a colon word and dispatches each instruction.

## Run it

Build and run the built-in demo:

```powershell
zig build run
```

Run your own source directly on the command line:

```powershell
zig build run -- : square dup * ; 9 square .
zig build run -- 2 3 4 + * .s
```

Run the tests:

```powershell
zig build test
```

## Supported words

Numbers, `:`, `;`, `dup`, `drop`, `swap`, `over`, `+`, `-`, `*`, `/`, `=`, `<`, `.`, `.s`, `emit`, `cr`, and `words`.

In Forth tradition, comparison words return `-1` for true and `0` for false.

## Suggested experiments

- Add a return stack instead of using Zig recursion for colon calls.
- Add branching words like `if`, `else`, and `then`.
- Load `.fth` source files instead of passing code on the command line.
