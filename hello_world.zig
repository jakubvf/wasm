const hello_world = "Hello, world!\n\x00";

extern fn printString([*]const u8) void;

pub export fn main() void {
    printString(hello_world);
}