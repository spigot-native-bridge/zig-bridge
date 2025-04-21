const std = @import("std");
const plugin = @import("mappings/native_plugin.zig");
const jni = @import("jni");

// public exports, import using @import("root").<x>
pub const types = @import("types/types.zig");
pub const events = @import("mappings/events/events.zig");
pub const native_plugin = @import("mappings/native_plugin.zig");

// functions called by mappings/native_plugin.BridgeNativePluginExport
pub fn load(_: *plugin.PluginState) void {}

pub fn enable(state: *plugin.PluginState) void {
    state.eventRegistry.listen(events.blocks.BlockBreakEvent, handleBlockBreakEvent) catch unreachable;
}

pub fn disable(_: *plugin.PluginState) void {
    std.debug.print("plugin has disabled... - zig", .{});
}

pub fn handleBlockBreakEvent(event: *events.blocks.BlockBreakEvent) void {
    event.player.sendMessage("§ameow. you broke a block! (from zig!)") catch unreachable;
    event.setCancelled(true);
}

comptime {
    jni.exportJNI("io.github.therealnv6.BridgeNativePlugin", plugin.BridgeNativePluginExport);
}
