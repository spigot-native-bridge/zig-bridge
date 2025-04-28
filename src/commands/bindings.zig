const std = @import("std");
const jni = @import("jni");
const bridge = @import("../bridge.zig");

const types = bridge.types;
const mappings = bridge.mappings;
const plugin = bridge.native_plugin;

const conversion = types.conversion;
const signature = types.signature;

const SignaturePart = signature.SignaturePart;
const Message = bridge.chat.Message;

const BridgeError = bridge.BridgeError;

pub const CommandSender = @import("sender.zig").CommandSender;
pub const SubcommandMap = std.StaticStringMap(Command);

pub const Command = struct {
    const Self = @This();

    name: []const u8,
    description: []const u8 = "",
    usageMessage: []const u8 = "",

    init: *const fn () BridgeError!void = emptyInit,
    callback: *const fn (sender: CommandSender, label: []const u8, args: [][]const u8) BridgeError!void = emptyCommand,

    subcommands: SubcommandMap = SubcommandMap.initComptime(.{}),

    pub fn emptyInit() !void {}
    pub fn emptyCommand(_: CommandSender, _: []const u8, _: [][]const u8) !void {}

    pub fn call(self: *const Self, sender: CommandSender, label: []const u8, args: [][]const u8) !void {
        if (args.len >= 1 and self.subcommands.kvs.len >= 1) {
            const subLabel = args[0];
            const sub = self.subcommands.get(subLabel);

            if (sub) |command| {
                try command.call(sender, subLabel, args[1..]);
            } else {
                try sender.sendMessage("Could not find subcommand.");
            }
        } else {
            try self.callback(sender, label, args);
        }
    }
};

pub const BridgeCommandRegistry = struct {
    const Self = @This();

    obj: jni.jobject,
    allocator: std.mem.Allocator,
    commands: std.StringHashMap(Command),

    pluginSignature: []const u8 = "zig",

    pub fn init(obj: jni.jobject, allocator: std.mem.Allocator) BridgeCommandRegistry {
        var map = std.StringHashMap(Command).init(allocator);
        map.ensureUnusedCapacity(16) catch unreachable;
        return .{
            .obj = obj,
            .commands = map,
            .allocator = allocator,
        };
    }

    pub fn setPluginSignature(self: *Self, pluginSignature: []const u8) void {
        self.pluginSignature = pluginSignature;
    }

    pub fn registerCommand(self: *Self, command: Command) !void {
        try self.commands.put(command.name, command);
        try self.createCommand(
            command.name,
            command.description,
            command.usageMessage,
            self.pluginSignature,
        );

        try command.init();
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

    // todo: this function is supposed to only be a thin call for Java to call,
    // perhaps move a large portion into other functions, and into the BridgeCommandRegistry.
    pub fn processCommands(_: *jni.cEnv, _: jni.jobject, jsender: jni.jobject, jlabel: jni.jstring, jargs: jni.jarray) callconv(.C) void {
        var vm = plugin.state.vm;
        vm.attachToVM() catch unreachable;

        const sender = conversion.object.fromJavaObject(CommandSender, vm.jvmEnv().*, jsender) orelse return;
        var label = std.mem.span(vm.newCString(jlabel, false));

        // remove the prefix from the command (e.g. /example:zig)
        if (std.mem.containsAtLeastScalar(u8, label, 1, ':')) {
            var split = std.mem.splitBackwardsScalar(u8, label, ':');

            const newLabel = split.next();

            if (newLabel) |token| {
                label = registry.allocator.dupeZ(u8, token) catch unreachable;
            }
        }

        var argsList = std.ArrayList([]const u8).init(registry.allocator);
        const argsLength = vm.env.getArrayLength(jargs);

        for (0..@intCast(argsLength)) |idx| {
            const element = vm.env.getObjectArrayElement(jargs, @intCast(idx)) orelse continue;
            const cstr = std.mem.span(vm.newCString(element, false));

            argsList.append(cstr) catch continue;
        }

        const command = registry.commands.get(label);

        if (command) |c| {
            c.call(sender, label, argsList.toOwnedSlice() catch unreachable) catch unreachable;
        }
    }
};

pub const ZigBridgeInfoCommand = Command{
    .name = "zig",
    .description = "Command to show general information about Zig Bridge",
    .callback = zigBridgeCommand,
};

pub fn zigBridgeCommand(sender: CommandSender, _: []const u8, _: [][]const u8) !void {
    const message = try Message.initSlice(
        plugin.state.allocator,
        &.{
            .{ .text = "This server is running ", .color = .yellow },
            .{ .text = "Zig Bridge ", .color = .aqua },
            .{ .text = "v" ++ bridge.Version ++ "\n", .color = .aqua },
            .{ .text = "https://github.com/therealnv6/zig-mappings", .color = .gray, .modifiers = &.{ .italic, .underline } },
        },
    );

    try sender.sendChatMessage(message);
}
