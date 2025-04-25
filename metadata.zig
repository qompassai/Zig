const std = @import("std");
const zfetch = @import("zfetch");
const Decodable = @import("zig-json-decode").Decodable;

const ORGANIZATION = "qompassai";
const CATEGORIES = [_][]const u8{ "equator", "nautilus", "sojourn", "waveRunner" };
const PROGRAMMING_LANGUAGES = [_][]const u8{
    "python", "rust", "mojo", "zig", "c", "c++", "javaScript", "typeScript",
    "java", "go", "ruby", "php", "swift", "lua", "kotlin", "r", "julia", "dart"
};

const RepoMetadata = struct {
    name: ?[]const u8 = null,
    full_name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    html_url: ?[]const u8 = null,
    topics: ?[][]const u8 = null,
};

const CitationMetadata = struct {
    title: []const u8,
    description: []const u8,
    keywords: [][]const u8,
    related_identifiers: ?[]RelatedIdentifier = null,
    
    const RelatedIdentifier = struct {
        relation: []const u8,
        identifier: []const u8,
    };
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try zfetch.init();
    defer zfetch.deinit();
    
    const repo_url = try getRepoUrl(allocator);
    defer allocator.free(repo_url);
    
    const owner_repo = try extractRepoInfo(allocator, repo_url);
    defer {
        allocator.free(owner_repo.owner);
        allocator.free(owner_repo.repo);
    }
    
    std.debug.print("Repository: {s}/{s}\n", .{ owner_repo.owner, owner_repo.repo });
    
    const effective_owner = if (std.ascii.eqlIgnoreCase(owner_repo.owner, ORGANIZATION)) 
        owner_repo.owner else ORGANIZATION;
    
    const metadata = try getRepoMetadata(allocator, effective_owner, owner_repo.repo);
    defer freeMetadata(allocator, metadata);
    
    const language = try detectProgrammingLanguage(allocator, metadata);
    defer allocator.free(language);
    
    const category = try detectCategory(allocator, metadata);
    defer allocator.free(category);
    
    std.debug.print("Detected Language: {s}\n", .{language});
    std.debug.print("Detected Category: {s}\n", .{category});
    
    try updateMetadataTemplate(allocator, "metadata_template.json", metadata, language, category);
    
    if (metadata.topics) |topics| {
        std.debug.print("\nCurrent topics: ", .{});
        for (topics, 0..) |topic, i| {
            std.debug.print("{s}", .{topic});
            if (i < topics.len - 1) std.debug.print(",", .{});
        }
        std.debug.print("\n", .{});
    }
}

fn getRepoUrl(allocator: std.mem.Allocator) ![]const u8 {
    var process = std.ChildProcess.init(&[_][]const u8{"git", "config", "--get", "remote.origin.url"}, allocator);
    process.stdout_behavior = .Pipe;
    process.stderr_behavior = .Pipe;
    
    try process.spawn();
    
    const stdout = try process.stdout.?.reader().readAllAlloc(allocator, 1024);
    errdefer allocator.free(stdout);
    
    const stderr = try process.stderr.?.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(stderr);
    
    const term = try process.wait();
    
    if (term != .Exited or term.Exited != 0) {
        std.debug.print("Error: Failed to execute git command\n{s}\n", .{stderr});
        return error.GitCommandFailed;
    }
    
    var url = stdout;
    while (url.len > 0 and std.ascii.isWhitespace(url[url.len - 1])) {
        url = url[0 .. url.len - 1];
    }
    
    if (url.len == 0) {
        std.debug.print("Error: Not a git repository or no remote 'origin' set\n", .{});
        return error.NoGitRemote;
    }
    
    return url;
}

const RepoInfo = struct {
    owner: []const u8,
    repo: []const u8,
};

fn extractRepoInfo(allocator: std.mem.Allocator, url: []const u8) !RepoInfo {
    
    if (std.mem.indexOf(u8, url, "git@github.com:")) |_| {
        const parts = try std.mem.split(u8, url, ":");
        const owner_repo = parts.skip(1).next() orelse return error.InvalidUrl;
        const parts2 = try std.mem.split(u8, owner_repo, "/");
        const owner = parts2.next() orelse return error.InvalidUrl;
        var repo = parts2.next() orelse return error.InvalidUrl;
        
        if (std.mem.endsWith(u8, repo, ".git")) {
            repo = repo[0 .. repo.len - 4];
        }
        
        return RepoInfo{
            .owner = try allocator.dupe(u8, owner),
            .repo = try allocator.dupe(u8, repo),
        };
    }
    
    if (std.mem.indexOf(u8, url, "https://github.com/")) |idx| {
        const after_prefix = url[idx + "https://github.com/".len..];
        const parts = try std.mem.split(u8, after_prefix, "/");
        const owner = parts.next() orelse return error.InvalidUrl;
        var repo = parts.next() orelse return error.InvalidUrl;
        
        if (std.mem.endsWith(u8, repo, ".git")) {
            repo = repo[0 .. repo.len - 4];
        }
        
        return RepoInfo{
            .owner = try allocator.dupe(u8, owner),
            .repo = try allocator.dupe(u8, repo),
        };
    }
    
    std.debug.print("Error: Could not parse GitHub URL: {s}\n", .{url});
    return error.InvalidGitHubUrl;
}

fn getRepoMetadata(allocator: std.mem.Allocator, owner: []const u8, repo: []const u8) !RepoMetadata {
    const url = try std.fmt.allocPrint(allocator, "https://api.github.com/repos/{s}/{s}", .{owner, repo});
    defer allocator.free(url);
    
    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();
    try headers.append("Accept", "application/vnd.github.mercy-preview+json");
    
    var req = try zfetch.Request.init(allocator, url, null);
    defer req.deinit();
    try req.do(.GET, headers, null);
    
    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024); // 1MB max
    defer allocator.free(body);
    
    if (req.status.code != 200) {
        std.debug.print("Error: Failed to fetch repository data: {d}\n", .{req.status.code});
        return error.GitHubApiError;
    }
    
    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();
    var tree = try parser.parse(body);
    defer tree.deinit();
    
    var metadata = RepoMetadata{};
    
    if (tree.root.Object.get("name")) |name_value| {
        if (name_value == .String) {
            metadata.name = try allocator.dupe(u8, name_value.String);
        }
    }
    
    if (tree.root.Object.get("full_name")) |full_name_value| {
        if (full_name_value == .String) {
            metadata.full_name = try allocator.dupe(u8, full_name_value.String);
        }
    }
    
    if (tree.root.Object.get("description")) |desc_value| {
        if (desc_value == .String) {
            metadata.description = try allocator.dupe(u8, desc_value.String);
        }
    }
    
    if (tree.root.Object.get("html_url")) |url_value| {
        if (url_value == .String) {
            metadata.html_url = try allocator.dupe(u8, url_value.String);
        }
    }
    
    if (tree.root.Object.get("topics")) |topics_value| {
        if (topics_value == .Array) {
            var topics = try allocator.alloc([]const u8, topics_value.Array.items.len);
            for (topics_value.Array.items, 0..) |topic, i| {
                if (topic == .String) {
                    topics[i] = try allocator.dupe(u8, topic.String);
                }
            }
            metadata.topics = topics;
        }
    }
    
    return metadata;
}

fn freeMetadata(allocator: std.mem.Allocator, metadata: RepoMetadata) void {
    if (metadata.name) |name| allocator.free(name);
    if (metadata.full_name) |full_name| allocator.free(full_name);
    if (metadata.description) |desc| allocator.free(desc);
    if (metadata.html_url) |url| allocator.free(url);
    
    if (metadata.topics) |topics| {
        for (topics) |topic| {
            allocator.free(topic);
        }
        allocator.free(topics);
    }
}

fn detectProgrammingLanguage(allocator: std.mem.Allocator, metadata: RepoMetadata) ![]const u8 {
    if (metadata.name) |name| {
        for (PROGRAMMING_LANGUAGES) |lang| {
            if (std.ascii.indexOfIgnoreCase(name, lang)) |_| {
                return allocator.dupe(u8, lang);
            }
        }
    }
    
    if (metadata.topics) |topics| {
        for (topics) |topic| {
            for (PROGRAMMING_LANGUAGES) |lang| {
                if (std.ascii.eqlIgnoreCase(topic, lang)) {
                    return allocator.dupe(u8, lang);
                }
            }
        }
    }
    
    if (metadata.description) |desc| {
        for (PROGRAMMING_LANGUAGES) |lang| {
            if (std.ascii.indexOfIgnoreCase(desc, lang)) |_| {
                return allocator.dupe(u8, lang);
            }
        }
    }
    
    std.debug.print("Warning: Could not automatically detect programming language.\n", .{});
    std.debug.print("Please enter the programming language (or press Enter for generic): ", .{});
    
    var buf: [100]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse "";
    
    if (input.len == 0) {
        return allocator.dupe(u8, "Programming");
    } else {
        return allocator.dupe(u8, input);
    }
}

fn detectCategory(allocator: std.mem.Allocator, metadata: RepoMetadata) ![]const u8 {
    if (metadata.topics) |topics| {
        for (topics) |topic| {
            for (CATEGORIES) |category| {
                if (std.ascii.eqlIgnoreCase(topic, category)) {
                    return allocator.dupe(u8, category);
                }
            }
        }
    }
    
    // Check name
    if (metadata.name) |name| {
        for (CATEGORIES) |category| {
            if (std.ascii.indexOfIgnoreCase(name, category)) |_| {
                return allocator.dupe(u8, category);
            }
        }
    }
    
    // Prompt user for category
    std.debug.print("Warning: Could not automatically detect project category.\n", .{});
    std.debug.print("Available categories: ", .{});
    for (CATEGORIES, 0..) |category, i| {
        std.debug.print("{s}", .{category});
        if (i < CATEGORIES.len - 1) std.debug.print(", ", .{});
    }
    std.debug.print("\nPlease enter the category: ", .{});
    
    var buf: [100]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse "";
    
    for (CATEGORIES) |category| {
        if (std.mem.eql(u8, input, category)) {
            return allocator.dupe(u8, category);
        }
    }
    
    std.debug.print("Invalid category. Using default: Equator\n", .{});
    return allocator.dupe(u8, "Equator");
}

fn updateMetadataTemplate(
    allocator: std.mem.Allocator, 
    template_path: []const u8, 
    metadata: RepoMetadata, 
    language: []const u8, 
    category: []const u8
) !void {
    const template = try std.fs.cwd().readFileAlloc(allocator, template_path, 1024 * 1024);
    defer allocator.free(template);
    
    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();
    var tree = try parser.parse(template);
    defer tree.deinit();
    
    // Title
    tree.root.Object.put("title", 
        std.json.Value{ .String = try std.fmt.allocPrint(allocator, "{s}: {s}", .{category, language}) });
    
    if (metadata.description) |desc| {
        tree.root.Object.put("description", std.json.Value{ .String = try allocator.dupe(u8, desc) });
    } else {
        tree.root.Object.put("description", std.json.Value{ 
            .String = try std.fmt.allocPrint(allocator, "Educational Content on the {s} Programming Language", .{language}) 
        });
    }
    
    var keywords = std.ArrayList(std.json.Value).init(allocator);
    defer keywords.deinit();
    
    if (metadata.topics) |topics| {
        for (topics) |topic| {
            try keywords.append(std.json.Value{ .String = try allocator.dupe(u8, topic) });
        }
    }
    
    const contains_keyword = struct {
        fn func(list: []const std.json.Value, keyword: []const u8) bool {
            for (list) |item| {
                if (item == .String and std.ascii.eqlIgnoreCase(item.String, keyword)) {
                    return true;
                }
            }
            return false;
        }
    }.func;
    
    if (!contains_keyword(keywords.items, category)) {
        try keywords.append(std.json.Value{ .String = try allocator.dupe(u8, category) });
    }
    
    if (!contains_keyword(keywords.items, language)) {
        try keywords.append(std.json.Value{ .String = try allocator.dupe(u8, language) });
    }
    
    if (!contains_keyword(keywords.items, "AI")) {
        try keywords.append(std.json.Value{ .String = "AI" });
    }
    
    if (!contains_keyword(keywords.items, "Education")) {
        try keywords.append(std.json.Value{ .String = "Education" });
    }
    
    tree.root.Object.put("keywords", std.json.Value{ .Array = keywords.toOwnedSlice() });
    
    if (metadata.html_url) |url| {
        if (tree.root.Object.get("related_identifiers")) |rel_ids| {
            if (rel_ids == .Array) {
                for (rel_ids.Array.items) |*rel_id| {
                    if (rel_id.* == .Object) {
                        if (rel_id.Object.get("relation")) |relation| {
                            if (relation == .String and std.mem.eql(u8, relation.String, "isSupplementTo")) {
                                rel_id.Object.put("identifier", std.json.Value{ .String = try allocator.dupe(u8, url) });
                            }
                        }
                    }
                }
            }
        }
    }
    
    const output_path = "CITATION.cff";
    
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    
    try std.json.stringify(tree.root, .{ .whitespace = .indent_4 }, file.writer());
    
    std.debug.print("Metadata written to {s}\n", .{output_path});
    
    if (metadata.full_name) |full_name| {
        std.debug.print("\nConsider updating GitHub topics with:\n", .{});
        std.debug.print("gh repo edit {s} --add-topic ", .{full_name});
        
        var first = true;
        for (keywords.items) |keyword| {
            if (keyword == .String) {
                if (!first) std.debug.print(",", .{});
                std.debug.print("{s}", .{keyword.String});
                first = false;
            }
        }
        std.debug.print("\n", .{});
    }
}

