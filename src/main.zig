const std = @import("std");

const pulse = struct {
    pub const Simple = opaque {};
    pub const StreamDirection = enum(i32) {
        no_direction = 0,
        playback = 1,
        record = 2,
        upload = 3,
    };

    pub const SampleFormat = enum(i32) {
        u8,
        alaw,
        ulaw,
        s16le,
        s16be,
        float32le,
        float32be,
        s32le,
        s32be,
        s24le,
        s24be,
        s24_32le,
        s24_32be,
        max,
        invalid = -1,
    };

    pub const ChannelPosition = enum(i32) {
        invalid = -1,
        mono = 0,
        front_left,
        front_right,
        front_center,
        rear_center,
        rear_left,
        rear_right,
        lfe,
        front_left_of_center,
        front_right_of_center,
        side_left,
        side_right,
        aux0,
        aux1,
        aux2,
        aux3,
        aux4,
        aux5,
        aux6,
        aux7,
        aux8,
        aux9,
        aux10,
        aux11,
        aux12,
        aux13,
        aux14,
        aux15,
        aux16,
        aux17,
        aux18,
        aux19,
        aux20,
        aux21,
        aux22,
        aux23,
        aux24,
        aux25,
        aux26,
        aux27,
        aux28,
        aux29,
        aux30,
        aux31,
        top_center,
        top_front_left,
        top_front_right,
        top_front_center,
        top_rear_left,
        top_rear_right,
        top_rear_center,
        max,
    };

    const channels_max = 32;
    pub const ChannelMap = extern struct {
        channels: u8,
        map: [channels_max]ChannelPosition,
    };

    pub const SampleSpec = extern struct {
        format: SampleFormat,
        rate: u32,
        channels: u8,
    };

    pub const BufferAttr = extern struct {
        max_length: u32,
        tlength: u32,
        minreq: u32,
        fragsize: u32,
    };

    //
    // Extern function definitions
    //
    extern fn pa_simple_read(
        simple: *Simple,
        data: [*]u8,
        bytes: usize,
        err: *i32,
    ) callconv(.C) i32;

    extern fn pa_simple_new(
        server: ?[*:0]const u8,
        name: [*:0]const u8,
        dir: StreamDirection,
        dev: ?[*:0]const u8,
        stream_name: [*:0]const u8,
        sample_spec: *const SampleSpec,
        map: ?*const ChannelMap,
        attr: ?*const BufferAttr,
        err: ?*i32,
    ) callconv(.C) ?*Simple;

    extern fn pa_simple_free(simple: *Simple) callconv(.C) void;

    //
    // Function alias'
    //

    pub const simpleNew = pa_simple_new;
    pub const simpleRead = pa_simple_read;
    pub const simpleFree = pa_simple_free;
};

const buffer_capacity = 32 * @sizeOf(u16);
const rate = 44100;
var buffer: [buffer_capacity]u8 = undefined;

var pulse_connection: *pulse.Simple = undefined;

pub fn main() !void {
    std.log.info("Working", .{});
    try recordAudio();
}

fn recordAudio() !void {
    var output_file = try std.fs.cwd().createFile("output.raw", .{ .truncate = true });
    defer output_file.close();

    var output_writer = output_file.writer();

    const sample_spec = pulse.SampleSpec{
        .format = .s16le,
        .rate = rate,
        .channels = 1,
    };
    var errcode: i32 = 0;
    pulse_connection = pulse.simpleNew(null, "pulse_test", .record, null, "test_stream", &sample_spec, null, null, &errcode) orelse
        return error.ConnectToServerFailed;

    const audio_record_begin = std.time.milliTimestamp();
    const audio_record_end = audio_record_begin + (std.time.ms_per_s * 5);
    var current_timestamp = std.time.milliTimestamp();
    while (current_timestamp < audio_record_end) {
        if (pulse.simpleRead(pulse_connection, &buffer, buffer_capacity, &errcode) < 0) {
            std.log.err("Failed to read from input device", .{});
            return error.ReadInputDeviceFail;
        }
        _ = try output_writer.write(buffer[0..]);
        std.time.sleep(std.time.ns_per_us * 5);
        current_timestamp = std.time.milliTimestamp();
    }
    pulse.simpleFree(pulse_connection);
}
