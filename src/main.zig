const std = @import("std");
const wasm = std.wasm;

const CustomSection = struct {};

const TypeSection = struct {
    types: []std.wasm.Type,
};

const ImportSection = struct {
    imports: []Import,

    const Import = struct {
        module: []u8,
        name: []u8,
        tag: wasm.ExternalKind,
        idx: uleb,
    };
};

const FunctionSection = struct {
    types: []TypeIndex,
    const TypeIndex = u32;
};

// TODO: Table (ID 4) and element  (ID 9) sections

const MemorySection = struct {
    memories: []wasm.Limits,
};

const GlobalSection = struct {
    globals: []Global,

    const Global = struct {
        type: wasm.Valtype,
        mutable: bool,
        init: []const u8,
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

const DataSection = struct {
    data: []Data,

    const Data = struct {
        memory_index: u32,
        offset: u32,
        data: []u8,
    };
};

const Module = struct {
    // TODO: custom section
    type_section: ?TypeSection = null,
    import_section: ?ImportSection = null,
    function_section: ?FunctionSection = null,
    // TODO: table section
    memory_section: ?MemorySection = null,
    global_section: ?GlobalSection = null,
    export_section: ?ExportSection = null,
    start_section: ?StartSection = null,
    // TODO: element section
    code_section: ?CodeSection = null,
    data_section: ?DataSection = null,
    // TODO: data count section

    const Section = union(enum) {
        custom_section: CustomSection,
        type_section: TypeSection,
        import_section: ImportSection,
        function_section: FunctionSection,
        memory_section: MemorySection,
        global_section: GlobalSection,
        export_section: ExportSection,
        start_section: StartSection,
        code_section: CodeSection,
        data_section: DataSection,
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
                .custom_section => |s| {
                    std.debug.print("{any}\n", .{s});
                },
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
                .memory_section => |s| {
                    module.memory_section = s;
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
                .data_section => |s| {
                    module.data_section = s;
                    std.debug.print("{any}\n", .{s});
                },
            }
        }

        return module;
    }

    pub fn deinit(module: *Module, allocator: std.mem.Allocator) void {
        if (module.export_section) |es| {
            for (es.exports) |e| {
                allocator.free(e.name);
            }
            allocator.free(es.exports);
        }
        if (module.code_section) |cs| {
            for (cs.functions) |f| {
                allocator.free(f.locals);
                allocator.free(f.body);
            }
            allocator.free(cs.functions);
        }
        if (module.type_section) |ts| {
            for (ts.types) |t| {
                allocator.free(t.params);
                allocator.free(t.returns);
            }
            allocator.free(ts.types);
        }
        if (module.function_section) |fs| {
            allocator.free(fs.types);
        }
        if (module.import_section) |is| {
            for (is.imports) |i| {
                allocator.free(i.module);
                allocator.free(i.name);
            }
            allocator.free(is.imports);
        }

        if (module.global_section) |gs| {
            for (gs.globals) |g| {
                allocator.free(g.init);
            }
            allocator.free(gs.globals);
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
            .custom => .{ .custom_section = undefined },
            .type => .{ .type_section = undefined },
            .import => .{ .import_section = undefined },
            .function => .{ .function_section = undefined },
            .memory => .{ .memory_section = undefined },
            .global => .{ .global_section = undefined },
            .@"export" => .{ .export_section = undefined },
            .start => .{ .start_section = undefined },
            .element => return error.UnsupportedWasmSection,
            .code => .{ .code_section = undefined },
            .data => .{ .data_section = undefined },
            else => return error.UnsupportedWasmSection,
        };
        const section_size = try std.leb.readULEB128(u64, reader);

        switch (section) {
            .custom_section => {
                try reader.skipBytes(section_size, .{});
            },
            .type_section => {
                const ts = &section.type_section;
                const num_types = try std.leb.readULEB128(uleb, reader);
                ts.types = try allocator.alloc(@TypeOf(ts.types[0]), num_types);

                for (ts.types) |*t| {
                    if (!try reader.isBytes("\x60")) {
                        std.log.err("non-function types are not supported\n", .{});
                        return error.InvalidWasmFile;
                    }
                    const num_params = try std.leb.readULEB128(uleb, reader);
                    const params = try allocator.alloc(wasm.Valtype, num_params);
                    for (params) |*param| {
                        param.* = try reader.readEnum(wasm.Valtype, .little);
                    }
                    const num_results = try std.leb.readULEB128(uleb, reader);
                    const returns = try allocator.alloc(wasm.Valtype, num_results);
                    for (returns) |*result| {
                        result.* = try reader.readEnum(wasm.Valtype, .little);
                    }
                    t.params = params;
                    t.returns = returns;
                }
            },
            .import_section => {
                const is = &section.import_section;
                const num_imports = try std.leb.readULEB128(uleb, reader);
                is.imports = try allocator.alloc(ImportSection.Import, num_imports);
                for (is.imports) |*import| {
                    const module_len = try std.leb.readULEB128(uleb, reader);
                    import.module = try allocator.alloc(u8, module_len);
                    if (try reader.readAll(import.module) != module_len) {
                        return error.InvalidWasmFile;
                    }
                    const name_len = try std.leb.readULEB128(uleb, reader);
                    import.name = try allocator.alloc(u8, name_len);
                    if (try reader.readAll(import.name) != name_len) {
                        return error.InvalidWasmFile;
                    }
                    import.tag = try reader.readEnum(wasm.ExternalKind, .little);
                    import.idx = try std.leb.readULEB128(uleb, reader);
                }
            },
            .function_section => {
                const fs = &section.function_section;
                const num_functions = try std.leb.readULEB128(uleb, reader);
                fs.types = try allocator.alloc(FunctionSection.TypeIndex, num_functions);
                for (fs.types) |*type_index| {
                    type_index.* = try std.leb.readULEB128(uleb, reader);
                }
            },
            .memory_section => {
                const ms = &section.memory_section;
                const num_memories = try std.leb.readULEB128(uleb, reader);
                ms.memories = try allocator.alloc(wasm.Limits, num_memories);
                for (ms.memories) |*memory| {
                    memory.flags = try reader.readByte();
                    memory.min = try std.leb.readULEB128(uleb, reader);
                    memory.max =
                        if (memory.hasFlag(.WASM_LIMITS_FLAG_HAS_MAX))
                        try std.leb.readULEB128(uleb, reader)
                    else
                        0;
                    if (memory.max != 0) @panic("TODO: memory max");
                }
            },
            .global_section => {
                const gs = &section.global_section;
                const num_globals = try std.leb.readULEB128(uleb, reader);
                gs.globals = try allocator.alloc(GlobalSection.Global, num_globals);
                for (gs.globals) |*global| {
                    global.type = try reader.readEnum(wasm.Valtype, .little);
                    global.mutable = try reader.readByte() == 1;
                    const fbs = reader.context;
                    const pos = try fbs.getPos();
                    const buffer = fbs.buffer[pos..];
                    const end_index = (try skipToElseOrEnd(buffer)).?;
                    global.init = try allocator.dupe(u8, buffer[0 .. end_index + 1]);
                    try reader.skipBytes(end_index + 1, .{});
                }
            },
            .export_section => {
                const es = &section.export_section;
                const num_exports = try std.leb.readULEB128(uleb, reader);
                es.exports = try allocator.alloc(ExportSection.Export, num_exports);
                for (es.exports) |*e| {
                    const export_name_len = try std.leb.readULEB128(uleb, reader);
                    e.name = try allocator.alloc(u8, export_name_len);
                    if (try reader.readAll(e.name) != export_name_len) {
                        return error.InvalidWasmFile;
                    }
                    e.tag = try reader.readEnum(wasm.ExternalKind, .little);
                    e.index = try std.leb.readULEB128(uleb, reader);
                }
            },
            .start_section => {
                const ss = &section.start_section;
                ss.function_index = try std.leb.readULEB128(u32, reader);
            },
            .code_section => {
                const cs = &section.code_section;
                const num_functions = try std.leb.readULEB128(uleb, reader);
                cs.functions = try allocator.alloc(CodeSection.Code, num_functions);
                for (cs.functions) |*f| {
                    f.size = try std.leb.readULEB128(uleb, reader);
                    // BUG: actual_body_size assumes that each ULEB128 integer is just 1 byte.
                    var actual_body_size = f.size;
                    const num_locals = try std.leb.readULEB128(uleb, reader);
                    actual_body_size -= 1;

                    f.locals = try allocator.alloc(CodeSection.Local, num_locals);
                    for (f.locals) |*local| {
                        local.count = try std.leb.readULEB128(uleb, reader);
                        local.type = try reader.readEnum(wasm.Valtype, .little);
                        if (local.type != .i32) {
                            @panic("Values other than i32 not supported!");
                        }
                        actual_body_size -= 2;
                    }

                    f.body = try allocator.alloc(u8, actual_body_size);
                    const read = try reader.readAll(f.body);
                    if (read != actual_body_size) {
                        return error.InvalidWasmFile;
                    }
                }
            },
            .data_section => {
                const ds = &section.data_section;
                const num_data = try std.leb.readULEB128(uleb, reader);
                ds.data = try allocator.alloc(DataSection.Data, num_data);
                for (ds.data) |*data| {
                    const data_type = try std.leb.readULEB128(uleb, reader);
                    if (data_type != 0) {
                        @panic("Type of data not supported!");
                    }
                    data.memory_index = 0; // assuming because of data_type
                    if (!try reader.isBytes("\x41")) {
                        @panic("Initialization of data not supported!");
                    }
                    data.offset = try std.leb.readULEB128(uleb, reader);
                    if (!try reader.isBytes("\x0B")) {
                        @panic("Initialization of data not supported!");
                    }
                    const data_size = try std.leb.readULEB128(uleb, reader);
                    data.data = try allocator.alloc(u8, data_size);
                    if (try reader.readAll(data.data) != data_size) {
                        return error.InvalidWasmFile;
                    }
                }
            },
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

const uleb = u32;
const ileb = i32;

const ImportFunction = struct {
    module: []const u8,
    name: []const u8,
    func: *const fn (vm: *VirtualMachine, params: []Value) error{NativeFunctionError}!?Value,
};

fn skipToElseOrEnd(instructions: []const u8) !?usize {
    var depth: u32 = 1;
    var fbs = std.io.fixedBufferStream(instructions);
    const reader = fbs.reader();
    while (try fbs.getPos() != try fbs.getEndPos()) {
        const opcode: std.wasm.Opcode = @enumFromInt(try reader.readByte());
        switch (opcode) {
            .call, .local_get => {
                _ = try std.leb.readULEB128(uleb, reader);
            },
            .i32_const => {
                _ = try std.leb.readILEB128(ileb, reader);
            },
            .@"if" => {
                depth += 1;
                _ = try std.leb.readULEB128(uleb, reader);
            },
            .@"else", .end => {
                depth -= 1;
                if (depth == 0) {
                    return try fbs.getPos() - 1;
                }
            },
            else => {},
        }
    }
    return null;
}

const VirtualMachine = struct {
    allocator: std.mem.Allocator,
    stack: std.ArrayList(Value),
    frames: std.ArrayList(Frame),
    module: Module,
    import_functions: std.ArrayList(ImportFunction),
    memories: std.ArrayList([]u8),
    globals: std.ArrayList(Value),

    pub fn init(allocator: std.mem.Allocator, module: Module) !VirtualMachine {
        var vm = VirtualMachine{
            .allocator = allocator,
            .frames = std.ArrayList(Frame).init(allocator),
            .stack = std.ArrayList(Value).init(allocator),
            .import_functions = std.ArrayList(ImportFunction).init(allocator),
            .memories = std.ArrayList([]u8).init(allocator),
            .globals = std.ArrayList(Value).init(allocator),
            .module = module,
        };

        if (module.memory_section) |ms| {
            for (ms.memories) |m| {
                std.debug.print("allocating memory: {d} pages\n", .{m.min});
                const size = m.min * std.wasm.page_size;
                const allocated = try allocator.alloc(u8, size);
                try vm.memories.append(allocated);
            }
        }

        if (module.data_section) |gs| {
            for (gs.data) |d| {
                std.debug.print("initializing memory {d} at offset {d}\n", .{d.memory_index, d.offset});
                const memory = vm.memories.items[d.memory_index];
                @memcpy(memory.ptr + d.offset, d.data);
            }
        }

        if (module.global_section) |gs| {
            for (gs.globals) |g| {
                std.debug.print("initializing {s} global\n", .{if (g.mutable) "mutable" else "immutable"});
                try vm.execute(Frame{
                    .locals = std.ArrayList(Value).init(allocator),
                    .code = .{ .buffer = g.init, .pos = 0 },
                    .block_stack = std.ArrayList(Block).init(allocator),
                });
                try vm.globals.append(vm.stack.pop());
            }
        }

        return vm;
    }

    pub fn deinit(vm: *VirtualMachine) void {
        vm.stack.deinit();
        vm.frames.deinit();
        vm.import_functions.deinit();
        vm.memories.deinit();
        vm.globals.deinit();
    }

    pub fn addImportFunction(vm: *VirtualMachine, module: []const u8, name: []const u8, func: *const fn (*VirtualMachine, []Value) error{NativeFunctionError}!?Value) !void {
        try vm.import_functions.append(.{ .module = module, .name = name, .func = func });
    }

    pub fn call(vm: *VirtualMachine, id: usize, args: []const Value) !?Value {
        std.debug.print("call func_idx({}) {any}\n", .{ id, vm.module.type_section.?.types[id] });
        var locals = std.ArrayList(Value).init(vm.allocator);
        for (args) |arg| {
            try locals.append(arg);
        }
        for (vm.module.code_section.?.functions[id].locals) |l| {
            try locals.appendNTimes(.{ .i32 = 0 }, l.count);
        }
        try vm.execute(Frame{
            .locals = locals,
            .code = .{ .buffer = vm.module.code_section.?.functions[id].body, .pos = 0 },
            .block_stack = std.ArrayList(Block).init(vm.allocator),
        });

        if (vm.stack.popOrNull()) |result| {
            std.debug.print("result: {any}\n", .{result});
            return result;
        } else {
            return null;
        }
    }

    pub fn execute(vm: *VirtualMachine, input: Frame) !void {
        try vm.frames.append(input);
        defer {
            var frame = vm.frames.pop();
            frame.deinit();
        }

        var current_frame = &vm.frames.items[vm.frames.items.len - 1];
        const reader = current_frame.code.reader();
        while (try current_frame.code.getPos() != try current_frame.code.getEndPos()) {
            const opcode: std.wasm.Opcode = @enumFromInt(try reader.readByte());
            switch (opcode) {
                .loop => {
                    const loop_start = try current_frame.code.getPos() - 1; // -1 cause we need to save the position of the loop instruction (not of the following block type)
                    try current_frame.block_stack.append(.{ .pos = loop_start, .is_loop = true });
                    std.debug.assert(try reader.readByte() == wasm.block_empty);
                    std.debug.print("loop begins at {}\n", .{loop_start});
                },
                .@"if" => {
                    const condition = vm.stack.pop().i32;
                    std.debug.assert(try reader.readByte() == wasm.block_empty);
                    std.debug.print("if => {}\n", .{condition != 0});
                    if (condition != 0) {
                        // Execute the 'then' branch
                        const pos = try current_frame.code.getPos();
                        try current_frame.block_stack.append(.{ .pos = pos - 2, .is_loop = false }); // if, block type => -2
                    } else {
                        // Skip to the 'else' branch or 'end'
                        const pos = try current_frame.code.getPos();
                        try current_frame.block_stack.append(.{ .pos = pos - 1, .is_loop = false }); // else => -1
                        const skip = (try skipToElseOrEnd(current_frame.code.buffer[pos..])).?;
                        try reader.skipBytes(skip, .{});
                    }
                },
                .@"else" => {
                    // Skip to end
                    const pos = try current_frame.code.getPos();
                    const skip = (try skipToElseOrEnd(current_frame.code.buffer[pos..])).?;
                    try reader.skipBytes(skip, .{});
                    const if_block = current_frame.block_stack.pop();
                    std.debug.print("reached else for if at 0x{x}\n", .{if_block.pos});
                    continue;
                },
                .call => {
                    const func_idx = try std.leb.readULEB128(uleb, reader);
                    const is_imported_func = iif: {
                        break :iif if (vm.module.import_section) |is|
                            func_idx < is.imports.len
                        else
                            false;
                    };
                    if (is_imported_func) {
                        const import = vm.module.import_section.?.imports[func_idx];
                        for (vm.import_functions.items) |import_func| {
                            if (std.mem.eql(u8, import.module, import_func.module) and std.mem.eql(u8, import.name, import_func.name)) {
                                const params = try vm.allocator.alloc(Value, vm.module.type_section.?.types[func_idx].params.len);
                                defer vm.allocator.free(params);
                                for (params) |*param| {
                                    param.* = vm.stack.pop();
                                }
                                std.debug.print("call imported native function idx({})\n", .{func_idx});
                                const result = try import_func.func(vm, params);
                                if (result) |r| {
                                    try vm.stack.append(r);
                                }
                                break;
                            }
                        }
                    } else {
                        // TODO: maybe merge this with fn call
                        std.debug.print("call func_idx({}) {any}\n", .{ func_idx, vm.module.type_section.?.types[func_idx] });
                        var frame = Frame{
                            .locals = std.ArrayList(Value).init(vm.allocator),
                            .code = .{ .buffer = vm.module.code_section.?.functions[func_idx].body, .pos = 0 },
                            .block_stack = std.ArrayList(Block).init(current_frame.block_stack.allocator),
                        };

                        for (vm.module.type_section.?.types[func_idx].params) |_| {
                            try frame.locals.append(vm.stack.pop());
                        }
                        try vm.execute(frame);
                    }
                },
                .end => {
                    if (current_frame.block_stack.popOrNull()) |b| {
                        // end of a block/loop
                        std.debug.print("end of a block/loop at 0x{x}\n", .{b.pos});
                    } else {
                        // end of a function
                        std.debug.print("end of a function\n", .{});
                        return;
                    }
                },
                .br => {
                    @panic("Implement br");
                },
                .br_if => {
                    // read the depth first
                    const depth = try std.leb.readULEB128(uleb, reader);

                    // if
                    const condition = vm.stack.pop().i32;
                    if (condition == 0) continue;

                    // br
                    const target_block = tb: {
                        var i: usize = 0;
                        while (i != depth) : (i += 1) {
                            _ = current_frame.block_stack.pop();
                        }
                        break :tb current_frame.block_stack.pop();
                    };

                    if (target_block.is_loop) {
                        try current_frame.code.seekTo(target_block.pos);
                        std.debug.print("br to loop at 0x{x}\n", .{target_block.pos});
                    } else {
                        @panic("TODO: Handle blocks!");
                    }
                },
                .local_get => {
                    const local_index = try std.leb.readULEB128(uleb, reader);
                    try vm.stack.append(current_frame.locals.items[local_index]);
                    std.debug.print("local_get idx({}) => {any}\n", .{ local_index, vm.stack.getLast() });
                },
                .local_set => {
                    const local_index = try std.leb.readULEB128(uleb, reader);
                    const value = vm.stack.pop();
                    current_frame.locals.items[local_index] = value;
                    std.debug.print("local_set idx({}) => {any}\n", .{ local_index, value });
                },
                .i32_const => {
                    const value = try std.leb.readILEB128(i32, reader);
                    try vm.stack.append(.{ .i32 = value });
                    std.debug.print("i32_const {}\n", .{value});
                },
                .i32_eq => {
                    const b = vm.stack.pop().i32;
                    const a = vm.stack.pop().i32;
                    const result = a == b;
                    try vm.stack.append(.{ .i32 = if (result) 1 else 0 });
                    std.debug.print("i32_eq => {}\n", .{result});
                },
                .i32_lt_s => {
                    const b = vm.stack.pop().i32;
                    const a = vm.stack.pop().i32;
                    const result = a < b;
                    try vm.stack.append(.{ .i32 = if (result) 1 else 0 });
                    std.debug.print("i32_lt_s => {}\n", .{result});
                },
                .i32_add => {
                    const b = vm.stack.pop().i32;
                    const a = vm.stack.pop().i32;
                    const result = a + b;
                    try vm.stack.append(.{ .i32 = result });
                    std.debug.print("i32_add {} + {} => {}\n", .{ a, b, result });
                },
                .drop => {
                    _ = vm.stack.popOrNull();
                    std.debug.print("drop\n", .{});
                },
                .@"return" => {
                    std.debug.print("return {any}\n", .{vm.stack.getLastOrNull()});
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

const Block = struct {
    pos: usize,
    is_loop: bool,
};
const Frame = struct {
    code: std.io.FixedBufferStream([]const u8),
    locals: std.ArrayList(Value),
    block_stack: std.ArrayList(Block),

    pub fn deinit(frame: *Frame) void {
        frame.locals.deinit();
        frame.block_stack.deinit();
    }
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    const file = try std.fs.cwd().openFile("hello_world.wasm", .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var module = try Module.init(allocator, file_contents);
    defer module.deinit(allocator);
    var vm = try VirtualMachine.init(allocator, module);
    defer vm.deinit();

    const imported = struct {
        fn logFunction(self: *VirtualMachine, params: []Value) error{NativeFunctionError}!?Value {
            _ = self;
            std.debug.print("log: {}\n", .{params[0].i32});
            return null;
        }
    };
    try vm.addImportFunction("console", "log", &imported.logFunction);

    const result = try vm.call(0, &[_]Value{ .{ .i32 = 1 }, .{ .i32 = 127 } });
    _ = result;
}

test "1: add" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile("test1.wasm", .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var module = try Module.init(allocator, file_contents);
    defer module.deinit(allocator);
    var vm = try VirtualMachine.init(allocator, module);
    defer vm.deinit();

    var locals = std.ArrayList(Value).init(allocator);
    try locals.append(.{ .i32 = 1 });
    try locals.append(.{ .i32 = 127 });
    try vm.execute(Frame{
        .locals = locals,
        .code = .{ .buffer = module.code_section.?.functions[0].body, .pos = 0 },
        .block_stack = std.ArrayList(Block).init(allocator),
    });
}

test "2: func call" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile("test2.wasm", .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var module = try Module.init(allocator, file_contents);
    defer module.deinit(allocator);
    var vm = try VirtualMachine.init(allocator, module);
    defer vm.deinit();

    const locals = std.ArrayList(Value).init(allocator);
    try vm.execute(Frame{
        .locals = locals,
        .code = .{ .buffer = module.code_section.?.functions[1].body, .pos = 0 },
        .block_stack = std.ArrayList(Block).init(allocator),
    });
}

test "3: if" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile("test3.wasm", .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var module = try Module.init(allocator, file_contents);
    defer module.deinit(allocator);
    var vm = try VirtualMachine.init(allocator, module);
    defer vm.deinit();

    try vm.execute(Frame{
        .locals = std.ArrayList(Value).init(allocator),
        .code = .{ .buffer = module.code_section.?.functions[vm.module.start_section.?.function_index].body, .pos = 0 },
        .block_stack = std.ArrayList(Block).init(allocator),
    });
}

test "4: loop" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile("test4.wasm", .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var module = try Module.init(allocator, file_contents);
    defer module.deinit(allocator);
    var vm = try VirtualMachine.init(allocator, module);
    defer vm.deinit();

    const imported = struct {
        fn logFunction(self: *VirtualMachine, params: []Value) error{NativeFunctionError}!?Value {
            _ = self;
            std.debug.print("log: {}\n", .{params[0].i32});
            return null;
        }
    };
    try vm.addImportFunction("console", "log", &imported.logFunction);

    const start_function_idx = vm.module.start_section.?.function_index - vm.module.import_section.?.imports.len;
    var locals = std.ArrayList(Value).init(allocator);
    for (module.code_section.?.functions[start_function_idx].locals) |l| {
        try locals.appendNTimes(.{ .i32 = 0 }, l.count);
    }
    try vm.execute(Frame{
        .locals = locals,
        .code = .{ .buffer = module.code_section.?.functions[start_function_idx].body, .pos = 0 },
        .block_stack = std.ArrayList(Block).init(allocator),
    });
}

test "5: if fix" {
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile("test5.wasm", .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var module = try Module.init(allocator, file_contents);
    defer module.deinit(allocator);

    var vm = try VirtualMachine.init(allocator, module);
    defer vm.deinit();

    const imported = struct {
        fn logFunction(self: *VirtualMachine, params: []Value) error{NativeFunctionError}!?Value {
            _ = self;
            std.debug.print("log: {}\n", .{params[0].i32});
            return null;
        }
    };
    try vm.addImportFunction("console", "log", &imported.logFunction);

    const start_function_idx = vm.module.start_section.?.function_index - vm.module.import_section.?.imports.len;
    _ = try vm.call(start_function_idx, &[_]Value{});
}
