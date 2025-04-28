const std = @import("std");
const jni = @import("jni");
const bridge = @import("../bridge.zig");

const types = bridge.types;

const BridgeError = bridge.BridgeError;
const SignaturePart = types.signature.SignaturePart;

pub const CommandSender = struct {
    const Self = @This();

    _object: jni.jobject = undefined,
    _vm: bridge.native_plugin.VMState = undefined,

    pub fn sendMessageFormat(self: *const Self, comptime message: []const u8, args: anytype) !void {
        try self.sendMessage(
            try std.fmt.allocPrint(bridge.native_plugin.state.allocator, message, args),
        );
    }

    pub fn sendMessage(self: *const Self, message: []const u8) !void {
        const state = bridge.native_plugin.state;
        const str = try state.vm.newUnicodeStringUtf8(message);

        try self._vm.callVoidMethod(
            self._object,
            "sendMessage",
            .{
                .bodyType = &.{SignaturePart.lang.String},
            },
            .{str},
        );
    }

    pub fn sendChatMessage(self: *const Self, message: bridge.chat.Message) !void {
        const str = try message.toString();
        try self.sendMessage(str);
    }
};
