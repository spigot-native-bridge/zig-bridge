const std = @import("std");
const root = @import("root");

const plugin = root.native_plugin;
const events = root.events;
const chat = root.chat;

const BridgeError = root.BridgeError;

const Message = chat.Message;

// functions called by mappings/native_plugin.BridgeNativePluginExport
pub fn load(state: *plugin.PluginState) void {
    state.eventRegistry.listenFallible(events.blocks.BlockBreakEvent, handleBlockBreakEvent) catch unreachable;
}

pub fn enable(_: *plugin.PluginState) void {}

pub fn disable(_: *plugin.PluginState) void {
    std.debug.print("plugin has disabled... - zig", .{});
}

pub fn handleBlockBreakEvent(event: *events.blocks.BlockBreakEvent) BridgeError!void {
    var message = try Message.init(plugin.state.allocator, .{});

    try message.withPart(.{ .color = .aqua, .modifiers = &.{chat.Modifier.italic}, .text = "meow" });
    try message.withPart(.{ .color = .yellow, .text = " i love my husband" });

    try event.player.sendChatMessage(message);

    event.setCancelled(true);
}
