const plugin = @import("mappings/native_plugin.zig");
const jni = @import("jni");

comptime {
    jni.exportJNI("io.github.therealnv6.BridgeNativePlugin", plugin.BridgeNativePluginExport);
}
