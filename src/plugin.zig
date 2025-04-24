const std = @import("std");
const root = @import("root");

const plugin = root.native_plugin;
const events = root.events;
const chat = root.chat;

const BridgeError = root.BridgeError;

const Message = chat.Message;

// functions called by mappings/native_plugin.BridgeNativePluginExport
pub fn load(state: *plugin.PluginState) !void {
    // 'listenFallible' for an event listener that can return an error (specifically, BridgeError, meaning, BridgeError!void)
    // 'listen' for an event listener that simply returns 'void'
    try state.eventRegistry.listenFallible(events.blocks.BlockBreakEvent, handleBlockBreakEvent);
    try state.eventRegistry.listenFallible(events.player.PlayerJoinEvent, onPlayerJoin);

    // default is events.debugErrorCallback
    state.eventRegistry.setErrorCallback(events.unreachableErrorCallback);
}

pub fn enable(_: *plugin.PluginState) !void {}

pub fn disable(_: *plugin.PluginState) !void {
    std.debug.print("plugin has disabled... - zig", .{});
}

pub fn onPlayerJoin(event: *events.player.PlayerJoinEvent) BridgeError!void {
    std.debug.print("player join event", .{});
    const message = try Message.initSlice(
        plugin.state.allocator,
        &.{
            .{ .text = "meow", .color = .aqua, .modifiers = &.{ .italic, .bold } },
            .{ .text = "wowie yellow", .color = .yellow },
        },
    );

    try event.player.sendChatMessage(message);
}

pub fn handleBlockBreakEvent(event: *events.blocks.BlockBreakEvent) BridgeError!void {
    event.setCancelled(true);
}
