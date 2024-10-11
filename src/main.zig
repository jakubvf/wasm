const std = @import("std");

const SectionID = enum(u8) {
    custom_section,
    type_section = 0x1,
    import_section = 0x2,
    function_section = 0x3,
    table_section = 0x4,
    memory_section = 0x5,
    global_section = 0x6,
    export_section = 0x7,
    start_section = 0x8,
    element_section = 0x9,
    code_section = 0xa,
    data_section = 0xb,
};

const Section = struct {
    id: SectionID,
    size: u32, // LE
    contents: SectionContents,
};

const SectionContents = union(enum) {
    type_section: TypeSection,
    import_section: ImportSection,
    function_section: FunctionSection,
    memory_section: MemorySection,
    global_section: GlobalSection,
    export_section: ExportSection,
    start_section: StartSection,
    code_section: CodeSection,
};

const TypeSection = struct {
    types: []FunctionType,
};

const TypeTag = enum(u8) {
    func = 0x60,
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
    imports: []Import,
};

const Import = struct {
    module: []u8,
    name: []u8,
    tag: ImportExportTag,
};

const FunctionSection = struct {
    types: []TypeIndex,
};

const TypeIndex = u32;

// TODO: Table (ID 4) and element  (ID 9) sections

const MemorySection = struct {
    memories: []Limits,
};

const Limits = struct {
    min: u32,
    max: ?u32,
};

const GlobalSection = struct {
    globals: []Global,
};

const Global = struct {
    type: ValueType,
    mutable: bool,
    init: []Instruction,
};
const Instruction = u8; // TODO

const ExportSection = struct {
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
    size: u32, // LE
    function_index: u32, // LE
};

const CodeSection = struct {
    functions: []Code,
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
const wasm_binary_version = 0x1;

const Module = struct {
    magic: u32,
    version: u32,
    sections: []Section,
};

fn parseSection(reader: anytype, allocator: std.mem.Allocator) !Section {
    var section: Section = undefined;
    section.id = try reader.readEnum(SectionID, .little);
    section.size = try reader.readInt(u8, .little);

    switch (section.id) {
        .type_section => {
            section.contents = .{ .type_section = undefined };
            const ts = &section.contents.type_section;
            const num_types = try reader.readInt(u8, .little);
            ts.types = try allocator.alloc(FunctionType, num_types);

            for (ts.types) |*t| {
                t.tag = try reader.readInt(u8, .little);
                const num_params = try reader.readInt(u8, .little);
                t.params = try allocator.alloc(ValueType, num_params);
                for (t.params) |*param| {
                    param.* = try reader.readEnum(ValueType, .little);
                }
                const num_results = try reader.readInt(u8, .little);
                t.results = try allocator.alloc(ValueType, num_results);
                for (t.results) |*result| {
                    result.* = try reader.readEnum(ValueType, .little);
                }
            }
        },
        .function_section => {
            section.contents = .{ .function_section = undefined };
            const fs = &section.contents.function_section;
            const num_functions = try reader.readInt(u8, .little);
            fs.types = try allocator.alloc(TypeIndex, num_functions);
            for (fs.types) |*type_index| {
                type_index.* = try reader.readInt(u8, .little);
            }
        },
        .export_section => {
            section.contents = .{ .export_section = undefined };
            const es = &section.contents.export_section;
            const num_exports = try reader.readInt(u8, .little);
            es.exports = try allocator.alloc(Export, num_exports);
            for (es.exports) |*e| {
                const export_name_len = try reader.readInt(u8, .little);
                e.name = try allocator.alloc(u8, export_name_len);
                if (try reader.readAll(e.name) != export_name_len) {
                    return error.InvalidWasmFile;
                }
                e.tag = try reader.readEnum(ImportExportTag, .little);
                e.index = try reader.readInt(u8, .little);
            }
        },
        .code_section => {
            section.contents = .{ .code_section = undefined };
            const cs = &section.contents.code_section;
            const num_functions = try reader.readInt(u8, .little);
            cs.functions = try allocator.alloc(Code, num_functions);
            for (cs.functions) |*f| {
                f.size = try reader.readInt(u8, .little);
                const num_locals = try reader.readInt(u8, .little);
                f.locals = try allocator.alloc(Local, num_locals);
                for (f.locals) |*local| {
                    std.debug.assert(false); // Untested
                    local.count = try reader.readInt(u8, .little);
                    local.type = try reader.readEnum(ValueType, .little);
                }
                f.body = try allocator.alloc(Instruction, f.size - 1); // - 1 for locals
                if (try reader.readAll(f.body) != f.size - 1) {
                    return error.InvalidWasmFile;
                }
            }
        },
        else => return error.UnsupportedSection,
    }
    return section;
}

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
    std.debug.print("{any}\n", .{try parseSection(reader, allocator)});
    std.debug.print("{any}\n", .{try parseSection(reader, allocator)});
    std.debug.print("{any}\n", .{try parseSection(reader, allocator)});
    std.debug.print("{any}\n", .{try parseSection(reader, allocator)});
    std.debug.print("End? {}\n", .{try file.getEndPos() == try file.getPos()});
}
