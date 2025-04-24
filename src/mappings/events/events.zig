const std = @import("std");
const jni = @import("jni");

const root = @import("root");

const native_plugin = root.native_plugin;

const types = root.types;

const signature = types.signature;
const conversion = types.conversion;

const SignaturePart = signature.SignaturePart;
const Player = types.player.Player;

const BridgeError = native_plugin.BridgeError;

// public exports
pub const blocks = @import("blocks.zig");

pub const EventType = enum {
    BlockBreakEvent,
};

pub fn unreachableErrorCallback(_: BridgeError) void {
    unreachable;
}

pub fn debugErrorCallback(err: BridgeError) void {
    std.debug.print("an error has occured during an event, {any}", .{err});
}

pub const EventRegistry = struct {
    listeners: std.ArrayList(EventCallback),
    errorCallback: *const fn (err: BridgeError) void,

    pub fn init(allocator: std.mem.Allocator) EventRegistry {
        return .{
            .listeners = std.ArrayList(EventCallback).init(allocator),
            .errorCallback = debugErrorCallback,
        };
    }

    pub fn setErrorCallback(self: *EventRegistry, callback: *const fn (err: BridgeError) void) void {
        self.errorCallback = callback;
    }

    pub fn listenFallible(self: *EventRegistry, comptime T: type, function: *const fn (context: *T) BridgeError!void) !void {
        try self.listeners.append(EventCallback.initFallible(T, function));
    }

    pub fn listen(self: *EventRegistry, comptime T: type, function: *const fn (context: *T) void) !void {
        try self.listeners.append(EventCallback.init(T, function));
    }

    pub fn processEvent(self: *EventRegistry, event: NativeEvent) void {
        for (self.listeners.items) |callback| {
            callEvent(event, callback) catch |e| self.errorCallback(e);
        }
    }
};

fn eventNoOpFallible(_: *anyopaque) BridgeError!void {}
fn eventNoOp(_: *anyopaque) void {}

pub const EventCallback = struct {
    functionFallible: *const fn (context: *anyopaque) BridgeError!void,
    function: *const fn (context: *anyopaque) void,

    fallible: bool,

    pub fn initFallible(comptime T: type, function: *const fn (context: *T) BridgeError!void) EventCallback {
        return .{
            .functionFallible = @ptrCast(function),
            .function = eventNoOp,
            .fallible = true,
        };
    }

    pub fn init(comptime T: type, function: *const fn (context: *T) void) EventCallback {
        return .{
            .functionFallible = eventNoOpFallible,
            .function = @ptrCast(function),
            .fallible = false,
        };
    }

    pub fn call(self: EventCallback, value: *anyopaque) BridgeError!void {
        if (self.fallible) {
            try self.functionFallible(value);
        } else {
            self.function(value);
        }
    }
};

pub fn callEvent(event: NativeEvent, callback: EventCallback) BridgeError!void {
    const eventType = event.getEventType() orelse return;
    const ty = switch (eventType) {
        .BlockBreakEvent => blocks.BlockBreakEvent,
    };

    const converted = conversion.object.fromJavaObject(ty, native_plugin.state.vm.env, event.event);

    if (converted) |ev| {
        try callback.call(@constCast(&ev));
    }
}

pub const NativeEvent = struct {
    eventId: []const u8 = undefined,
    event: jni.jobject = undefined,

    pub fn init(object: jni.jobject) ?NativeEvent {
        return conversion.object.fromJavaObject(NativeEvent, native_plugin.state.vm.env, object);
    }

    pub fn getEventType(self: *const NativeEvent) ?EventType {
        return std.meta.stringToEnum(EventType, self.eventId);
    }
};
