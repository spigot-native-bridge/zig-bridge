const std = @import("std");
const jni = @import("jni");
const root = @import("root");
const types = @import("root").types;

const state = root.native_plugin.state;
const sig = types.signature;
const MAX_STRINGS = 4;

pub const VMError = error{
    NoMethodFound,
    NoClassFound,
    NoFieldFound,
    InvalidUtf8,
} || std.mem.Allocator.Error;

pub const VMState = struct {
    const Self = @This();

    jvm: jni.JavaVM,
    env: jni.JNIEnv,
    allocator: std.mem.Allocator,

    pub fn init(cenv: *jni.cEnv, allocator: std.mem.Allocator) !VMState {
        var vm: jni.JavaVM = undefined;
        const env = jni.JNIEnv.warp(cenv);

        try env.getJavaVM(&vm);

        return .{
            .jvm = vm,
            .env = env,
            .allocator = allocator,
        };
    }

    pub fn jvmEnv(self: *const Self) *jni.JNIEnv {
        return @constCast(&self.env);
    }

    // not sure if this is a good thing to do.
    pub fn attachToVM(self: *Self) !void {
        var env: ?*?jni.cEnv = undefined;
        try self.jvm.attachCurrentThread(&env, null);

        if (env == null) {
            @panic("");
        }

        if (env) |current| {
            if (current.*) |environment| {
                self.env = jni.JNIEnv.warp(@constCast(&environment));
            }
        }
        //self.env = jni.JNIEnv.warp(env);
    }

    pub fn newUnicodeStringUtf8(self: *const Self, str: []const u8) VMError!jni.jstring {
        const utf16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, str);
        const null_terminated = try self.allocator.dupeZ(u16, utf16);

        return self.env.newString(null_terminated.ptr, @intCast(null_terminated.len));
    }

    pub fn newUnicodeString(self: *const Self, str: []const u16) jni.jstring {
        return self.env.newString(str.ptr, str.len);
    }

    pub fn freeUnicodeString(self: *const Self, jstr: jni.jstring, str: []const u16) void {
        self.env.releaseStringChars(jstr, str.ptr);
    }

    pub fn newCString(self: *const Self, object: jni.jstring) [*c]const u8 {
        return self.env.getStringUTFChars.?(self.jenv, object, 0);
    }

    pub fn callVoidMethod(self: *const Self, obj: jni.jobject, name: []const u8, signature: sig.Signature, args: anytype) VMError!void {
        return self.callMethodTemplate(self.env._cJNIEnv.*.*.CallVoidMethod.?, void, obj, name, signature, args);
    }

    pub fn callIntegerMethod(self: *const Self, obj: jni.jobject, name: []const u8, signature: sig.Signature, args: anytype) VMError!u32 {
        return self.callMethodTemplate(self.env._cJNIEnv.*.*.CallIntMethod.?, void, obj, name, signature, args);
    }

    pub fn callObjectMethod(self: *const Self, obj: jni.jobject, name: []const u8, signature: sig.Signature, args: anytype) VMError!u32 {
        return self.callMethodTemplate(self.env._cJNIEnv.*.*.CallObjectMethod.?, void, obj, name, signature, args);
    }

    pub fn newObject(self: *const Self, className: [*]const u8, signature: [*c]const u8, args: anytype) VMError!jni.jobject {
        return self.callObjectMethod(self.env.findClass(className), "<init>", signature, args);
    }

    pub fn callMethodTemplate(self: *const Self, function: anytype, comptime ReturnType: type, obj: jni.jobject, name: []const u8, signature: sig.Signature, args: anytype) VMError!ReturnType {
        const class = self.env.getObjectClass(obj) orelse return error.NoClassFound;
        const method = self.env._cJNIEnv.*.*.GetMethodID.?(
            self.env._cJNIEnv,
            class,
            name.ptr,
            try signature.toJavaSignature(self.allocator),
        ) orelse return VMError.NoMethodFound;

        return @call(.auto, function, .{ self.env._cJNIEnv, obj, method } ++ args);
    }

    pub fn getClassName(self: *const Self, class: jni.jclass) ![]const u8 {
        const getNameSignature = sig.Signature{ .bodyType = &.{}, .returnType = sig.SignaturePart.lang.String };
        const jstr = try self.callObjectMethod(class, "getName", getNameSignature, .{});

        if (jstr == null) {
            return error.MethodNotFound;
        }

        return std.mem.span(self.newCString(jstr));
    }
};

//pub const Env = struct {
//    const Self = @This();
//
//    jenv: *jni.cEnv,
//    jvm: jni.JavaVM,
//    allocator: std.mem.Allocator,
//
//    pub fn init(env: *jni.cEnv, allocator: std.mem.Allocator) Env {
//        var vm: jni.JavaVM = undefined;
//        const result = env.*.*.GetJavaVM.?(env, &vm);
//
//        if (result != jni.cjni.JNI_OK) {
//            // todo: proper error handling
//            @panic("couldn't get JavaVM");
//        }
//
//        return .{
//            .jenv = env,
//            .jvm = vm,
//            .allocator = allocator,
//        };
//    }
//
//    pub fn attachToVM(self: *const Self) !void {
//        self.jvm.attachCurrentThread(&self.jenv, .{});
//    }
//
//    pub fn callVoidMethod(self: *const Self, obj: jni.jobject, name: [*]const u8, signature: sig.Signature, args: anytype) !void {
//        const class = self.getObjectClass(obj) orelse unreachable;
//        const method = try self.getMethodId(class, name, signature) orelse unreachable;
//        std.debug.print("hey, howdy! \n", .{});
//
//        @call(.auto, self.jenv.*.*.CallVoidMethod.?, .{ self.jenv, obj, method } ++ args);
//    }
//
//    pub fn callObjectMethod(self: *const Self, obj: jni.jobject, name: [*]const u8, signature: sig.Signature, args: anytype) !jni.jobject {
//        const class = self.getObjectClass(obj);
//        const method = try self.getMethodId(class, name, signature);
//
//        return @call(.auto, self.jenv.*.*.CallObjectMethod.?, .{ self.jenv, obj, method } ++ args);
//    }
//
//    pub fn callIntMethod(self: *const Self, obj: jni.jobject, name: [*c]const u8, signature: [*c]const u8) !u32 {
//        const class = self.getObjectClass(obj) orelse return error.NoClass;
//        const method = try self.getMethodId(class, name, signature) orelse return error.NoMethod;
//
//        return @intCast(self.jenv.*.*.CallIntMethod.?(self.jenv, obj, method));
//    }
//
//    pub fn newObject(self: *const Self, className: [*]const u8, signature: [*c]const u8, args: anytype) !jni.jobject {
//        const class = self.findClass(className);
//        const method = try self.getMethodId(class, "<init>", signature);
//
//        return @call(.auto, self.jenv.*.*.CallObjectMethod.?, .{ self.jenv, method } ++ args);
//    }
//
//    pub fn newString(self: *const Self, chars: []const u8) jni.jstring {
//        return self.jenv.*.*.NewStringUTF.?(self.jenv, chars.ptr);
//    }
//
//    pub fn freeString(self: *const Self, str: jni.jstring, chars: []const u8) void {
//        self.jenv.*.*.ReleaseStringUTFChars.?(self.jenv, str, chars.ptr);
//    }
//
//    pub fn newCString(self: *const Self, object: jni.jstring) [*c]const u8 {
//        return self.jenv.*.*.GetStringUTFChars.?(self.jenv, object, 0);
//    }
//
//    pub fn getClassName(self: *const Self, class: jni.jclass) ![]const u8 {
//        const getNameSignature = sig.Signature{ .bodyType = &.{}, .returnType = sig.SignaturePart.lang.String };
//        const jstr = try self.callObjectMethod(class, "getName", getNameSignature, .{});
//
//        if (jstr == null) {
//            return error.MethodNotFound;
//        }
//
//        const cstr = self.newCString(jstr);
//
//        return std.mem.span(cstr);
//    }
//
//    pub fn getObjectClass(self: *const Self, object: jni.jobject) jni.jclass {
//        return self.jenv.*.*.GetObjectClass.?(self.jenv, object);
//    }
//
//    pub fn findClass(self: *const Self, className: [*]const u8) jni.jclass {
//        return self.jenv.*.*.FindClass.?(self.jenv, className);
//    }
//
//    pub fn getMethodId(self: *const Self, class: jni.jclass, name: [*c]const u8, signature: sig.Signature) !jni.jmethodID {
//        return self.jenv.*.*.GetMethodID.?(self.jenv, class, name, try signature.toJavaSignature(self.allocator));
//    }
//};
