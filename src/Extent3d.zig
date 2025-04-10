const Self = @This();

width: u32,
height: u32,
depth: u32 = 1,

pub fn volume(self: Self) usize {
    return self.width * self.height * self.depth;
}
