const std = @import("std");
const jni = @import("jni");
const state = @import("native_plugin.zig").state;
const sig = @import("../types/signature.zig");

pub const Env = struct {
    const Self = @This();

    jenv: *jni.cEnv,
    allocator: std.mem.Allocator,

    pub fn init(env: *jni.cEnv, allocator: std.mem.Allocator) Env {
        return .{
            .jenv = env,
            .allocator = allocator,
        };
    }

    pub fn callVoidMethod(self: *const Self, obj: jni.jobject, name: [*]const u8, signature: sig.Signature, args: anytype) !void {
        const class = self.getObjectClass(obj) orelse unreachable;
        const method = try self.getMethodId(class, name, signature) orelse unreachable;

        @call(.auto, self.jenv.*.*.CallVoidMethod.?, .{ self.jenv, obj, method } ++ args);
    }

    pub fn callObjectMethod(self: *const Self, obj: jni.jobject, name: [*]const u8, signature: sig.Signature, args: anytype) !jni.jobject {
        const class = self.getObjectClass(obj);
        const method = try self.getMethodId(class, name, signature);

        return @call(.auto, self.jenv.*.*.CallObjectMethod.?, .{ self.jenv, obj, method } ++ args);
    }

    pub fn callIntMethod(self: *const Self, obj: jni.jobject, name: [*c]const u8, signature: [*c]const u8) !u32 {
        const class = self.getObjectClass(obj);
        const method = try self.getMethodId(class, name, signature);

        return @intCast(self.jenv.*.*.CallIntMethod.?(self.jenv, obj, method));
    }

    pub fn newObject(self: *const Self, className: [*]const u8, signature: [*c]const u8, args: anytype) !jni.jobject {
        const class = self.findClass(className);
        const method = try self.getMethodId(class, "<init>", signature);

        return @call(.auto, self.jenv.*.*.CallObjectMethod.?, .{ self.jenv, method } ++ args);
    }

    pub fn newString(self: *const Self, chars: [*c]const u8) jni.jstring {
        return self.jenv.*.*.NewStringUTF.?(self.jenv, chars);
    }

    pub fn newCString(self: *const Self, object: jni.jstring) [*c]const u8 {
        return self.jenv.*.*.GetStringUTFChars.?(self.jenv, object, 0);
    }

    pub fn getClassName(self: *const Self, class: jni.jclass) ![]const u8 {
        const getNameSignature = sig.Signature{ .bodyType = &.{}, .returnType = sig.SignaturePart.lang.String };
        const jstr = try self.callObjectMethod(class, "getName", getNameSignature, .{});

        if (jstr == null) {
            return error.MethodNotFound;
        }

        const cstr = self.newCString(jstr);

        return std.mem.span(cstr);
    }

    pub fn getObjectClass(self: *const Self, object: jni.jobject) jni.jclass {
        return self.jenv.*.*.GetObjectClass.?(self.jenv, object);
    }

    pub fn findClass(self: *const Self, className: [*]const u8) jni.jclass {
        return self.jenv.*.*.FindClass.?(self.jenv, className);
    }

    pub fn getMethodId(self: *const Self, class: jni.jclass, name: [*c]const u8, signature: sig.Signature) !jni.jmethodID {
        return self.jenv.*.*.GetMethodID.?(self.jenv, class, name, try signature.toJavaSignature(self.allocator));
    }
};
