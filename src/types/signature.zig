const std = @import("std");

pub const Signature = struct {
    bodyType: []const SignaturePart = &.{},
    returnType: SignaturePart = .Void,

    pub fn toJavaSignature(self: *const Signature, allocator: std.mem.Allocator) ![*c]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        try buffer.append('(');

        for (self.bodyType, 0..) |ty, idx| {
            try buffer.append('L');
            try buffer.appendSlice(ty.java);

            if (idx != self.bodyType.len - 1) {
                try buffer.append(',');
            }

            try buffer.append(';');
        }

        try buffer.append(')');

        if (!std.mem.eql(u8, self.returnType.java, SignaturePart.Void.java)) {
            try buffer.append('L');
        }

        try buffer.appendSlice(self.returnType.java);

        if (!std.mem.eql(u8, self.returnType.java, SignaturePart.Void.java)) {
            try buffer.appendSlice(";");
        }

        return try allocator.dupeZ(u8, try buffer.toOwnedSlice());
    }
};

pub const SignaturePart = struct {
    java: []const u8,

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

    pub const Void = SignaturePart.init("V");

    pub fn init(signature: []const u8) SignaturePart {
        return .{ .java = signature };
    }
};
