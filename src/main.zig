const std = @import("std");

const SectionID = enum(u8) {
    custom_id,
    type_id,
    import_id,
    function_id,
    table_id,
    memory_id,
    global_id,
    export_id,
    start_id,
    element_id,
    code_id,
    data_id,
};

const Section = struct {
    id: SectionID,
    size: u32, // LE
    contents: []u8,
};

const TypeSection = struct {
    id: u8 = 0x1,
    size: u32, // LE
    types: []FunctionType,
};

const FunctionType = struct {
    tag: u8 = 0x60,
    params: []ValueType,
    results: []ValueType,
};

const ValueType = enum(u8) {
    int32 = 0x7f,
    int64 = 0x7e,
    float32 = 0x7d,
    float64 = 0x7c,
};

const ImportSection = struct {
    id: u8 = 0x2,
    size: u32, // LE
    imports: []Import,
};

const Import = struct {
    module: []u8,
    name: []u8,
    tag: ImportExportTag,
};

const FunctionSection = struct {
    id: u8 = 0x3,
    size: u32, // LE
    types: []TypeIndex, // []LE
};

const TypeIndex = u32; // LE

// TODO: Table (ID 4) and element  (ID 9) sections

const MemorySection = struct {
    id: u8 = 0x5,
    size: u32, // LE
    memories: []Limits,
};

const Limits = struct {
    min: u32, // LE
    max: ?u32, // LE
};

const GlobalSection = struct {
    id: u8 = 0x6,
    size: u32, // LE
    globals: []Global,
};

const Global = struct {
    type: ValueType,
    mutable: bool,
    init: []Instruction,
};
const Instruction = u8; // TODO

const ExportSection = struct {
    id: u8 = 0x7,
    size: u32, // LE
    exports: []Export,
};

const Export = struct {
    name: []u8,
    tag: ImportExportTag,
    index: u32, // LE
};

const ImportExportTag = enum(u8) {
    function = 0x0,
    table = 0x1,
    memory = 0x2,
    global = 0x3,
};

const StartSection = struct {
    id: u8 = 0x8,
    size: u32, // LE
    function_index: u32, // LE
};

const CodeSection = struct {
    id: u8 = 10,
    size: u32, // LE
    codes: []Code,
};

const Code = struct {
    size: u32, // LE
    locals: []Local,
    body: []Instruction,
};

const Local = struct {
    count: u32, // LE
    type: ValueType,
};

const wasm_binary_magic = 0x0061736d;
const wasm_binary_version = 0x1; // LE

const Module = struct {
    magic: u32,
    version: u32,
    sections: []Section,
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    const file = try std.fs.cwd().openFile("test1.wasm", .{});
    defer file.close();

    const reader = file.reader();
    if (!try reader.isBytes("\x00asm")) {
        return error.InvalidWasmFile;
    }
    if (try reader.readInt(u32, .little) != 1) {
        return error.UnsupportedWasmVersion;
    }
    // Type section
    const section_code = try reader.readInt(u8, .little);
    std.debug.print("Section code: {}\n", .{section_code});
    const section_size = try reader.readInt(u8, .little);
    std.debug.print("Section size: {}\n", .{section_size});
    const num_types = try reader.readInt(u8, .little);
    std.debug.print("Number of types: {}\n", .{num_types});
    const function_type = try reader.readInt(u8, .little);
    std.debug.print("Function type: {}\n", .{function_type});
    const num_params = try reader.readInt(u8, .little);
    std.debug.print("Number of params: {}\n", .{num_params});
    const param_type1 = try reader.readInt(u8, .little);
    std.debug.print("Param type: {}\n", .{param_type1});
    const param_type2 = try reader.readInt(u8, .little);
    std.debug.print("Param type: {}\n", .{param_type2});
    const num_results = try reader.readInt(u8, .little);
    std.debug.print("Number of results: {}\n", .{num_results});
    const result_type = try reader.readInt(u8, .little);
    std.debug.print("Result type: {}\n", .{result_type});
    // Function section
    const section_code2 = try reader.readInt(u8, .little);
    std.debug.print("Section code: {}\n", .{section_code2});
    const section_size2 = try reader.readInt(u8, .little);
    std.debug.print("Section size: {}\n", .{section_size2});
    const num_functions = try reader.readInt(u8, .little);
    std.debug.print("Number of functions: {}\n", .{num_functions});
    const signature_index = try reader.readInt(u8, .little);
    std.debug.print("Signature index: {}\n", .{signature_index});
    // Export section
    const section_code3 = try reader.readInt(u8, .little);
    std.debug.print("Section code: {}\n", .{section_code3});
    const section_size3 = try reader.readInt(u8, .little);
    std.debug.print("Section size: {}\n", .{section_size3});
    const num_exports = try reader.readInt(u8, .little);
    std.debug.print("Number of exports: {}\n", .{num_exports});
    const export_name_len = try reader.readInt(u8, .little);
    std.debug.print("Export name length: {}\n", .{export_name_len});
    const export_name = try allocator.alloc(u8, export_name_len);
    if (try reader.read(export_name) == 0) {
        return error.InvalidWasmFile;
    }
    std.debug.print("Export name: {s}\n", .{export_name});
    const export_kind = try reader.readInt(u8, .little);
    std.debug.print("Export kind: {}\n", .{export_kind});
    const export_index = try reader.readInt(u8, .little);
    std.debug.print("Export index: {}\n", .{export_index});
    // Code section
    const section_code4 = try reader.readInt(u8, .little);
    std.debug.print("Section code: {}\n", .{section_code4});
    const section_size4 = try reader.readInt(u8, .little);
    std.debug.print("Section size: {}\n", .{section_size4});
    const num_functions2 = try reader.readInt(u8, .little);
    std.debug.print("Number of functions: {}\n", .{num_functions2});
    const body_size = try reader.readInt(u8, .little);
    std.debug.print("Body size: {}\n", .{body_size});
    const locals_count = try reader.readInt(u8, .little);
    std.debug.print("Locals count: {}\n", .{locals_count});
    try reader.skipUntilDelimiterOrEof('\x0b');
    std.debug.print("End? {}\n", .{try file.getEndPos() == try file.getPos()});
}
