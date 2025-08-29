const std = @import("std");
const rl = @import("raylib");
const cell = @import("cell.zig");

const border_size: u8 = 1;

// rows and columns dynamic.
pub const Grid = struct {
    num_columns: u8,
    num_rows: u8,
    cells_old: []cell.LinearCell,
    cells: []cell.LinearCell,
    live_cells_start: []u16,
    alloc: std.mem.Allocator,

    pub fn getRandomLiveVals(alloc: std.mem.Allocator, live_cells_num: u16, cols: u8, rows: u8) ![]u16 {
        // create index slice with live cell indexes
        var live_on_start: []u16 = try alloc.alloc(u16, live_cells_num);

        // ** RNG ** //
        var seed: u64 = undefined;

        try std.posix.getrandom(std.mem.asBytes(&seed));

        std.debug.print("\nSeed? {d}\n", .{seed});

        var prng = std.Random.DefaultPrng.init(seed);

        var rand = prng.random();
        // ** //

        var index_start: u16 = 0;

        // Generate random live tiles
        while (index_start < live_cells_num) {
            // std.debug.print("\n rows * cols - 1 {}\n", .{@as(u16, rows) * @as(u16, cols) - 1});
            live_on_start[index_start] = rand.intRangeAtMost(u16, 0, @as(u16, rows) * @as(u16, cols) - 1);

            index_start += 1;
        }

        return live_on_start;
    }

    pub fn resetCells(self: Grid) void {
        // std.debug.print("\nLive vals? {any}\n", .{live_on_start});

        var index: u16 = 0;

        // Instantiate tiles.
        while (index < self.cells.len) {
            self.cells[index] = cell.LinearCell{ .live = false };
            self.cells_old[index] = cell.LinearCell{ .live = false };

            index += 1;
        }

        // OLD CODE - OVER COMPLICATED FOR SETTING INITIAL VALUES
        // Can't initialize slice with array init syntax. Need to do it like this.
        // @memcpy(live_on_start, );

        // const midway_rows = (rows / 2) - 2;
        // const midway_cols = (columns / 2) - 2;

        // var index: usize = 0;
        // var row: u32 = 0;
        //
        // while (row < rows) {
        //     var col: u32 = 0;
        //
        //     while (col < columns) {
        //         // should fill a 9 by 9 grid mostly in the center?
        //         if (row > midway_rows and
        //             col > midway_cols and
        //             row <= midway_rows + 3 and
        //             col <= midway_cols + 3)
        //         {
        //             cells[index] = cell.LinearCell{ .live = true };
        //         } else {
        //             cells[index] = cell.LinearCell{ .live = false };
        //         }
        //
        //         col += 1;
        //         index += 1;
        //     }
        //
        //     row += 1;
        // }

        // return cells;
    }

    // Separated from cells creation function due to testing needing it left out at times.
    pub fn setLiveTilesOnStart(self: Grid) void {
        // Make cells live if found in randomly generated starting live values slice.
        for (self.live_cells_start) |index_to_enable| {
            self.setCellStateByIndex(index_to_enable, true);
        }
    }

    pub fn init(alloc: std.mem.Allocator, cols: u8, rows: u8, live_cells: []u16) !Grid {
        const cells: []cell.LinearCell = try alloc.alloc(cell.LinearCell, @as(u16, rows) * cols);
        const cells_old: []cell.LinearCell = try alloc.alloc(cell.LinearCell, @as(u16, rows) * cols);

        var grid = Grid{
            .num_columns = cols,
            .num_rows = rows,
            .alloc = alloc,
            .live_cells_start = live_cells,
            .cells_old = cells_old,
            .cells = cells,
        };

        // grid.resetCells();

        // Set random live tiles for simulation.
        grid.setLiveTilesOnStart();

        return grid;
    }

    pub fn deinit(self: Grid) void {
        self.alloc.free(self.live_cells_start);
        self.alloc.free(self.cells);
        self.alloc.free(self.cells_old);
    }

    pub fn setCellStateByIndex(self: Grid, index: u16, live: bool) void {
        self.cells[index].live = live;
    }

    // **** Update calls **** //

    // for reuse in both update functions
    pub fn applyRules(self: Grid) void {
        var index: u16 = 0;

        for (self.cells_old) |grid_cell| {
            const neighbours = self.getLiveCellNeighborCount(index);

            if (grid_cell.live) {
                // std.debug.print("\nLive cell checked: {d}", .{index});

                if (neighbours <= 1) {
                    // std.debug.print("\nKilled - few/no neighbours", .{});
                    self.cells[index].live = false;
                } else if (neighbours >= 4) {
                    // std.debug.print("\nKilled - too many neighbours", .{});
                    self.cells[index].live = false;
                }
            } else if (!grid_cell.live and neighbours == 3) {
                // std.debug.print("\nDead cell set to live - has 3 neighbours {d}", .{index});

                self.cells[index].live = true;
            }

            index += 1;
        }
    }

    // Get neighbors that are live.
    // New: Removed unnecessary variable stack allocations and placed inline.
    fn getLiveCellNeighborCount(self: Grid, index: u16) u8 {
        // Simplest way for now
        //
        // get first relevant row for cell, then loop through it and next two rows, but only checking columns around index.
        const cr: u8 = @intCast(index / self.num_columns);
        const cc: u8 = @intCast(index % self.num_columns);

        // const current_row: i32 = cr - 1;
        // const current_cell: i32 = cc - 1;

        // const start_row = ; // -1 to get the row before it horizontally.
        // const start_col = ; // -1 to get the column before it horizontally.

        var row_index: u8 = @intCast(@max(@as(i16, cr) - 1, 0));

        var num_live: u8 = 0;

        // std.debug.print("\nstart row {} - end row {}\n", .{ start_row, end_row });
        // std.debug.print("start col {} - end col {}\n", .{ start_col, end_col });

        while (row_index <= @min(cr + 1, self.num_rows - 1)) {
            var col_index: u8 = @intCast(@max(@as(i16, cc) - 1, 0));

            while (col_index <= @min(cc + 1, self.num_columns - 1)) {
                // std.debug.print("\nOverflow? {} {} {}\n", .{ row_index, self.num_columns, col_index });
                const current_index: u16 = @as(u16, row_index) * self.num_columns + col_index;

                // don't count if current cell, and if not alive
                if (index != current_index and self.cells_old[current_index].live) {
                    num_live += 1;
                }

                col_index += 1;
            }

            row_index += 1;
        }

        return num_live;
    }

    // fn countLiveTiles(cells: []cell.LinearCell) usize {
    //     var count: usize = 0;
    //
    //     for (cells) |c| {
    //         if (c.live) {
    //             count += 1;
    //         }
    //     }
    //
    //     return count;
    // }

    // Doesn't update live cell data - takes a snapshot from present state, and uses the snapshot
    // for checks before switching out cell data with new slice.
    // Makes sure the cells update per frame, rather than the later cells having an unfair chronological advantage
    // New: Added mold_cells emcpy and removed allocations/frees to improve performance.
    pub fn updateSnapshot(self: Grid) !void {
        @memcpy(self.cells_old, self.cells);

        self.applyRules();
    }
};

pub fn drawGrid(grid: Grid, screen_width: u16, screen_height: u16) void {
    var index: u16 = 0;
    var row: u8 = 0;

    const cell_size: u8 = @intCast(@min(screen_width, screen_height) / grid.num_columns);

    // const cell_size: u8 = try std.fmt.parseInt(u8, smallest_dimension, 10);

    const finalSize: u8 = (cell_size - (border_size * 2));

    while (row < grid.num_rows) {
        const y: u16 = @as(u16, row) * cell_size + border_size;

        var col: u8 = 0;

        while (col < grid.num_columns) {
            const x: u16 = @as(u16, col) * cell_size + border_size;

            // std.debug.print("x: {}, y: {}, size: {}\n", .{ x, y, finalSize });
            // std.debug.print("index: {} live: {}\n", .{ index, grid.cells[index].live });

            // const color: rl.Color = ;

            // draw fill
            // rl.drawRectangle(x, y, finalSize, finalSize, col);

            // draw inside
            rl.drawRectangle(@intCast(x), @intCast(y), @intCast(finalSize), @intCast(finalSize), if (grid.cells[index].live) rl.Color.lime else rl.Color.light_gray);

            index += 1;
            col += 1;
        }

        row += 1;
    }
}

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

fn testGetNeighbours(live_cells: []usize, test_index: usize) !u8 {
    const gpa = std.testing.allocator;

    const columns: u32 = 100;
    const rows: u32 = 100;

    const grid: *Grid = try Grid.init(gpa, columns, rows, live_cells);
    defer grid.deinit();

    return grid.getLiveCellNeighborCount(test_index);
}

test "get neighbours - linear" {
    const gpa = std.testing.allocator;

    var marked: []usize = try gpa.alloc(usize, 8);

    // --------------------------

    std.debug.print("\nGet neighbour for non-edge case with live items nearby\n", .{});

    var test_index: usize = 150;

    // Can't initialize slice with array init syntax. Need to do it like this.
    @memcpy(marked, &[_]usize{ test_index - 1, test_index + 1, test_index - 100, test_index - 101, test_index - 99, test_index + 99, test_index + 100, test_index + 101 });

    var result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(8, result);

    // --------------------------

    std.debug.print("\nGet neighbour for index with no live items nearby\n", .{});

    test_index = 500;

    marked = try gpa.alloc(usize, 6);
    @memcpy(marked, &[_]usize{ 1, 2, 3, 4, 5, 6 });

    // --------------------------

    result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(0, result);

    // --------------------------

    std.debug.print("\nGet neighbour for index on top row, left corner \n", .{});

    test_index = 0;

    marked = try gpa.alloc(usize, 3);

    @memcpy(marked, &[_]usize{ test_index + 100, test_index + 101, test_index + 1 });

    // --------------------------

    result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(3, result);

    // --------------------------

    std.debug.print("\nGet neighbour for index on bottom row, right corner \n", .{});

    test_index = 999;

    marked = try gpa.alloc(usize, 3);

    @memcpy(marked, &[_]usize{ test_index - 100, test_index - 101, test_index - 1 });

    // --------------------------

    result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(3, result);

    // --------------------------

    std.debug.print("\nget neighbours - linear - success\n", .{});

    gpa.free(marked);
}
