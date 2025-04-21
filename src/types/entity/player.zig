const jni = @import("jni");
const std = @import("std");

const Env = @import("../../mappings/mappings.zig").Env;
const signature = @import("../types.zig").signature;
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
    _env: *Env = undefined,

    pub fn sendMessage(self: *const Self, message: [*c]const u8) !void {
        try self._env.callVoidMethod(
            self._object,
            "sendMessage",
            .{
                .bodyType = &.{SignaturePart.lang.String},
                .returnType = SignaturePart.Void,
            },
            .{self._env.newString(message)},
        );
    }

    pub fn kickPlayer(self: *const Self, message: [*c]const u8) !void {
        try self._env.callVoidMethod(
            self._object,
            "kickPlayer",
            .{
                .bodyType = &.{SignaturePart.lang.String},
                .returnType = SignaturePart.Void,
            },
            .{self._env.newString(message)},
        );
    }

    pub fn getJavaSignature() [*c]const u8 {
        return "Lorg/bukkit/entity/Player;";
    }
};
