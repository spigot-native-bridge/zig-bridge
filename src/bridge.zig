const std = @import("std");
const gl = @import("fjsf");
const jni = @import("jni");

// public exports, import using @import("root").<x>
pub const types = @import("types/types.zig");
pub const events = @import("events/events.zig");
pub const native_plugin = @import("plugin/native_plugin.zig");
pub const mappings = @import("mappings/mappings.zig");
pub const chat = @import("chat.zig");
pub const commands = @import("commands/bindings.zig");

// functions that get called by java code
//pub const load = plugin.load;
//pub const enable = plugin.enable;
//pub const disable = plugin.disable;

pub const BridgeError = native_plugin.BridgeError;

pub extern fn load(state: *native_plugin.PluginState) void;
pub extern fn enable(state: *native_plugin.PluginState) void;
pub extern fn disable(state: *native_plugin.PluginState) void;

comptime {
    jni.exportJNI("io.github.therealnv6.BridgeNativePlugin", native_plugin.BridgeNativePluginExport);
    jni.exportJNI("io.github.therealnv6.commands.BridgeCommandRegistry", commands.BridgeCommandExport);
}
