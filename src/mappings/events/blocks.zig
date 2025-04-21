const types = @import("../../types/types.zig");
const jni = @import("jni");

const Player = types.player.Player;
const CancelEventImpl = @import("cancel.zig").CancelEventImpl;

pub const BlockBreakEvent = struct {
    player: Player = undefined,
    _object: jni.jobject = undefined,

    pub const setCancelled = CancelEventImpl(BlockBreakEvent);
};
