const jni = @import("jni");
const std = @import("std");
const bridge = @import("../bridge.zig");

const commands = bridge.commands;

const mappings = bridge.mappings;
const events = bridge.events;
const types = bridge.types;

const load = bridge.load;
const enable = bridge.enable;
const disable = bridge.disable;

const NativeEvent = events.NativeEvent;
const EventCallback = events.EventCallback;
const EventRegistry = events.EventRegistry;

const CommandRegistry = commands.BridgeCommandRegistry;

const java = types.list.java;

const SignaturePart = types.signature.SignaturePart;
const Player = types.player.Player;
const conversion = types.conversion;

pub const BridgeError = error{} || mappings.VMError;

pub const VMState = mappings.VMState;
pub const PluginState = struct {
    const Self = @This();
    const InitFunction = *const fn (state: *Self) BridgeError!void;

    commandRegistry: CommandRegistry = undefined,
    eventRegistry: EventRegistry,
    allocator: std.mem.Allocator,
    vm: VMState,

    // functions
    enable: InitFunction = undefined,
    disable: InitFunction = undefined,

    pub fn init(env: *jni.cEnv) !Self {
        const allocator = std.heap.c_allocator;
        return .{
            .allocator = allocator,
            .eventRegistry = EventRegistry.init(allocator),
            .vm = try mappings.VMState.init(env, allocator),
        };
    }

    pub fn markPlugin(self: *Self, enableFunction: InitFunction, disableFunction: InitFunction) void {
        self.enable = enableFunction;
        self.disable = disableFunction;
    }
};

pub var state: PluginState = undefined;

pub const BridgeNativePlugin = struct {
    pub fn getOnlinePlayers(env: *jni.cEnv, obj: jni.jobject) !std.ArrayList(Player) {
        const jobject = try state.env.callObjectMethod(
            obj,
            "getOnlinePlayers",
            .{
                .bodyType = &.{},
                .returnType = SignaturePart.util.Collection,
            },
            .{},
        );

        if (jobject == null) {
            return error.MethodNotFound;
        }

        const collection = try java.Collection.fromObject(env, jobject);

        return try collection.toZigArrayList(Player, state.allocator);
    }
};

pub const BridgeNativePluginExport = extern struct {
    pub fn tick(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {}

    pub fn onLoad(env: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        state = PluginState.init(env) catch unreachable;
        //load(&state) catch unreachable;
        load(&state);
    }

    pub fn onEnable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        state.vm.attachToVM() catch unreachable;
        state.enable(&state) catch unreachable;
        //enable(&state);
    }

    pub fn processEvent(_: *jni.cEnv, _: jni.jobject, jevent: jni.jobject) callconv(.C) void {
        state.vm.attachToVM() catch unreachable;

        if (NativeEvent.init(jevent)) |event| {
            state.eventRegistry.processEvent(event);
        }
    }

    pub fn onDisable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        state.vm.attachToVM() catch unreachable;
        state.disable(&state) catch unreachable;
        //disable(&state);
    }

    pub fn getName(_: *jni.cEnv, _: jni.jobject) callconv(.C) jni.jstring {
        return state.vm.newUnicodeStringUtf8("bridge-zig") catch unreachable;
    }

    pub fn getLanguage(_: *jni.cEnv, _: jni.jobject) callconv(.C) jni.jstring {
        return state.vm.newUnicodeStringUtf8("zig") catch unreachable;
    }
};
