const std = @import("std");

pub const COLOR_CHAR = "§";
const ALPHABET = "0123456789abcdefklmnor";

pub const Message = struct {
    parts: std.ArrayList(MessagePart),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, part: MessagePart) !Message {
        var list = std.ArrayList(MessagePart).init(allocator);
        try list.append(part);

        return .{
            .parts = list,
            .allocator = allocator,
        };
    }

    pub fn initSlice(allocator: std.mem.Allocator, parts: []const MessagePart) !Message {
        var list = std.ArrayList(MessagePart).init(allocator);
        try list.appendSlice(parts);

        return .{
            .parts = list,
            .allocator = allocator,
        };
    }

    pub fn appendPart(self: *Message, part: MessagePart) !void {
        try self.parts.append(part);
    }

    pub fn toString(self: *const Message) ![]const u8 {
        var list = std.ArrayList(u8).init(self.allocator);

        for (self.parts.items) |part| {
            try list.appendSlice(try part.toString(self.allocator));
        }

        return list.toOwnedSlice();
    }
};

pub const MessagePart = struct {
    color: Color = .white,
    modifiers: []const Modifier = &.{},
    text: []const u8 = "",

    pub fn toString(self: *const MessagePart, allocator: std.mem.Allocator) ![]const u8 {
        var list = std.ArrayList(u8).init(allocator);

        try list.appendSlice(COLOR_CHAR);
        try list.append(self.color.toColorCode());

        for (self.modifiers) |modifier| {
            try list.appendSlice(COLOR_CHAR);
            try list.append(modifier.toColorCode());
        }

        try list.appendSlice(self.text);

        return list.toOwnedSlice();
    }
};

pub const Color = enum {
    black,
    dark_blue,
    dark_green,
    dark_aqua,
    dark_red,
    dark_purple,
    gold,
    gray,
    dark_gray,
    blue,
    green,
    aqua,
    red,
    light_purple,
    yellow,
    white,

    pub fn toColorCode(self: Color) u8 {
        return ALPHABET[self.getId()];
    }

    pub fn getId(self: Color) u8 {
        return @intFromEnum(self);
    }
};

pub const Modifier = enum {
    magic,
    bold,
    strikethrough,
    underline,
    italic,
    reset,

    pub fn toColorCode(self: Modifier) u8 {
        return ALPHABET[16 + self.getId()];
    }

    pub fn getId(self: Modifier) u8 {
        return @intFromEnum(self);
    }
};
