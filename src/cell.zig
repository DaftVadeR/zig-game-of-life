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

// use explicity cell and row values, or have it calculate positions based on
// board column and row counts?
pub const PositionedCell = struct { column: u16, row: u16, live: bool };

pub const LinearCell = struct { live: bool };

// fn getNeighbourCount(cells: []Cell) void{
//
// }
