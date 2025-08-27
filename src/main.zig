const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

const sound_start_wav = @embedFile("./assets/sounds/shuffle.wav");

const default_num_columns: u16 = 100;
const default_num_rows: u16 = 100;

const cell_size = 4;

const screenWidth = 600;
const screenHeight = 600;

// rows and columns dynamic.
const Grid = struct { num_columns: u16, num_rows: u16 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const grid = try getGridFromSizeArgs(alloc);

    rl.initWindow(screenWidth, screenHeight, "Game of life try");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);

    var started = false;

    const sound_start_wav_mem = try rl.loadWaveFromMemory(".wav", sound_start_wav);
    const sound_start = rl.loadSoundFromWave(sound_start_wav_mem);
    defer rl.unloadSound(sound_start);
    defer rl.unloadWave(sound_start_wav_mem);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        // rl.drawTexture(image_table_tex, 0, 0, rl.Color.white);

        defer rl.drawFPS(10, 10);

        const mouse_click = rl.isMouseButtonPressed(rl.MouseButton.left);

        const t = rl.getTime();

        if (!started and mouse_click) {
            started = true;

            rl.playSound(sound_start);
        } else if (started) {
            rl.drawRectangle(0, 0, grid.num_columns * cell_size, grid.num_rows * cell_size, rl.Color.black);

            const s = try std.fmt.allocPrint(alloc, "Frame time elapsed {d}", .{t});

            const null_term = try alloc.dupeZ(u8, s);

            defer alloc.free(s);

            defer alloc.free(null_term);

            rl.drawText(null_term, 10, 50, 20, rl.Color.yellow.alpha(0.2));
        }
    }
}

fn getGridFromSizeArgs(alloc: std.mem.Allocator) !Grid {
    var args = try std.process.argsWithAllocator(alloc);

    defer args.deinit();

    var columns: u16 = default_num_columns;
    var rows: u16 = default_num_rows;

    var i: u8 = 0;

    while (args.next()) |arg| {
        if (i > 0) {
            std.debug.print("Arg {s}\n", .{arg});
        }

        if (i == 1) {
            columns = try std.fmt.parseInt(u16, arg, 10);
        }

        if (i == 2) {
            rows = try std.fmt.parseInt(u16, arg, 10);
        }

        i += 1;
    }

    // we got rows, but no columns - just make it a square...
    if (i == 1) {
        rows = columns;
    }

    std.debug.print("Columns and rows -> {d} x {d}", .{ columns, rows });

    return Grid{ .num_columns = columns, .num_rows = rows };
}

// Get (x,y) cell from grid with compacted byte bit flags.
// Get the bit from the byte to get the flag from the appropriate bit in a bytes bits (8).
fn getCellBitwise(grid: []u8, width: usize, x: usize, y: usize) bool {
    const idx = y * width + x;
    const byte_index = idx / 8;
    const bit_index = idx % 8;

    return (grid[byte_index] >> bit_index) & 1 == 1;
}

// Get (x,y) cell from grid but stick to simple per array index fetching and a boolean field.
fn getCellLinear(grid: Grid, cells: []LinearCell, x: usize, y: usize) bool {
    const idx = y * grid.num_columns + x;

    return cells[idx].live;
}

// use explicity cell and row values, or have it calculate positions based on
// board column and row counts?
const PositionedCell = struct { column: u16, row: u16, live: bool };

const LinearCell = struct { live: bool };

// fn getNeighbourCount(cells: []Cell) void{
//
// }

// test "get cell state from position - linear" {
//     const gpa = std.testing.allocator;
//
//     var list: std.ArrayList(i32) = .empty;
//
//     defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
//
//     try list.append(gpa, 42);
//
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
//
// test "get cell state from position - positioned" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
//
// test "get neighbours - positioned" {
// }
//
// test "get neighbours - linear" {
// }
