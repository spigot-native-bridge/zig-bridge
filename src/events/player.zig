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
