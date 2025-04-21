const jni = @import("jni");
const std = @import("std");
const mappings = @import("mappings.zig");
const events = @import("events/events.zig");
const root = @import("root");

const types = root.types;

const load = root.load;
const enable = root.enable;
const disable = root.disable;

const NativeEvent = events.NativeEvent;
const BlockBreakEvent = events.blocks.BlockBreakEvent;
const EventCallback = events.EventCallback;
const EventRegistry = events.EventRegistry;

const java = types.list.java;

const SignaturePart = types.signature.SignaturePart;
const Player = types.player.Player;
const conversion = types.conversion;

pub const PluginState = struct {
    eventRegistry: EventRegistry,
    allocator: std.mem.Allocator,
    env: mappings.Env,

    pub fn init(env: *jni.cEnv) PluginState {
        const allocator = std.heap.page_allocator;
        return .{
            .allocator = allocator,
            .eventRegistry = EventRegistry.init(allocator),
            .env = mappings.Env.init(env, allocator),
        };
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
        state = PluginState.init(env);
        load(&state);
    }

    pub fn onEnable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        enable(&state);
    }

    pub fn processEvent(_: *jni.cEnv, _: jni.jobject, jevent: jni.jobject) callconv(.C) void {
        if (NativeEvent.init(jevent)) |event| {
            state.eventRegistry.processEvent(event);
        }
    }

    pub fn onDisable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        disable(&state);
    }

    pub fn getName(_: *jni.cEnv, _: jni.jobject) callconv(.C) jni.jstring {
        return state.env.newString("bridge-zig");
    }

    pub fn getLanguage(_: *jni.cEnv, _: jni.jobject) callconv(.C) jni.jstring {
        return state.env.newString("zig");
    }
};
