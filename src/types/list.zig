const std = @import("std");
const jni = @import("jni");
const mappings = @import("../mappings/mappings.zig");
const conversion = @import("conversion.zig");
const objectConversion = conversion.object;

pub const java = struct {
    pub const Collection = struct {
        const Self = @This();

        inner: jni.jobject,
        class: jni.jclass,
        env: *jni.cEnv,

        pub fn fromObject(env: *jni.cEnv, object: jni.jobject) !Self {
            return .{
                .env = env,
                .class = env.*.*.GetObjectClass.?(env, object),
                .inner = object,
            };
        }

        pub fn arrayList(env: *jni.cEnv, class: jni.jclass) !Self {
            const list = mappings.newObject(env, "java/util/ArrayList", "()V");

            return .{
                .inner = list,
                .class = class,
                .env = env,
            };
        }

        pub fn toZigArrayList(self: *const Self, comptime T: type, allocator: std.mem.Allocator) !std.ArrayList(T) {
            var list = std.ArrayList(T).init(allocator);

            const innerClass = self.env.*.*.GetObjectClass.?(self.env, self.inner);
            const toArrayMethod = self.env.*.*.GetMethodID.?(self.env, innerClass, "toArray", "()[Ljava/lang/Object;");

            if (toArrayMethod == null) {
                return error.MethodNotFound;
            }

            const elementsArray = self.env.*.*.CallObjectMethod.?(self.env, self.inner, toArrayMethod);
            const size = self.env.*.*.GetArrayLength.?(self.env, elementsArray);

            for (0..@intCast(size)) |i| {
                const obj = self.env.*.*.GetObjectArrayElement.?(self.env, elementsArray, @intCast(i));
                const converted = objectConversion.fromJavaObject(T, self.env, obj);

                if (converted) |val| {
                    try list.append(val);
                }
            }

            return list;
        }
    };
};
