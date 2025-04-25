const jni = @import("jni");
const events = @import("events.zig");
const bridge = @import("../bridge.zig");

const types = bridge.types;

const EventType = events.EventType;
const Player = types.player.Player;

pub const PlayerJoinEvent = struct {
    player: Player = undefined,
    _object: jni.jobject = undefined,

    pub fn getEventType() EventType {
        return .PlayerJoinEvent;
    }
};

pub const PlayerChatEvent = struct {
    player: Player = undefined,
    _object: jni.jobject = undefined,

    pub fn getEventType() EventType {
        return .PlayerChatEvent;
    }

    pub fn setFormat(self: *PlayerChatEvent, format: []const u8) !void {
        const state = bridge.native_plugin.state;
        const str = try state.vm.newUnicodeStringUtf8(format);
        // todo free str

        try bridge.native_plugin.state.vm.callVoidMethod(
            self._object,
            "setFormat",
            .{
                .bodyType = &.{
                    types.signature.SignaturePart.lang.String,
                },
            },
            .{str},
        );
    }
};
