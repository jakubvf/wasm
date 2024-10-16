const std = @import("std");
const wasm = std.wasm;

const TypeSection = struct {
    types: []std.wasm.Type,
};

const ImportSection = struct {
    imports: []Import,

    const Import = struct {
        module: []u8,
        name: []u8,
        tag: wasm.ExternalKind,
    };
};

const FunctionSection = struct {
    types: []TypeIndex,
    const TypeIndex = u32;
};

// TODO: Table (ID 4) and element  (ID 9) sections

const MemorySection = struct {
    memories: []Limits,

    const Limits = struct {
        min: u32,
        max: ?u32,
    };
};

const GlobalSection = struct {
    globals: []Global,

    const Global = struct {
        type: wasm.Valtype,
        mutable: bool,
        init: []u8,
    };
};

const ExportSection = struct {
    exports: []Export,

    const Export = struct {
        name: []u8,
        tag: wasm.ExternalKind,
        index: u32,
    };
};

const StartSection = struct {
    size: u32,
    function_index: u32,
};

const CodeSection = struct {
    functions: []Code,

    const Code = struct {
        size: u32,
        locals: []Local,
        body: []u8,
    };
    const Local = struct {
        count: u32,
        type: wasm.Valtype,
    };
};

const Module = struct {
    // TODO: custom section
    type_section: ?TypeSection = null,
    import_section: ?ImportSection = null,
    function_section: ?FunctionSection = null,
    // TODO: table section
    // TODO: memory section
    global_section: ?GlobalSection = null,
    export_section: ?ExportSection = null,
    start_section: ?StartSection = null,
    // TODO: element section
    code_section: ?CodeSection = null,
    // TODO: data section
    // TODO: data count section

    const Section = union(enum) {
        type_section: TypeSection,
        import_section: ImportSection,
        function_section: FunctionSection,
        memory_section: MemorySection,
        global_section: GlobalSection,
        export_section: ExportSection,
        start_section: StartSection,
        code_section: CodeSection,
    };

    pub fn init(allocator: std.mem.Allocator, bytecode: []const u8) !Module {
        var module = Module{};

        var fbs = std.io.fixedBufferStream(bytecode);
        const reader = fbs.reader();
        if (!try reader.isBytes(&std.wasm.magic)) {
            return error.InvalidWasmFile;
        }
        if (try reader.readInt(u32, .little) != 1) {
            return error.UnsupportedWasmVersion;
        }
        while (try fbs.getEndPos() != try fbs.getPos()) {
            const section = try parseSection(reader, allocator);
            switch (section) {
                .type_section => |s| {
                    module.type_section = s;
                    std.debug.print("{any}\n", .{s});
                },
                .import_section => |s| {
                    module.import_section = s;
                    std.debug.print("{any}\n", .{s});
                },
                .function_section => |s| {
                    module.function_section = s;
                    std.debug.print("{any}\n", .{s});
                },
                .global_section => |s| {
                    module.global_section = s;
                    std.debug.print("{any}\n", .{s});
                },
                .export_section => |s| {
                    module.export_section = s;
                    std.debug.print("{any}\n", .{s});
                },
                .start_section => |s| {
                    module.start_section = s;
                    std.debug.print("{any}\n", .{s});
                },
                .code_section => |s| {
                    module.code_section = s;
                    std.debug.print("{any}\n", .{s});
                },
                else => return error.UnsupportedSection,
            }
        }

        return module;
    }

    pub fn deinit(module: *Module, allocator: std.mem.Allocator) void {
        if (module.export_section) |es| {
            for (es.exports) |e| {
                allocator.free(e.name);
            }
        }
        if (module.code_section) |cs| {
            for (cs.functions) |f| {
                for (f.locals) |l| {
                    allocator.free(l);
                }
                allocator.free(f.locals);
                allocator.free(f.body);
            }
            allocator.free(cs.functions);
        }
    }

    pub fn format(self: Module, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        _ = opt;
        try writer.print("{s} section (size: {d}):\n", .{ @tagName(self.id), self.size });
        if (self.type_section) |ts| {
            for (ts.types) |t| {
                try writer.writeAll("  type: (");
                for (t.params) |param| {
                    try writer.print("{s} ", .{@tagName(param)});
                }
                try writer.writeAll(") -> (");
                for (t.returns) |result| {
                    try writer.print("{s} ", .{@tagName(result)});
                }
                try writer.writeAll(")\n");
            }
        }
        if (self.function_section) |fs| {
            for (fs.types) |type_index| {
                try writer.print("  function type index: {d}\n", .{type_index});
            }
        }
        if (self.export_section) |es| {
            for (es.exports) |e| {
                try writer.print("  export: {s} (tag: {s}, index: {d})\n", .{ e.name, @tagName(e.tag), e.index });
            }
        }
        if (self.code_section) |cs| {
            for (cs.functions) |f| {
                try writer.print("  function body size: {d}\n", .{f.size});
                for (f.locals) |l| {
                    try writer.print("    local count: {d}, type: {s}\n", .{ l.count, @tagName(l.type) });
                }
            }
        }
    }

    fn parseSection(reader: anytype, allocator: std.mem.Allocator) !Section {
        var section: Section = switch (try reader.readEnum(wasm.Section, .little)) {
            .type => .{ .type_section = undefined },
            .import => .{ .import_section = undefined },
            .function => .{ .function_section = undefined },
            .memory => .{ .memory_section = undefined },
            .global => .{ .global_section = undefined },
            .@"export" => .{ .export_section = undefined },
            .start => .{ .start_section = undefined },
            .element => return error.UnsupportedWasmSection,
            .code => .{ .code_section = undefined },
            .data => return error.UnsupportedWasmSection,
            else => return error.UnsupportedWasmSection,
        };
        _ = try std.leb.readULEB128(u64, reader);

        switch (section) {
            .type_section => {
                const ts = &section.type_section;
                const num_types = try reader.readInt(u8, .little);
                ts.types = try allocator.alloc(@TypeOf(ts.types[0]), num_types);

                for (ts.types) |*t| {
                    if (!try reader.isBytes("\x60")) {
                        std.log.err("non-function types are not supported\n", .{});
                        return error.InvalidWasmFile;
                    }
                    const num_params = try reader.readInt(u8, .little);
                    const params = try allocator.alloc(wasm.Valtype, num_params);
                    for (params) |*param| {
                        param.* = try reader.readEnum(wasm.Valtype, .little);
                    }
                    const num_results = try reader.readInt(u8, .little);
                    const returns = try allocator.alloc(wasm.Valtype, num_results);
                    for (returns) |*result| {
                        result.* = try reader.readEnum(wasm.Valtype, .little);
                    }
                    t.params = params;
                    t.returns = returns;
                }
            },
            .function_section => {
                const fs = &section.function_section;
                const num_functions = try reader.readInt(u8, .little);
                fs.types = try allocator.alloc(FunctionSection.TypeIndex, num_functions);
                for (fs.types) |*type_index| {
                    type_index.* = try reader.readInt(u8, .little);
                }
            },
            .export_section => {
                const es = &section.export_section;
                const num_exports = try reader.readInt(u8, .little);
                es.exports = try allocator.alloc(ExportSection.Export, num_exports);
                for (es.exports) |*e| {
                    const export_name_len = try reader.readInt(u8, .little);
                    e.name = try allocator.alloc(u8, export_name_len);
                    if (try reader.readAll(e.name) != export_name_len) {
                        return error.InvalidWasmFile;
                    }
                    e.tag = try reader.readEnum(wasm.ExternalKind, .little);
                    e.index = try reader.readInt(u8, .little);
                }
            },
            .code_section => {
                const cs = &section.code_section;
                const num_functions = try reader.readInt(u8, .little);
                cs.functions = try allocator.alloc(CodeSection.Code, num_functions);
                for (cs.functions) |*f| {
                    f.size = try reader.readInt(u8, .little);
                    const num_locals = try reader.readInt(u8, .little);
                    f.locals = try allocator.alloc(CodeSection.Local, num_locals);
                    for (f.locals) |*local| {
                        std.debug.assert(false); // Untested
                        local.count = try reader.readInt(u8, .little);
                        local.type = try reader.readEnum(wasm.Valtype, .little);
                    }
                    f.body = try allocator.alloc(u8, f.size - 1); // - 1 for locals count
                    if (try reader.readAll(f.body) != f.size - 1) {
                        return error.InvalidWasmFile;
                    }
                }
            },
            else => return error.UnsupportedSection,
        }
        return section;
    }
};

const Value = union(enum) {
    i32: i32,

    pub fn format(self: Value, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        _ = opt;

        switch (self) {
            .i32 => try writer.print("{} (i32)", .{self.i32}),
        }
    }
};

const VirtualMachine = struct {
    stack: std.ArrayList(Value),
    frames: std.ArrayList(Frame),
    module: Module,

    pub fn execute(vm: *VirtualMachine, input: Frame) !void {
        try vm.frames.append(input);
        defer {
            var frame = vm.frames.pop();
            frame.locals.deinit();
        }

        var idk = vm.frames.items[vm.frames.items.len - 1];
        const reader = idk.code.reader();
        while (try idk.code.getPos() != try idk.code.getEndPos()) {
            const opcode: std.wasm.Opcode = @enumFromInt(try reader.readByte());
            switch (opcode) {
                .local_get => {
                    const local_index = try reader.readByte();
                    try vm.stack.append(.{ .i32 = local_index });
                    std.debug.print("local_get idx({}) => {any}\n", .{ local_index, vm.stack.getLast() });
                },
                .i32_add => {
                    const b = vm.stack.pop().i32;
                    const a = vm.stack.pop().i32;
                    const result = idk.locals.items[@intCast(a)].i32 + idk.locals.items[@intCast(b)].i32;
                    try vm.stack.append(.{ .i32 = result });
                    std.debug.print("i32_add idx({}) + idx({}) => {}\n", .{ a, b, result });
                },
                .i32_const => {
                    const value = try std.leb.readILEB128(i32, reader);
                    try vm.stack.append(.{ .i32 = value });
                    std.debug.print("i32_const {}\n", .{value});
                },
                .call => {
                    const func_idx = try reader.readByte();
                    std.debug.print("call func_idx({}) {any}\n", .{ func_idx, vm.module.type_section.?.types[func_idx] });
                    var frame = Frame{ .locals = std.ArrayList(Value).init(vm.stack.allocator), .code = .{ .buffer = vm.module.code_section.?.functions[func_idx].body, .pos = 0 } };
                    for (vm.module.type_section.?.types[func_idx].params) |_| {
                        try frame.locals.append(vm.stack.pop());
                    }
                    try vm.execute(frame);
                },
                .end => {
                    std.debug.print("==end==\n", .{});
                    for (vm.stack.items, 0..) |item, idx| {
                        std.debug.print("  {}: {}\n", .{ idx, item });
                    }
                    return;
                },
                else => {
                    std.debug.print("Unknown opcode {}\n", .{opcode});
                    return;
                },
            }
        }
    }
};

const Frame = struct {
    code: std.io.FixedBufferStream([]const u8),
    locals: std.ArrayList(Value),
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    const file = try std.fs.cwd().openFile("test2.wasm", .{});
    defer file.close();

    const module = try Module.init(allocator, try file.readToEndAlloc(allocator, 1024 * 1024));
    var vm = VirtualMachine{
        .frames = std.ArrayList(Frame).init(allocator),
        .stack = std.ArrayList(Value).init(allocator),
        .module = module,
    };
    defer vm.stack.deinit();

    try vm.execute(Frame{
        .locals = std.ArrayList(Value).init(allocator),
        .code = .{ .buffer = vm.module.code_section.?.functions[1].body, .pos = 0 },
    });
}
