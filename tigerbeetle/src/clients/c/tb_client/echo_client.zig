const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;

const vsr = @import("../tb_client.zig").vsr;
const Header = vsr.Header;
const stdx = vsr.stdx;
const constants = vsr.constants;
const RingBuffer = vsr.ring_buffer.RingBuffer;
const MessagePool = vsr.message_pool.MessagePool;
const Message = MessagePool.Message;

pub fn EchoClient(comptime StateMachine_: type, comptime MessageBus: type) type {
    return struct {
        const Self = @This();

        // Exposing the same types the real client does:
        const VSRClient = vsr.Client(StateMachine_, MessageBus);
        pub const StateMachine = VSRClient.StateMachine;
        pub const Request = VSRClient.Request;

        /// Custom Demuxer which treats Event(operation)s as results and echoes them back.
        pub fn DemuxerType(comptime operation: StateMachine.Operation) type {
            return struct {
                const Demuxer = @This();

                results: []u8,
                events_decoded: u32 = 0,

                pub fn init(reply: []u8) Demuxer {
                    return Demuxer{ .results = reply };
                }

                pub fn decode(self: *Demuxer, event_offset: u32, event_count: u32) []u8 {
                    // Double check the event offset/count are contiguously decoded from results.
                    assert(self.events_decoded == event_offset);
                    self.events_decoded += event_count;

                    // Double check the results has enough event bytes to echo back.
                    const byte_count = @sizeOf(StateMachine.Event(operation)) * event_count;
                    assert(self.results.len >= byte_count);

                    // Echo back the result bytes and consume the events.
                    defer self.results = self.results[byte_count..];
                    return self.results[0..byte_count];
                }
            };
        }

        id: u128,
        cluster: u128,
        release: vsr.Release = vsr.Release.minimum,
        request_number: u32 = 0,
        request_inflight: ?Request = null,
        message_pool: *MessagePool,

        pub fn init(
            allocator: mem.Allocator,
            options: struct {
                id: u128,
                cluster: u128,
                replica_count: u8,
                message_pool: *MessagePool,
                message_bus_options: MessageBus.Options,
            },
        ) !Self {
            _ = allocator;
            _ = options.replica_count;
            _ = options.message_bus_options;

            return Self{
                .id = options.id,
                .cluster = options.cluster,
                .message_pool = options.message_pool,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            _ = allocator;
            if (self.request_inflight) |inflight| self.release_message(inflight.message.base());
        }

        pub fn tick(self: *Self) void {
            const inflight = self.request_inflight orelse return;
            self.request_inflight = null;

            // Allocate a reply message.
            const reply = self.get_message().build(.request);
            defer self.release_message(reply.base());

            // Copy the request message's entire content including header into the reply.
            const operation = inflight.message.header.operation;
            stdx.copy_disjoint(
                .exact,
                u8,
                reply.buffer,
                inflight.message.buffer,
            );

            // Similarly to the real client, release the request message before invoking the
            // callback. This necessitates a `copy_disjoint` above.
            self.release_message(inflight.message.base());

            switch (inflight.callback) {
                .request => |callback| {
                    callback(inflight.user_data, operation.cast(Self.StateMachine), reply.body());
                },
                .register => |callback| {
                    const result = vsr.RegisterResult{
                        .batch_size_limit = constants.message_body_size_max,
                    };
                    callback(inflight.user_data, &result);
                },
            }
        }

        pub fn register(
            self: *Self,
            callback: Request.RegisterCallback,
            user_data: u128,
        ) void {
            assert(self.request_inflight == null);
            assert(self.request_number == 0);

            const message = self.get_message().build(.request);
            errdefer self.release_message(message.base());

            // We will set parent, session, view and checksums only when sending for the first time:
            message.header.* = .{
                .client = self.id,
                .request = self.request_number,
                .cluster = self.cluster,
                .command = .request,
                .operation = .register,
                .release = vsr.Release.minimum,
            };

            assert(self.request_number == 0);
            self.request_number += 1;

            self.request_inflight = .{
                .message = message,
                .user_data = user_data,
                .callback = .{ .register = callback },
            };
        }

        pub fn request(
            self: *Self,
            callback: Request.Callback,
            user_data: u128,
            operation: StateMachine.Operation,
            events: []const u8,
        ) void {
            const event_size: usize = switch (operation) {
                inline else => |operation_comptime| @sizeOf(StateMachine.Event(operation_comptime)),
            };
            assert(events.len <= constants.message_body_size_max);
            assert(events.len % event_size == 0);

            const message = self.get_message().build(.request);
            errdefer self.release_message(message.base());

            message.header.* = .{
                .client = self.id,
                .request = 0, // Set by raw_request() below.
                .cluster = self.cluster,
                .command = .request,
                .release = vsr.Release.minimum,
                .operation = vsr.Operation.from(StateMachine, operation),
                .size = @intCast(@sizeOf(Header) + events.len),
            };

            stdx.copy_disjoint(.exact, u8, message.body(), events);
            self.raw_request(callback, user_data, message);
        }

        pub fn raw_request(
            self: *Self,
            callback: Request.Callback,
            user_data: u128,
            message: *Message.Request,
        ) void {
            assert(message.header.client == self.id);
            assert(message.header.cluster == self.cluster);
            assert(message.header.release.value == self.release.value);
            assert(!message.header.operation.vsr_reserved());
            assert(message.header.size >= @sizeOf(Header));
            assert(message.header.size <= constants.message_size_max);

            message.header.request = self.request_number;
            self.request_number += 1;

            assert(self.request_inflight == null);
            self.request_inflight = .{
                .message = message,
                .user_data = user_data,
                .callback = .{ .request = callback },
            };
        }

        pub fn get_message(self: *Self) *Message {
            return self.message_pool.get_message(null);
        }

        pub fn release_message(self: *Self, message: *Message) void {
            self.message_pool.unref(message);
        }
    };
}

test "Echo Demuxer" {
    const StateMachine = vsr.state_machine.StateMachineType(
        @import("../../../testing/storage.zig").Storage,
        constants.state_machine_config,
    );
    const MessageBus = vsr.message_bus.MessageBusClient;
    const Client = EchoClient(StateMachine, MessageBus);

    var prng = std.rand.DefaultPrng.init(42);
    inline for ([_]StateMachine.Operation{
        .create_accounts,
        .create_transfers,
    }) |operation| {
        const Event = StateMachine.Event(operation);
        var events: [@divExact(constants.message_body_size_max, @sizeOf(Event))]Event = undefined;
        prng.fill(std.mem.asBytes(&events));

        for (0..events.len) |i| {
            const events_total = i + 1;
            const events_data = std.mem.sliceAsBytes(events[0..events_total]);
            var demuxer = Client.DemuxerType(operation).init(events_data);

            var events_offset: usize = 0;
            while (events_offset < events_total) {
                const events_limit = events_total - events_offset;
                const events_count = @max(1, prng.random().uintAtMost(usize, events_limit));
                defer events_offset += events_count;

                const reply_bytes = demuxer.decode(@intCast(events_offset), @intCast(events_count));
                const reply: []Event = @alignCast(std.mem.bytesAsSlice(Event, reply_bytes));
                try testing.expectEqual(&reply[0], &events[events_offset]);
                try testing.expectEqual(reply.len, events[events_offset..][0..events_count].len);
            }
        }
    }
}
