const jni = @import("jni");
const events = @import("events.zig");
const types = @import("root").types;

const EventType = events.EventType;
const Player = types.player.Player;

pub const PlayerJoinEvent = struct {
    player: Player = undefined,
    _object: jni.jobject = undefined,

    pub fn getEventType() EventType {
        return .PlayerJoinEvent;
    }
};
