const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

const sound_start_wav = @embedFile("./assets/sounds/shuffle.wav");

const default_num_columns: u16 = 100;
const default_num_rows: u16 = 100;

const cell_size = 8;

const screen_width: i32 = 800;
const screen_height: i32 = 800;

// rows and columns dynamic.
const Grid = struct {
    num_columns: u16,
    num_rows: u16,
    cells: []LinearCell,
    alloc: std.mem.Allocator,

    fn getCells(columns: u16, rows: u16, alloc: std.mem.Allocator) ![]LinearCell {
        var cells: []LinearCell = try alloc.alloc(LinearCell, rows * columns);

        const midway_rows = (rows / 2) - 2;
        const midway_cols = (columns / 2) - 2;

        var index: usize = 0;
        var row: u32 = 0;

        while (row < rows) {
            var col: u32 = 0;

            while (col < columns) {
                // should fill a 9 by 9 grid mostly in the center?
                if (row > midway_rows and
                    col > midway_cols and
                    row < midway_rows + 3 and
                    col < midway_cols + 3)
                {
                    cells[index] = LinearCell{ .live = true };
                } else {
                    cells[index] = LinearCell{ .live = false };
                }
                col += 1;
                index += 1;
            }

            row += 1;
        }

        return cells;
    }

    fn init(cols: u16, rows: u16, alloc: std.mem.Allocator) !*const Grid {
        const cells = try getCells(cols, rows, alloc);

        const grid = try alloc.create(Grid);

        grid.* = Grid{ .num_columns = cols, .num_rows = rows, .alloc = alloc, .cells = cells };

        return grid;
    }

    fn deinit(self: *const Grid) void {
        self.alloc.free(self.cells);
        self.alloc.destroy(self);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const grid = try getGridFromSizeArgs(alloc);
    defer grid.deinit();

    // const flags = rl.ConfigFlags{ .window_topmost = true, .borderless_windowed_mode = true, .window_undecorated = true, .window_highdpi = false, .fullscreen_mode = true };
    // rl.setConfigFlags(flags);

    rl.initWindow(screen_width, screen_height, "Game of life try");
    // rl.setWindowPosition(0, 0); // Force to top-left corner
    // rl.setWindowMonitor(0); // Force to monitor 0 (primary)
    // rl.toggleFullscreen();

    // Fiddling to try figure out why screen height is 35px or so higher than explicitly provided values in initWindow call.
    //
    // rl.setWindowMaxSize(screen_width, screen_height);
    // rl.setWindowSize(screen_width, screen_height);
    //
    // rl.setWindowTitle("");

    // const flags = rl.ConfigFlags{ .fullscreen_mode = true, .borderless_windowed_mode = true, .window_maximized = true };
    // rl.setWindowState(flags);
    // rl.setConfigFlags(rl.ConfigFlags{})

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

        rl.clearBackground(rl.Color.dark_gray);
        rl.drawRectangle(0, 0, screen_width, screen_height, rl.Color.red);

        // rl.drawTexture(image_table_tex, 0, 0, rl.Color.white);

        defer rl.drawFPS(10, 10);

        const mouse_click = rl.isMouseButtonPressed(rl.MouseButton.left);

        // const t = rl.getFrameTime();

        if (!started and mouse_click) {
            started = true;

            rl.playSound(sound_start);
        } else if (started) {
            drawUi();
            drawGrid(grid);
        }
    }
}

fn drawUi() void {
    // rl.drawRectangle(0, 0, grid.num_columns * cell_size, grid.num_rows * cell_size, rl.Color.black);

    // const s = try std.fmt.allocPrint(alloc, "Frame time {d}", .{t});
    // defer alloc.free(s);

    // const null_term = try alloc.dupeZ(u8, s);
    // defer alloc.free(null_term);

    // rl.drawText(null_term, 10, 50, 20, rl.Color.yellow.alpha(0.2));

}

fn getGridFromSizeArgs(alloc: std.mem.Allocator) !*const Grid {
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

    // we got columns, but no rows - just make it a square...
    if (i == 1) {
        rows = columns;
    }

    std.debug.print("Columns and rows -> {d} x {d}", .{ columns, rows });

    // Get cells
    const grid = try Grid.init(columns, rows, alloc);

    return grid;
}

const border_size: u8 = 1;

fn drawGrid(grid: *const Grid) void {
    var index: usize = 0;
    var row: u32 = 0;

    const finalSize: u8 = (cell_size - (border_size * 2));

    while (row < grid.num_rows) {
        const y: u32 = row * cell_size + border_size;

        var col: u32 = 0;

        while (col < grid.num_columns) {
            const x: u32 = col * cell_size + border_size;

            // std.debug.print("x: {}, y: {}, size: {}\n", .{ x, y, finalSize });
            // std.debug.print("index: {} live: {}\n", .{ index, grid.cells[index].live });

            const color: rl.Color = if (grid.cells[index].live) rl.Color.lime else rl.Color.gray;

            // draw fill
            // rl.drawRectangle(x, y, finalSize, finalSize, col);

            // draw inside
            rl.drawRectangle(@intCast(x), @intCast(y), @intCast(finalSize), @intCast(finalSize), color);

            index += 1;
            col += 1;
        }

        // std.debug.print("errr row? {}\n", .{row});
        row += 1;
    }
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
