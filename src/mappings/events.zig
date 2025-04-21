const std = @import("std");
const jni = @import("jni");
const types = @import("../types/types.zig");

const state = @import("native_plugin.zig").state;

const Player = types.player.Player;
const conversion = types.conversion;

pub const EventType = enum {
    BlockBreakEvent,
};

pub const BlockBreakEvent = struct {
    player: Player = undefined,
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
