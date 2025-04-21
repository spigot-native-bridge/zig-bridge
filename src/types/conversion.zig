const std = @import("std");
const state = @import("../mappings/native_plugin.zig").state;
const jni = @import("jni");

// we can change this some day
const Signature = [*c]const u8;

pub const object = struct {
    pub fn fromJavaObject(T: type, env: *jni.cEnv, obj: jni.jobject) ?T {
        const info = @typeInfo(T);

        if (info != .@"struct") {
            @compileError("fromJavaObject() only supports structs");
        }

        var value = T{};

        const struct_ty = info.@"struct";
        const class = env.*.*.GetObjectClass.?(env, obj) orelse unreachable;

        inline for (struct_ty.fields) |field| {
            // reserved names for objects this current context is aware of
            if (comptime std.mem.eql(u8, "_object", field.name)) {
                @field(value, "_object") = obj;
            } else if (comptime std.mem.eql(u8, "_env", field.name)) {
                @field(value, "_env") = &state.env;
            } else {
                // in case the current field is not a reserved name, parse the field automatically.
                const signature = types.zigTypeToSignature(field.type);

                const fieldId = env.*.*.GetFieldID.?(env, class, field.name, signature);
                const parsedField = parseJavaField(field.type, env, obj, fieldId);

                if (parsedField) |token| {
                    @field(value, field.name) = token;
                }
            }
        }

        return value;
    }

    pub fn parseJavaField(T: type, env: *jni.cEnv, obj: jni.jobject, fieldId: jni.jfieldID) ?T {
        const info = @typeInfo(T);

        // @compileError(std.fmt.comptimePrint("Not supported currently, got type: {any}", .{info}))
        return switch (info) {
            // both signed and unsigned, since java only has signed.
            .int => |i| switch (i.bits) {
                8 => @intCast(env.*.*.GetCharField.?(env, obj, fieldId)),
                16 => @intCast(env.*.*.GetShortField.?(env, obj, fieldId)),
                32 => @intCast(env.*.*.GetIntField.?(env, obj, fieldId)),
                64 => @intCast(env.*.*.GetLongField.?(env, obj, fieldId)),
                else => @compileError(std.fmt.comptimePrint("Not supported currently, got type: {any}", .{i.bits})),
            },
            .float => |f| switch (f.bits) {
                32 => @floatCast(env.*.*.GetFloatField.?(env, obj, fieldId)),
                64 => @floatCast(env.*.*.GetDoubleField.?(env, obj, fieldId)),
                else => @compileError(std.fmt.comptimePrint("Not supported currently, got type: {any}", .{f.bits})),
            },
            .comptime_int => @intCast(env.*.*.GetIntField.?(env, obj, fieldId)),
            .comptime_float => @floatCast(env.*.*.GetFloatField.?(env, obj, fieldId)),
            .bool => env.*.*.GetBooleanField.?(env, obj, fieldId) == 1,
            .array => |array| switch (array.child) {
                u8 => {
                    const strObject = env.*.*.GetObjectField.?(env, obj, fieldId);
                    const str = env.*.*.GetStringUTFChars.?(strObject, 0);

                    return std.mem.span(str);
                },
                else => @compileError("unsupported amount of bits in parseJavaField()"),
            },
            .pointer => |pointer| switch (pointer.size) {
                std.builtin.Type.Pointer.Size.slice => switch (pointer.child) {
                    u8 => {
                        const strObject = @as(jni.jstring, env.*.*.GetObjectField.?(env, obj, fieldId) orelse unreachable);
                        const str = env.*.*.GetStringUTFChars.?(env, strObject, 0) orelse unreachable;
                        defer env.*.*.ReleaseStringUTFChars.?(env, strObject, str);

                        return state.allocator.dupe(u8, std.mem.span(str)) catch unreachable;
                    },
                    else => @compileError("unsupported amount of bits in parseJavaField()"),
                },

                else => @compileError(std.fmt.comptimePrint("Not supported currently, got type: {any}", .{info})),
            },
            else => switch (T) {
                jni.jobject => env.*.*.GetObjectField.?(env, obj, fieldId),
                else => fromJavaObject(T, env, env.*.*.GetObjectField.?(env, obj, fieldId) orelse unreachable),
            },
        };
    }
};

pub const types = struct {
    pub fn zigTypeToSignature(T: type) Signature {
        const info = @typeInfo(T);
        return switch (info) {
            .int => |i| switch (i.bits) {
                8 => "C",
                16 => "S",
                32 => "I",
                64 => "J",
                else => @compileError("unsupported amount of bits in zigTypeToSignature()"),
            },
            .float => |f| switch (f.bits) {
                32 => "F",
                64 => "D",
                else => @compileError("unsupported amount of bits in zigTypeToSignature()"),
            },
            .comptime_int => "I",
            .comptime_float => "D",
            .bool => "Z",
            .array => |array| "[" ++ zigTypeToSignature(array.child),
            .pointer => |pointer| switch (pointer.size) {
                std.builtin.Type.Pointer.Size.slice => switch (pointer.child) {
                    u8 => "Ljava/lang/String;",
                    else => @compileError(std.fmt.comptimePrint("Not supported currently, got type: {any}", .{info})),
                },
                else => @compileError(std.fmt.comptimePrint("Not supported currently, got type: {any}", .{info})),
            },
            .@"struct" => if (std.meta.hasFn(T, "getJavaSignature")) {
                return @call(.auto, T.getJavaSignature, .{});
            } else {
                return "Ljava/lang/Object;";
            },
            else => "Ljava/lang/Object;",
        };
    }
};
