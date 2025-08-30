const std = @import("std");
const rl = @import("raylib");
const cell = @import("cell.zig");

const border_size: u8 = 1;

// rows and columns dynamic.
pub const GridWhitelist = struct {
    num_columns: u8,
    num_rows: u8,

    cells_old: []bool,
    cells: []bool,

    alloc: std.mem.Allocator,

    // Separated from cells creation function due to testing needing it left out at times.
    pub fn setLiveTilesOnStart(self: GridWhitelist, live_cells: []u16) void {
        for (live_cells) |lc| {
            self.cells[lc] = true;
            self.cells_old[lc] = true; // for tests
        }
    }

    pub fn init(alloc: std.mem.Allocator, cols: u8, rows: u8, live_cells: []u16) !GridWhitelist {
        const cells: []bool = try alloc.alloc(bool, @as(u16, rows) * cols);
        const cells_old: []bool = try alloc.alloc(bool, @as(u16, rows) * cols);

        var grid = GridWhitelist{
            .num_columns = cols,
            .num_rows = rows,
            .alloc = alloc,
            .cells_old = cells_old,
            .cells = cells,
        };

        // grid.resetCells();

        // Set random live tiles for simulation.
        grid.setLiveTilesOnStart(live_cells);

        return grid;
    }

    pub fn deinit(self: GridWhitelist) void {
        self.alloc.free(self.cells);
        self.alloc.free(self.cells_old);
    }

    // **** Update calls **** //

    // for reuse in both update functions
    pub fn applyRules(self: GridWhitelist) void {
        var index: u16 = 0;
        // var list_index: u16 = 0;
        var row: u8 = 0;
        // var live: bool = false;
        var col: u8 = 0;
        var neighbours: u8 = 0;

        while (row < self.num_rows) {
            col = 0;

            while (col < self.num_columns) {
                neighbours = self.getLiveCellNeighborCount(index);

                if (self.cells_old[index]) {
                    // std.debug.print("\nLive cell checked: {d}", .{index});

                    if (neighbours <= 1) {
                        // std.debug.print("\nKilled - few/no neighbours", .{});
                        self.cells[index] = false;
                    } else if (neighbours >= 4) {
                        // std.debug.print("\nKilled - too many neighbours", .{});
                        self.cells[index] = false;
                    }
                } else {
                    if (neighbours == 3) {
                        // std.debug.print("\nDead cell set to live - has 3 neighbours {d}", .{index});

                        self.cells[index] = true;
                    }
                }

                index += 1;
                col += 1;
            }

            row += 1;
        }

        // for (self.cells_old) |grid_cell| {
        // }
    }

    // Get neighbors that are live.
    // New: Removed unnecessary variable stack allocations and placed inline.
    fn getLiveCellNeighborCount(self: GridWhitelist, index: u16) u8 {
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
                if (index != current_index and self.cells_old[current_index]) {
                    num_live += 1;
                }

                col_index += 1;
            }

            row_index += 1;
        }

        return num_live;
    }

    // Doesn't update live cell data - takes a snapshot from present state, and uses the snapshot
    // for checks before switching out cell data with new slice.
    // Makes sure the cells update per frame, rather than the later cells having an unfair chronological advantage
    // New: Added mold_cells emcpy and removed allocations/frees to improve performance.
    pub fn updateSnapshot(self: GridWhitelist) !void {
        @memcpy(self.cells_old, self.cells);

        self.applyRules();
    }
};

pub fn drawGrid(grid: GridWhitelist, screen_width: u16, screen_height: u16) void {
    const cell_size: u8 = @intCast(@min(screen_width, screen_height) / grid.num_columns);

    // const cell_size: u8 = try std.fmt.parseInt(u8, smallest_dimension, 10);

    const finalSize: u8 = (cell_size - (border_size * 2));

    var index: u16 = 0;
    var row: u8 = 0;

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
            rl.drawRectangle(@intCast(x), @intCast(y), @intCast(finalSize), @intCast(finalSize), if (grid.cells[index]) rl.Color.lime else rl.Color.light_gray);

            index += 1;
            col += 1;
        }

        row += 1;
    }
}

fn testGetNeighbours(live_cells: []u16, test_index: u16) !u8 {
    const gpa = std.testing.allocator;

    const columns: u8 = 100;
    const rows: u8 = 100;

    const grid = try GridWhitelist.init(gpa, columns, rows, live_cells);

    defer grid.deinit();

    gpa.free(live_cells);

    return grid.getLiveCellNeighborCount(test_index);
}

test "get neighbours - linear" {
    const gpa = std.testing.allocator;

    var marked: []u16 = try gpa.alloc(u16, 8);

    // --------------------------

    std.debug.print("\nGet neighbour for non-edge case with live items nearby\n", .{});

    var test_index: u16 = 150;

    // Can't initialize slice with array init syntax. Need to do it like this.
    @memcpy(marked, &[_]u16{ test_index - 1, test_index + 1, test_index - 100, test_index - 101, test_index - 99, test_index + 99, test_index + 100, test_index + 101 });

    var result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(8, result);

    // --------------------------

    std.debug.print("\nGet neighbour for index with no live items nearby\n", .{});

    test_index = 500;

    marked = try gpa.alloc(u16, 6);
    @memcpy(marked, &[_]u16{ 1, 2, 3, 4, 5, 6 });

    // --------------------------

    result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(0, result);

    // --------------------------

    std.debug.print("\nGet neighbour for index on top row, left corner \n", .{});

    test_index = 0;

    marked = try gpa.alloc(u16, 3);

    @memcpy(marked, &[_]u16{ test_index + 100, test_index + 101, test_index + 1 });

    // --------------------------

    result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(3, result);

    // --------------------------

    std.debug.print("\nGet neighbour for index on bottom row, right corner \n", .{});

    test_index = 999;

    marked = try gpa.alloc(u16, 3);

    @memcpy(marked, &[_]u16{ test_index - 100, test_index - 101, test_index - 1 });

    // --------------------------

    result = try testGetNeighbours(marked, test_index);

    try std.testing.expectEqual(3, result);

    // --------------------------

    std.debug.print("\nget neighbours - linear - success\n", .{});
}
