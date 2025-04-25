const std = @import("std");
const jni = @import("jni");
const bridge = @import("../bridge.zig");

const types = bridge.types;
const mappings = bridge.mappings;
const plugin = bridge.native_plugin;

const conversion = types.conversion;
const signature = types.signature;

const Player = types.player.Player;
const SignaturePart = signature.SignaturePart;
const Message = bridge.chat.Message;

pub const Command = struct {
    name: []const u8,
    description: []const u8 = "",
    usageMessage: []const u8 = "",
    pluginSignature: []const u8 = "zig",
    callback: *const fn (player: Player, label: []const u8, args: []const u8) bridge.native_plugin.BridgeError!void,
};

pub const BridgeCommandRegistry = struct {
    const Self = @This();

    obj: jni.jobject,
    commands: std.StringHashMap(Command),

    pub fn init(obj: jni.jobject, allocator: std.mem.Allocator) BridgeCommandRegistry {
        var map = std.StringHashMap(Command).init(allocator);
        map.ensureUnusedCapacity(16) catch unreachable;
        return .{
            .obj = obj,
            .commands = map,
        };
    }

    pub fn registerCommand(self: *Self, command: Command) !void {
        try self.commands.put(command.name, command);
        try self.createCommand(
            command.name,
            command.description,
            command.usageMessage,
            command.pluginSignature,
        );
    }

    pub fn createCommand(
        self: *const BridgeCommandRegistry,
        name: []const u8,
        description: []const u8,
        usageMessage: []const u8,
        pluginSignature: []const u8,
    ) !void {
        var vm = plugin.state.vm;

        // todo: free these
        const jname = try vm.newUnicodeStringUtf8(name);
        const jdescription = try vm.newUnicodeStringUtf8(description);
        const jusageMessage = try vm.newUnicodeStringUtf8(usageMessage);
        const jpluginSignature = try vm.newUnicodeStringUtf8(pluginSignature);

        try vm.callVoidMethod(
            self.obj,
            "createNativeBoundCommand",
            .{
                .returnType = .Void,
                .bodyType = &.{
                    SignaturePart.lang.String, // name
                    SignaturePart.lang.String, // description
                    SignaturePart.lang.String, // usageMessage
                    SignaturePart.lang.String, // pluginSignature
                },
            },
            .{ jname, jdescription, jusageMessage, jpluginSignature },
        );
    }
};

pub const BridgeCommandExport = struct {
    var registry: *BridgeCommandRegistry = undefined;

    pub fn initRegistry(env: *jni.cEnv, tobj: jni.jobject) callconv(.C) void {
        const obj = env.*.*.NewGlobalRef.?(env, tobj);

        plugin.state.commandRegistry = BridgeCommandRegistry.init(obj, plugin.state.allocator);
        registry = &plugin.state.commandRegistry;

        registry.registerCommand(ZigBridgeInfoCommand) catch unreachable;
    }

    pub fn processCommands(_: *jni.cEnv, _: jni.jobject, jsender: jni.jobject, jlabel: jni.jstring, _: jni.jarray) callconv(.C) void {
        var vm = plugin.state.vm;
        vm.attachToVM() catch unreachable;

        const player = conversion.object.fromJavaObject(Player, vm.jvmEnv().*, jsender) orelse return;
        const label = std.mem.span(vm.newCString(jlabel, false));

        const command = registry.commands.get(label);

        if (command) |c| {
            c.callback(player, label, "") catch unreachable;
        }
    }
};

pub const ZigBridgeInfoCommand = Command{
    .name = "zig",
    .description = "Command to show general information about Zig Bridge",
    .pluginSignature = "zig-bridge",
    .callback = zigBridgeCommand,
};

pub fn zigBridgeCommand(player: Player, _: []const u8, _: []const u8) !void {
    const message = try Message.initSlice(
        plugin.state.allocator,
        &.{
            .{ .text = "This server is running ", .color = .yellow },
            .{ .text = "Zig Bridge\n", .color = .aqua },
            .{ .text = "https://github.com/therealnv6/zig-mappings", .color = .gray, .modifiers = &.{ .italic, .underline } },
        },
    );

    try player.sendChatMessage(message);
}
