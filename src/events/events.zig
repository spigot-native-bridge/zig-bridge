const std = @import("std");
const jni = @import("jni");

const bridge = @import("../bridge.zig");

const native_plugin = bridge.native_plugin;

const types = bridge.types;

const signature = types.signature;
const conversion = types.conversion;

const SignaturePart = signature.SignaturePart;
const Player = types.player.Player;

const BridgeError = native_plugin.BridgeError;

// public exports
pub const blocks = @import("blocks.zig");
pub const player = @import("player.zig");

pub const EventType = enum {
    BlockBreakEvent,
    PlayerJoinEvent,
    PlayerChatEvent,
};

pub fn unreachableErrorCallback(_: BridgeError, _: NativeEvent) void {
    unreachable;
}

pub fn debugErrorCallback(err: BridgeError, event: NativeEvent) void {
    std.debug.print("\n[ee] [BRIDGE-ZIG EVENT ERROR]\n", .{});
    std.debug.print("[ee] an {any} error has occured during a {s} event!\n", .{ err, event.eventId });
    std.debug.print("[ee] this would have been a runtime crash in unreachableErrorCallback()\n", .{});
    std.debug.print("[ee] this is an error within one of your plugins, *not* with bridge-zig.\n\n", .{});
}

pub const EventRegistry = struct {
    listeners: std.ArrayList(EventCallback),
    errorCallback: *const fn (err: BridgeError, event: NativeEvent) void,

    pub fn init(allocator: std.mem.Allocator) EventRegistry {
        return .{
            .listeners = std.ArrayList(EventCallback).init(allocator),
            .errorCallback = debugErrorCallback,
        };
    }

    pub fn setErrorCallback(self: *EventRegistry, callback: *const fn (err: BridgeError, event: NativeEvent) void) void {
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

            // nothing to do, this is not the same event.
            if (callback.eventType != event.getEventType()) {
                continue;
            }

            callEvent(event, callback) catch |e| self.errorCallback(e, event);
        }
    }
};

fn eventNoOpFallible(_: *anyopaque) BridgeError!void {}
fn eventNoOp(_: *anyopaque) void {}

pub const EventCallback = struct {
    functionFallible: *const fn (context: *anyopaque) BridgeError!void,
    function: *const fn (context: *anyopaque) void,

    fallible: bool,
    eventType: EventType,

    pub fn initFallible(comptime T: type, function: *const fn (context: *T) BridgeError!void) EventCallback {
        if (!std.meta.hasFn(T, "getEventType")) {
            @compileError("Passed an event type to .init() or .initFallible() without a getEventType() function");
        }

        return .{
            .functionFallible = @ptrCast(function),
            .function = eventNoOp,
            .fallible = true,
            .eventType = T.getEventType(),
        };
    }

    pub fn init(comptime T: type, function: *const fn (context: *T) void) EventCallback {
        if (!std.meta.hasFn(T, "getEventType")) {
            @compileError("Passed an event type to .init() or .initFallible() without a getEventType() function");
        }

        return .{
            .functionFallible = eventNoOpFallible,
            .function = @ptrCast(function),
            .fallible = false,
            .eventType = T.getEventType(),
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

fn callEventTyped(event: NativeEvent, callback: EventCallback, comptime T: type) BridgeError!void {
    const converted = conversion.object.fromJavaObject(
        T,
        native_plugin.state.vm.env,
        event.event,
    );

    if (converted) |ev| {
        try callback.call(@constCast(&ev));
    }
}

pub fn callEvent(event: NativeEvent, callback: EventCallback) BridgeError!void {
    const eventType = event.getEventType() orelse return;
    //const ty = switch (eventType) {
    //    .BlockBreakEvent => blocks.BlockBreakEvent,
    //    .PlayerJoinEvent => player.PlayerJoinEvent,
    //};

    switch (eventType) {
        .BlockBreakEvent => try callEventTyped(event, callback, blocks.BlockBreakEvent),
        .PlayerJoinEvent => try callEventTyped(event, callback, player.PlayerJoinEvent),
        .PlayerChatEvent => try callEventTyped(event, callback, player.PlayerChatEvent),
    }
    //switch (eventType) {
    //    .BlockBreakEvent => {
    //        const converted = conversion.object.fromJavaObject(
    //            blocks.BlockBreakEvent,
    //            native_plugin.state.vm.env,
    //            event.event,
    //        );

    //        if (converted) |ev| {
    //            try callback.call(@constCast(&ev));
    //        }
    //    },
    //    .PlayerJoinEvent => {
    //        const converted = conversion.object.fromJavaObject(
    //            player.PlayerJoinEvent,
    //            native_plugin.state.vm.env,
    //            event.event,
    //        );

    //        if (converted) |ev| {
    //            try callback.call(@constCast(&ev));
    //        }
    //    },
    //}
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
