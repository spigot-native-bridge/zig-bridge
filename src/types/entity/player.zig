const jni = @import("jni");
const std = @import("std");
const bridge = @import("../../bridge.zig");

const types = bridge.types;

const signature = types.signature;
const SignaturePart = signature.SignaturePart;

pub const Player = struct {
    const Self = @This();

    firstPlayed: u64 = 0,
    lastPlayed: u64 = 0,
    hasPlayedBefore: bool = false,
    health: f64 = 0.0,
    healthScale: f64 = 0.0,

    // this is the internal java object, used to call java functions
    _object: jni.jobject = undefined,
    _vm: bridge.native_plugin.VMState = undefined,

    pub fn sendMessage(self: *const Self, message: []const u8) !void {
        const state = bridge.native_plugin.state;
        const str = try state.vm.newUnicodeStringUtf8(message);
        //defer state.vm.freeUnicodeString(str, message);

        try self._vm.callVoidMethod(
            self._object,
            "sendMessage",

            .{
                .bodyType = &.{SignaturePart.lang.String},
                .returnType = SignaturePart.Void,
            },
            .{str},
        );
    }

    pub fn sendChatMessage(self: *const Self, message: bridge.chat.Message) !void {
        const str = try message.toString();
        try self.sendMessage(str);
    }

    pub fn kickPlayer(self: *const Self, message: []const u8) !void {
        const state = bridge.native_plugin.state;
        const str = try state.vm.newUnicodeStringUtf8(message);
        //defer state.vm.freeUnicodeString(str, message);

        try self._vm.callVoidMethod(
            self._object,
            "kickPlayer",

            .{
                .bodyType = &.{SignaturePart.lang.String},
                .returnType = SignaturePart.Void,
            },
            .{str},
        );
    }

    pub fn getUniqueId(self: *const Self) !types.UniqueId {
        const obj = try self._vm.callObjectMethod(
            self._object,
            "getUniqueId",
            .{
                .returnType = SignaturePart.util.UUID,
            },
            .{},
        );

        const id = types.conversion.object.fromJavaObject(types.UniqueId, self._vm.jvmEnv().*, obj);

        if (id == null) {
            return bridge.BridgeError.OutOfMemory;
        }

        return id.?;
    }

    pub fn getJavaSignature() [*c]const u8 {
        return "Lorg/bukkit/entity/Player;";
    }
};
