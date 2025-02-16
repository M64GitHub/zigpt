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

    // Allocate a response buffer
    var response_buffer = std.ArrayList(u8).init(gpa.allocator()); // ✅ Create response storage
    defer response_buffer.deinit();

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
        \\{{
        \\  "model": "gpt-4o",
        \\  "messages": [
        \\    {{"role": "system", "content": "You are a poetic assistant."}},
        \\    {{"role": "user", "content": "Write a beautiful poem about {s}."}}
        \\  ],
        \\  "max_tokens": 100
        \\}}
    , .{theme_str}) catch unreachable;

    defer gpa.allocator().free(request_body);

    // ✅ Send the request to OpenAI's API
    const res = try client.fetch(.{
        .method = .POST,
        .payload = request_body,
        .location = .{ .url = "https://api.openai.com/v1/chat/completions" },
        .server_header_buffer = &buf,
        .response_storage = .{ .dynamic = &response_buffer }, // ✅ Store the response body here!
        .headers = http.Client.Request.Headers{
            .content_type = .{ .override = header_content_type },
            .authorization = .{ .override = header_authorization },
        },
    });

    std.debug.print("Status: {s}\n", .{@tagName(res.status)});

    // ✅ Extract the response body
    const response_body = response_buffer.items; // ✅ Now we can read the body!

    // ✅ Print the full raw response for debugging
    std.debug.print("Raw API Response:\n{s}\n", .{response_body});

    // ✅ Extract the AI-generated response manually
    const start_index = std.mem.indexOf(u8, response_body, "\"content\": \"") orelse {
        std.debug.print("Error: No content field found in response.\n", .{});
        return;
    };
    const end_index = std.mem.indexOfPos(u8, response_body, start_index + 11, "\"") orelse {
        std.debug.print("Error: Could not find end of AI response.\n", .{});
        return;
    };

    const poem: []const u8 = response_body[start_index + 11 .. end_index];

    // ✅ Print AI-generated poem
    std.debug.print("\nAI-Generated Poem:\n{s}\n", .{poem});
}
