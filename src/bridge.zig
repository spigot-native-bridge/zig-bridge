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

const root = @import("root");

pub const BridgeError = native_plugin.BridgeError;
pub const Version = "0.0.2";

// this is expected to be in your plugin!
pub extern fn load(state: *native_plugin.PluginState) void;

comptime {
    jni.exportJNI("io.github.therealnv6.BridgeNativePlugin", native_plugin.BridgeNativePluginExport);
    jni.exportJNI("io.github.therealnv6.commands.BridgeCommandRegistry", commands.BridgeCommandExport);
}
