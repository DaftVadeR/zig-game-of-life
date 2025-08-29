const std = @import("std");
const rl = @import("raylib");

// const rg = @import("raygui");

const grid = @import("grid.zig");

const sound_start_wav = @embedFile("./assets/sounds/shuffle.wav");

const default_num_columns: u8 = 150;
const default_num_rows: u8 = 150;

const screen_width: i32 = 900;
const screen_height: i32 = 900;

const num_start_cells: u16 = 3000;

const time_between_updates: f64 = 0.05; // separate it from frame rate speed.

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    var cellGrid = try getGridFromSizeArgs(alloc);
    defer cellGrid.deinit();

    // const flags = rl.ConfigFlags{ .window_topmost = true, .borderless_windowed_mode = true, .window_undecorated = true, .window_highdpi = false, .fullscreen_mode = true };
    // rl.setConfigFlags(flags);

    rl.initWindow(screen_width, screen_height - 37, "Game of life try");

    // rl.setWindowPosition(0, 0); // Force to top-left corner
    // rl.setWindowMonitor(0); // Force to monitor 0 (primary)
    // rl.toggleFullscreen();

    // Fiddling to try figure out why screen height is 35px or so higher than explicitly provided values in initWindow call.
    //
    // rl.setWindowMaxSize(screen_width, screen_height);
    // rl.setWindowSize(screen_width, screen_height);
    //
    // rl.setWindowTitle("");

    // const flags = rl.ConfigFlags{ .borderless_windowed_mode = true };
    // rl.setWindowState(flags);
    // rl.setConfigFlags(flags);

    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(240);

    var started = false;

    const sound_start_wav_mem = try rl.loadWaveFromMemory(".wav", sound_start_wav);
    const sound_start = rl.loadSoundFromWave(sound_start_wav_mem);

    defer rl.unloadSound(sound_start);
    defer rl.unloadWave(sound_start_wav_mem);

    var elapsed_time: f32 = 0; // works as a rolling elapsed time, resetting once the update is done.

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        // rl.drawRectangle(0, 0, screen_width, screen_height, rl.Color.red);

        // rl.drawTexture(image_table_tex, 0, 0, rl.Color.white);

        const mouse_click = rl.isMouseButtonPressed(rl.MouseButton.left);

        if (!started and mouse_click) {
            started = true;

            rl.playSound(sound_start);
        } else if (started) {
            elapsed_time += rl.getFrameTime();

            // drawUi();

            grid.drawGrid(cellGrid, screen_width, screen_height);

            if (elapsed_time >= time_between_updates) { // only update every x seconds. Not ideal, but better than limiting framerate.
                elapsed_time = 0;

                try cellGrid.updateSnapshot(); // update based on prior frame data.
                // cellGrid.updateSimple(); // update off the same live cell data.
            }
        }

        rl.drawRectangle(0, 0, 100, 40, rl.Color.black);
        rl.drawFPS(10, 10);
    }
}

// fn updateCells(){}

fn drawUi() void {
    // rl.drawRectangle(0, 0, grid.num_columns * cell_size, grid.num_rows * cell_size, rl.Color.black);

    // const s = try std.fmt.allocPrint(alloc, "Frame time {d}", .{t});
    // defer alloc.free(s);

    // const null_term = try alloc.dupeZ(u8, s);
    // defer alloc.free(null_term);

    // rl.drawText(null_term, 10, 50, 20, rl.Color.yellow.alpha(0.2));

}

fn getGridFromSizeArgs(alloc: std.mem.Allocator) !grid.Grid {
    var args = try std.process.argsWithAllocator(alloc);

    defer args.deinit();

    var columns: u8 = default_num_columns;
    var rows: u8 = default_num_rows;

    var i: u8 = 0;

    while (args.next()) |arg| {
        if (i > 0) {
            std.debug.print("Arg {s}\n", .{arg});
        }

        if (i == 1) {
            columns = try std.fmt.parseInt(u8, arg, 10);
        }

        if (i == 2) {
            rows = try std.fmt.parseInt(u8, arg, 10);
        }

        i += 1;
    }

    // we got columns, but no rows - just make it a square...
    if (i == 1) {
        rows = columns;
    }

    std.debug.print("Columns and rows -> {d} x {d}", .{ columns, rows });

    // Get cells
    const live_cells_start = try grid.Grid.getRandomLiveVals(alloc, num_start_cells, columns, rows);
    const grid_cells = try grid.Grid.init(alloc, columns, rows, live_cells_start);

    return grid_cells;
}

// This makes sure all test blocks are picked up
test {
    std.debug.print("running test in main.zig", .{});
    std.testing.refAllDecls(@This());
}
