const jni = @import("jni");
const std = @import("std");
const mappings = @import("mappings.zig");
const types = @import("../types/types.zig");

const java = types.list.java;

const SignaturePart = types.signature.SignaturePart;
const Player = types.player.Player;
const conversion = types.conversion;

pub const state = struct {
    pub var allocator: std.mem.Allocator = undefined;
    pub var env: mappings.Env = undefined;
};

pub const EventType = enum {
    BlockBreakEvent,
};

pub fn tryCallEvent(event: NativeEvent) bool {
    const eventType = event.getEventType() orelse return false;
    const ty = switch (eventType) {
        .BlockBreakEvent => BlockBreakEvent,
    };

    const converted = conversion.object.fromJavaObject(ty, state.env.jenv, event.event);

    if (converted) |ev| {
        handleBlockBreakEvent(ev) catch return false;
    }

    return true;
}

pub fn handleBlockBreakEvent(event: BlockBreakEvent) !void {
    try event.player.sendMessage("meow. you broke a block!");
}

pub const NativeEvent = struct {
    eventId: []const u8 = undefined,
    event: jni.jobject = undefined,

    pub fn init(object: jni.jobject) ?NativeEvent {
        return conversion.object.fromJavaObject(NativeEvent, state.env.jenv, object);
    }

    pub fn getEventType(self: *const NativeEvent) ?EventType {
        return std.meta.stringToEnum(EventType, self.eventId);
    }
};

pub const BlockBreakEvent = struct {
    player: Player = undefined,
};

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
            if (!std.mem.eql(u8, curr.eventId, "BlockBreakEvent")) {
                return;
            }

            _ = tryCallEvent(curr);
        }
    }

    pub fn tick(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {}

    pub fn onLoad(env: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        const allocator = std.heap.page_allocator;
        state.allocator = allocator;
        state.env = mappings.Env.init(env, allocator);

        std.debug.print("meow meow meow (from zig)\n", .{});
    }

    pub fn onEnable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        std.debug.print("meow meow meow (from zig)\n", .{});
    }

    pub fn onDisable(_: *jni.cEnv, _: jni.jobject) callconv(.C) void {
        std.debug.print("meow meow meow (from zig)\n", .{});
    }
};
