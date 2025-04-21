const jni = @import("jni");
const types = @import("root").types;

const Player = types.player.Player;
const CancelEventImpl = @import("cancel.zig").CancelEventImpl;

pub const BlockBreakEvent = struct {
    player: Player = undefined,
    _object: jni.jobject = undefined,

    pub const setCancelled = CancelEventImpl(BlockBreakEvent);
};
