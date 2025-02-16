const std = @import("std");
const http = std.http;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Get the API key from an environment variable
    const env_api_key = std.process.getEnvVarOwned(gpa.allocator(), "OPENAI_API_KEY") catch |err| {
        std.debug.print("Error: Could not retrieve API key from environment: {}\n", .{err});
        return;
    };
    defer gpa.allocator().free(env_api_key);

    var client = http.Client{ .allocator = gpa.allocator() };
    defer client.deinit();

    // Allocate a buffer for server headers
    var buf: [4096]u8 = undefined;

    var response_buffer = std.ArrayList(u8).init(gpa.allocator()); //  Create response storage
    defer response_buffer.deinit();

    // Get user input
    var stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();

    try stdout.print("Enter a theme for your poem: ", .{});
    var theme: [100]u8 = undefined;

    const input_size = (try stdin.readUntilDelimiterOrEof(&theme, '\n')) orelse null;

    const theme_trimmed = if (input_size) |size|
        std.mem.trimRight(u8, theme[0..size.len], " \n\r\t")
    else
        "";

    // Construct JSON payload for AI query
    const request_body = std.fmt.allocPrint(gpa.allocator(),
        \\{{
        \\  "model": "gpt-4o",
        \\  "messages": [
        \\    {{"role": "system", "content": "You are a poetic assistant."}},
        \\    {{"role": "user", "content": "Write a beautiful poem about {s}."}}
        \\  ],
        \\  "max_tokens": 500
        \\}}
    , .{theme_trimmed}) catch unreachable;
    defer gpa.allocator().free(request_body);

    // Allocate API key with `allocPrint`
    const auth_header = std.fmt.allocPrint(gpa.allocator(), "Bearer {s}", .{env_api_key}) catch unreachable;
    defer gpa.allocator().free(auth_header);

    // Send the request to OpenAI's API
    const res = try client.fetch(.{
        .method = .POST,
        .payload = request_body,
        .location = .{ .url = "https://api.openai.com/v1/chat/completions" },
        .server_header_buffer = &buf,
        .response_storage = .{ .dynamic = &response_buffer }, // Store the response body here!
        .headers = http.Client.Request.Headers{
            .content_type = .{ .override = "application/json" },
            .authorization = .{ .override = auth_header },
        },
        .max_append_size = 8192,
    });

    std.debug.print("HTTP Status: {s}\n", .{@tagName(res.status)});

    const response_body = response_buffer.items;

    std.debug.print("Raw API Response:\n{s}\n", .{response_body});

    const start_index = std.mem.indexOf(u8, response_body, "\"content\": \"") orelse {
        std.debug.print("Error: No content field found in response.\n", .{});
        return;
    };
    const end_index = std.mem.indexOfPos(u8, response_body, start_index + 12, "\"") orelse {
        std.debug.print("Error: Could not find end of AI response.\n", .{});
        return;
    };

    const poem: []const u8 = response_body[start_index + 11 .. end_index];

    std.debug.print("\nAI-Generated Poem:\n{s}\n", .{poem});
}
