const jni = @import("jni");
const std = @import("std");
const mappings = @import("mappings.zig");
const types = @import("../types/types.zig");
const events = @import("events.zig");

const NativeEvent = events.NativeEvent;
const BlockBreakEvent = events.BlockBreakEvent;
const EventCallback = events.EventCallback;
const EventRegistry = events.EventRegistry;

const java = types.list.java;

const SignaturePart = types.signature.SignaturePart;
const Player = types.player.Player;
const conversion = types.conversion;

pub const state = struct {
    pub var allocator: std.mem.Allocator = undefined;
    pub var eventRegistry: EventRegistry = undefined;
    pub var env: mappings.Env = undefined;
};

pub fn handleBlockBreakEvent(event: *BlockBreakEvent) void {
    event.player.sendMessage("meow. you broke a block! (from zig!)") catch unreachable;
}

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
    pub fn getName(_: *jni.cEnv, _: jni.jobject) callconv(.C) jni.jstring {
        return state.env.newString("bridge-zig");
    }

    pub fn getLanguage(_: *jni.cEnv, _: jni.jobject) callconv(.C) jni.jstring {
        return state.env.newString("zig");
    }

    pub fn processEvent(_: *jni.cEnv, _: jni.jobject, event: jni.jobject) callconv(.C) void {
        const nativeEvent = NativeEvent.init(event);

        if (nativeEvent) |curr| {
            state.eventRegistry.processEvent(curr);
        }
    }

    pub fn tick(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {}

    pub fn onLoad(env: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        const allocator = std.heap.page_allocator;
        state.allocator = allocator;
        state.env = mappings.Env.init(env, allocator);
        state.eventRegistry = EventRegistry.init(allocator);

        std.debug.print("meow meow meow (from zig)\n", .{});
    }

    pub fn onEnable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        std.debug.print("meow meow meow (from zig)\n", .{});
        state.eventRegistry.listen(BlockBreakEvent, handleBlockBreakEvent) catch unreachable;
    }

    pub fn onDisable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        std.debug.print("meow meow meow (from zig)\n", .{});
    }
};
