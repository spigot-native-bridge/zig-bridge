const std = @import("std");

pub const Signature = struct {
    bodyType: []const SignaturePart = &.{},
    returnType: SignaturePart = .Void,

    pub fn toJavaSignature(self: *const Signature, allocator: std.mem.Allocator) ![*c]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        try buffer.append('(');

        for (self.bodyType) |ty| {
            if (!ty.primitive) {
                try buffer.append('L');
            }

            try buffer.appendSlice(ty.java);

            if (!ty.primitive) {
                try buffer.append(';');
            }
        }

        try buffer.append(')');

        if (!self.returnType.primitive) {
            try buffer.append('L');
        }

        try buffer.appendSlice(self.returnType.java);

        if (!self.returnType.primitive) {
            try buffer.appendSlice(";");
        }

        return try allocator.dupeZ(u8, try buffer.toOwnedSlice());
    }
};

pub const SignaturePart = struct {
    java: []const u8,
    primitive: bool,

    pub const lang = struct {
        const PREFIX = "java/lang/";

        pub const String = SignaturePart.init(PREFIX ++ "String");
    };

    pub const util = struct {
        const PREFIX = "java/util/";

        pub const Collection = SignaturePart.init(PREFIX ++ "Collection");
        pub const List = SignaturePart.init(PREFIX ++ "List");
    };

    pub const bukkit = struct {
        const PREFIX = "org/bukkit/";
        pub const entity = struct {
            const ENTITY_PREFIX = "org/bukkit/entity";

            pub const Player = SignaturePart.init(ENTITY_PREFIX ++ "Player");
        };
    };

    pub const primitives = struct {
        pub const Boolean = SignaturePart.initPrimitive("Z");
    };

    pub const Void = SignaturePart.initPrimitive("V");

    pub fn init(signature: []const u8) SignaturePart {
        return .{ .java = signature, .primitive = false };
    }

    pub fn initPrimitive(signature: []const u8) SignaturePart {
        return .{ .java = signature, .primitive = true };
    }
};
