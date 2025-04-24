const std = @import("std");
const root = @import("root");

const types = root.types;
const native_plugin = root.native_plugin;

const signature = types.signature;
const SignaturePart = signature.SignaturePart;

pub fn CancelEventImpl(comptime T: type) fn (self: *const T, cancelled: bool) void {
    return struct {
        pub fn inner(self: *const T, cancelled: bool) void {
            if (!comptime @hasField(T, "_object")) {
                @compileError("T in CancelEventImpl must contain an `_object: jni.jobject` field.");
            }

            native_plugin.state.vm.callVoidMethod(
                @field(self, "_object"),
                "setCancelled",
                .{
                    .bodyType = &.{SignaturePart.primitives.Boolean},
                },
                .{cancelled},
            ) catch {
                std.debug.print("WARNING!!! called #setCancelled() on [java] Object without that method.\n", .{});
            };
        }
    }.inner;
}
