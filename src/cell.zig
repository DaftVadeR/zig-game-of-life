const std = @import("std");
const grid = @import("grid.zig");

// Get (x,y) cell from grid with compacted byte bit flags.
// Get the bit from the byte to get the flag from the appropriate bit in a bytes bits (8).
pub fn getCellBitwise(cellGrid: []u8, width: usize, x: usize, y: usize) bool {
    const idx = y * width + x;
    const byte_index = idx / 8;
    const bit_index = idx % 8;

    return (cellGrid[byte_index] >> bit_index) & 1 == 1;
}

// Get (x,y) cell from grid but stick to simple per array index fetching and a boolean field.
pub fn getCellLinear(cellGrid: grid.Grid, cells: []LinearCell, x: usize, y: usize) bool {
    const idx = y * cellGrid.num_columns + x;

    return cells[idx].live;
}

pub fn generateRandomLiveCellsForGrid(alloc: std.mem.Allocator, live_cells_num: u16, cols: u8, rows: u8) ![]u16 {
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

// use explicity cell and row values, or have it calculate positions based on
// board column and row counts?
pub const PositionedCell = struct { column: u16, row: u16, live: bool };

pub const LinearCell = struct { live: bool };

// fn getNeighbourCount(cells: []Cell) void{
//
// }
