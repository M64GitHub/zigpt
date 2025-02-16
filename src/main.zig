const std = @import("std");
const http = std.http; // ✅ Import http module

// ✅ Define headers as constants
const header_content_type: []const u8 = "application/json"[0..];
const header_authorization: []const u8 = "Bearer YOUR_OPENAI_API_KEY"[0..];

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Create an HTTP client
    var client = http.Client{ .allocator = gpa.allocator() };
    defer client.deinit();

    // Allocate a buffer for server headers
    var buf: [1024]u8 = undefined;

    // Get user input
    var stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();

    try stdout.print("Enter a theme for your poem: ", .{});
    var theme: [100]u8 = undefined;
    const input_size = try stdin.readUntilDelimiterOrEof(&theme, '\n');
    if (input_size == null) {
        std.debug.print("Error: No input received.\n", .{});
        return;
    }

    const theme_length: usize = theme.len;
    const theme_str: []const u8 = theme[0..theme_length];

    // ✅ Construct JSON payload for AI query
    const request_body = std.fmt.allocPrint(gpa.allocator(),
        \\{
        \\  "model": "gpt-4o",
        \\  "messages": [
        \\    {"role": "system", "content": "You are a poetic assistant."},
        \\    {"role": "user", "content": "Write a beautiful poem about {s}."}
        \\  ],
        \\  "max_tokens": 100
        \\}
    , .{theme_str}) catch unreachable;

    defer gpa.allocator().free(request_body);

    // ✅ Send the request to OpenAI's API
    const res = try client.fetch(.{
        .method = .POST,
        .payload = request_body,
        .location = .{ .url = "https://api.openai.com/v1/chat/completions" },
        .server_header_buffer = &buf,
        .headers = http.Client.Request.Headers{
            .content_type = .{ .override = header_content_type }, // ✅ Use `.override`
            .authorization = .{ .override = header_authorization }, // ✅ Use `.override`
        },
    });

    // ✅ Read the response body
    var response_buf: [4096]u8 = undefined;
    const response_size = try res.reader.readAll(&response_buf); // ✅ Use `.reader` instead of `.body`

    // ✅ Print the full raw response for debugging
    std.debug.print("Raw API Response:\n{s}\n", .{response_buf[0..response_size]});

    // ✅ Extract the AI-generated poem manually
    const start_index = std.mem.indexOf(u8, response_buf[0..response_size], "\"content\": \"") orelse {
        std.debug.print("Error: No content field found in response.\n", .{});
        return;
    };
    const end_index = std.mem.indexOfPos(u8, response_buf[0..response_size], start_index + 11, "\"") orelse {
        std.debug.print("Error: Could not find end of AI response.\n", .{});
        return;
    };

    const poem: []const u8 = response_buf[start_index + 11 .. end_index];

    // ✅ Print AI-generated poem
    std.debug.print("\nAI-Generated Poem:\n{s}\n", .{poem});
}
