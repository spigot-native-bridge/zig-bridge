const std = @import("std");
const jni = @import("jni");
const types = @import("../types/types.zig");

const state = @import("native_plugin.zig").state;

const signature = types.signature;
const conversion = types.conversion;

const SignaturePart = signature.SignaturePart;
const Player = types.player.Player;

pub const EventType = enum {
    BlockBreakEvent,
};

pub fn CancelEventImpl(comptime T: type) fn (self: *const T, cancelled: bool) void {
    return struct {
        pub fn inner(self: *const T, cancelled: bool) void {
            if (!comptime @hasField(T, "_object")) {
                @compileError("T in CancelEventImpl must contain an `_object` field.");
            }

            state.env.callVoidMethod(
                @field(self, "_object"),
                "setCancelled",
                .{
                    .bodyType = &.{SignaturePart.primitives.Boolean},
                },
                .{cancelled},
            ) catch unreachable;
        }
    }.inner;
}

pub const BlockBreakEvent = struct {
    player: Player = undefined,
    _object: jni.jobject = undefined,

    pub const setCancelled = CancelEventImpl(BlockBreakEvent);
};

pub const EventRegistry = struct {
    listeners: std.ArrayList(EventCallback),

    pub fn init(allocator: std.mem.Allocator) EventRegistry {
        return .{
            .listeners = std.ArrayList(EventCallback).init(allocator),
        };
    }

    pub fn listen(self: *EventRegistry, comptime T: type, function: *const fn (context: *T) void) !void {
        try self.listeners.append(EventCallback.init(T, function));
    }

    pub fn processEvent(self: *EventRegistry, event: NativeEvent) void {
        for (self.listeners.items) |callback| {
            callEvent(event, callback);
        }
    }
};

pub const EventCallback = struct {
    function: *const fn (context: *anyopaque) void,

    pub fn init(comptime T: type, function: *const fn (context: *T) void) EventCallback {
        return .{
            .function = @ptrCast(function),
        };
    }

    pub fn call(self: EventCallback, value: *anyopaque) void {
        self.function(value);
    }
};

pub fn callEvent(event: NativeEvent, callback: EventCallback) void {
    const eventType = event.getEventType() orelse return;
    const ty = switch (eventType) {
        .BlockBreakEvent => BlockBreakEvent,
    };

    const converted = conversion.object.fromJavaObject(ty, state.env.jenv, event.event);

    if (converted) |ev| {
        callback.call(@constCast(&ev));
    }
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
