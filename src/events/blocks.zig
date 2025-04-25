const jni = @import("jni");
const events = @import("events.zig");
const bridge = @import("../bridge.zig");

const types = bridge.types;

const EventType = events.EventType;
const Player = types.player.Player;

const CancelEventImpl = @import("cancel.zig").CancelEventImpl;

pub const BlockBreakEvent = struct {
    player: Player = undefined,
    _object: jni.jobject = undefined,

    pub fn getEventType() EventType {
        return .BlockBreakEvent;
    }

    pub const setCancelled = CancelEventImpl(BlockBreakEvent);
};
