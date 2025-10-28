const std = @import("std");
const zxml = @import("zxml");

test "SVG parsing with mmap" {
    var parser = try SvgParser.initWithMmap(std.testing.allocator, "src/tests/tiger.svg");
    defer parser.deinit();
    var doc = try parser.parse();
    defer doc.deinit();
    try std.testing.expectEqual(240, doc.paths.items.len);
}

test "SVG parsing with in-memory" {
    const xml_content = @embedFile("tiger.svg");
    var parser = try SvgParser.initInMemory(std.testing.allocator, xml_content);
    defer parser.deinit();
    var doc = try parser.parse();
    defer doc.deinit();
    try std.testing.expectEqual(240, doc.paths.items.len);
}

test "SVG parsing with stream" {
    const xml_content = @embedFile("tiger.svg");
    var reader = std.io.Reader.fixed(xml_content);
    var parser = try SvgParser.initStream(std.testing.allocator, &reader);
    defer parser.deinit();
    var doc = try parser.parse();
    defer doc.deinit();
    try std.testing.expectEqual(240, doc.paths.items.len);
}

pub const SvgPath = struct {
    dummy: u8 = 0,

    fn parse(allocator: std.mem.Allocator, xml: SvgXml.PathXml) !SvgPath {
        // ignored for this example...
        _ = allocator;
        _ = xml;
        return SvgPath{};
    }
};

pub const SvgDocument = struct {
    allocator: std.mem.Allocator,

    paths: std.ArrayList(SvgPath) = std.ArrayList(SvgPath).empty,

    pub fn deinit(self: *SvgDocument) void {
        self.paths.deinit(self.allocator);
    }
};
pub const SvgParser = struct {
    const Parser = zxml.TypedParser(SvgXml);

    xml: SvgXml,
    parser: Parser,

    pub fn initWithMmap(allocator: std.mem.Allocator, filepath: []const u8) !SvgParser {
        var parser = Parser.initWithMmap(allocator, filepath) catch |err| {
            std.log.err("could not parse SVG: {}", .{err});
            return error.InvalidSvg;
        };
        errdefer parser.deinit();
        return SvgParser{
            .xml = parser.result,
            .parser = parser,
        };
    }

    pub fn initInMemory(allocator: std.mem.Allocator, content: []const u8) !SvgParser {
        var parser = Parser.initInMemory(allocator, content) catch |err| {
            std.log.err("could not parse SVG: {}", .{err});
            return error.InvalidSvg;
        };
        errdefer parser.deinit();
        return SvgParser{
            .xml = parser.result,
            .parser = parser,
        };
    }

    pub fn initStream(allocator: std.mem.Allocator, reader: *std.io.Reader) !SvgParser {
        var parser = Parser.init(allocator, reader) catch |err| {
            std.log.err("could not parse SVG: {}", .{err});
            return error.InvalidSvg;
        };
        errdefer parser.deinit();
        return SvgParser{
            .xml = parser.result,
            .parser = parser,
        };
    }

    pub fn parse(self: *SvgParser) !SvgDocument {
        const allocator = self.parser.allocator;
        var doc = SvgDocument{
            .allocator = allocator,
            .paths = try std.ArrayList(SvgPath).initCapacity(allocator, 240),
        };
        errdefer doc.deinit();

        // This is where we have a bug, especially in ReleaseFast mode,
        // but maybe also in ReleaseSafe mode.
        while (try self.xml.paths.next()) |item| {
            const path = try SvgPath.parse(allocator, item);
            try doc.paths.append(allocator, path);
        }

        return doc;
    }

    pub fn deinit(self: *SvgParser) void {
        self.parser.deinit();
    }
};

const SvgXml = struct {
    paths: zxml.Iterator("path", SvgXml.PathXml),

    const PathXml = struct {
        d: []const u8,
    };
};
