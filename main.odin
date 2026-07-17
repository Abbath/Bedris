#+feature dynamic-literals
package main

import "core:flags"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:slice"
import rl "vendor:raylib"

Tile :: struct {
  filled: bool,
  color:  rl.Color,
}

Field :: struct {
  width:  int,
  height: int,
  data:   [dynamic]Tile,
}

Shape :: enum {
  SQUARE,
  LINE,
  SNAKE1,
  SNAKE2,
  JSHAPE,
  LSHAPE,
  TSHAPE,
  WEIRD,
}

Piece :: struct {
  shape:    Shape,
  color:    rl.Color,
  segments: [dynamic]Point,
}

Point :: distinct [2]int

square := []Point{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
line := []Point{{0, 0}, {1, 0}, {2, 0}, {3, 0}}
snake1 := []Point{{0, 0}, {1, 0}, {1, 1}, {2, 1}}
snake2 := []Point{{0, 1}, {1, 1}, {1, 0}, {2, 0}}
jshape := []Point{{0, 1}, {1, 1}, {2, 1}, {2, 0}}
lshape := []Point{{0, 1}, {1, 1}, {2, 1}, {0, 0}}
tshape := []Point{{0, 1}, {1, 1}, {2, 1}, {1, 0}}

oner := []Point{{0, 0}}
twoer := []Point{{0, 0}, {0, 1}}
threeer1 := []Point{{0, 0}, {0, 1}, {1, 0}}
threeer2 := []Point{{0, 0}, {0, 1}, {1, 1}}
threeer3 := []Point{{0, 0}, {1, 0}, {2, 0}}
fiver1 := []Point{{0, 1}, {1, 1}, {1, 0}, {2, 1}, {1, 2}}
fiver2 := []Point{{0, 0}, {1, 0}, {2, 0}, {0, 1}, {2, 1}}
fiver3 := []Point{{0, 0}, {1, 0}, {2, 0}, {1, 1}, {2, 1}}
fiver4 := []Point{{0, 0}, {1, 0}, {2, 0}, {0, 1}, {1, 1}}
fiver5 := []Point{{0, 0}, {1, 0}, {2, 0}, {0, 1}, {0, 2}}
fiver6 := []Point{{0, 0}, {1, 0}, {2, 0}, {2, 1}, {2, 2}}
fiver7 := []Point{{0, 0}, {1, 0}, {2, 0}, {3, 0}, {3, 1}}
fiver8 := []Point{{0, 0}, {1, 0}, {2, 0}, {3, 0}, {0, 1}}
fiver9 := []Point{{0, 1}, {1, 1}, {2, 1}, {2, 0}, {0, 2}}
fiver10 := []Point{{0, 0}, {0, 1}, {1, 1}, {2, 1}, {2, 2}}

traditional_shapes := [Shape][]Point {
  .SQUARE = square,
  .LINE   = line,
  .SNAKE1 = snake1,
  .SNAKE2 = snake2,
  .JSHAPE = jshape,
  .LSHAPE = lshape,
  .TSHAPE = tshape,
  .WEIRD  = {},
}

traditional_colors := [Shape]rl.Color {
  .SQUARE = rl.YELLOW,
  .LINE   = rl.SKYBLUE,
  .SNAKE1 = rl.LIME,
  .SNAKE2 = rl.RED,
  .JSHAPE = rl.ORANGE,
  .LSHAPE = rl.BLUE,
  .TSHAPE = rl.VIOLET,
  .WEIRD  = rl.BROWN,
}

shapes := [][]Point{square, line, snake1, snake2, jshape, lshape, tshape}
weird_shapes := [][]Point{oner, twoer, threeer1, threeer2, threeer3, fiver1, fiver2, fiver3, fiver4, fiver5, fiver6, fiver7, fiver8, fiver9, fiver10}
weird_colors := []rl.Color{rl.PURPLE, rl.PINK, rl.GREEN, rl.GOLD}

make_piece :: proc(bag: ^Bag) -> (p: Piece) {
  shape := get_shape(bag)
  if conf.weird_shapes do if rand.uint64() % 7 == 0 do shape = .WEIRD
  if shape != .WEIRD {
    p = Piece{shape, traditional_colors[shape], make([dynamic]Point, len(traditional_shapes[shape]))}
    copy(p.segments[:], traditional_shapes[shape][:])
  } else {
    weird_segments := rand.choice(weird_shapes)
    p = Piece{shape, rand.choice(weird_colors), make([dynamic]Point, len(weird_segments))}
    copy(p.segments[:], weird_segments[:])
  }
  offset_piece(&p, {FIELD_WIDTH / 2 - 1, -2})
  return p
}

make_field :: proc(w, h: int) -> Field {
  return Field{w, h, make([dynamic]Tile, w * h)}
}

delete_field :: proc(f: Field) {
  delete(f.data)
}

render_tile :: proc(r: rl.Rectangle, c: rl.Color) {
  dark_color := rl.ColorBrightness(c, -0.3)
  rl.DrawRectangleRec(r, dark_color)
  small_rect := r
  small_rect.x += 5
  small_rect.y += 5
  small_rect.width -= 10
  small_rect.height -= 10
  rl.DrawLineEx({r.x, r.y}, {r.x, r.y} + {r.width, r.height}, 2, c)
  rl.DrawLineEx({r.x + r.width, r.y}, {r.x, r.y} + {0, r.height}, 2, c)
  rl.DrawRectangleRec(small_rect, c)
}

render_field :: proc(f: Field) {
  tile_size := 40
  for i in 0 ..< f.height {
    for j in 0 ..< f.width {
      rect := rl.Rectangle{f32(j * tile_size), f32(i * tile_size), auto_cast tile_size, auto_cast tile_size}
      color := at(f, i, j).color
      render_tile(rect, color)
      rl.DrawRectangleLinesEx(rect, 1, rl.RAYWHITE if at(f, i, j).filled else rl.LIGHTGRAY)
    }
  }
}

render_piece :: proc(p: Piece) {
  tile_size: f32 = 40
  for segment in p.segments {
    rect := rl.Rectangle{f32(segment.x) * tile_size, f32(segment.y) * tile_size, tile_size, tile_size}
    render_tile(rect, p.color)
  }
}

render_preview_piece :: proc(p: Piece) {
  tile_size := 40
  color := p.color
  color.a = 100
  for segment in p.segments do rl.DrawRectangle(i32(segment.x * tile_size), i32(segment.y * tile_size), i32(tile_size), i32(tile_size), color)
}

at_out :: proc(f: Field, row: int, col: int) -> Tile {
  idx := row * f.width + col
  if idx > 0 && idx < len(f.data) do return f.data[row * f.width + col]
  return Tile{}
}
at_in :: proc(f: ^Field, row: int, col: int) -> ^Tile {
  idx := row * f.width + col
  if idx > 0 && idx < len(f.data) do return &f.data[row * f.width + col]
  return nil
}
at :: proc {
  at_out,
  at_in,
}

drop_piece :: proc(p: ^Piece, f: Field) -> (res: bool) {
  old_segments := make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  for &segment in p.segments {
    if segment.y + 1 < FIELD_HEIGHT && !at(f, segment.y + 1, segment.x).filled {
      segment.y += 1
      res = true
    } else {
      res = false
      copy(p.segments[:], old_segments[:])
      break
    }
  }
  return
}

cement_piece :: proc(f: ^Field, p: Piece) {
  for segment in p.segments do if segment.x >= 0 && segment.y >= 0 && segment.x < f.width && segment.y < f.height do at(f, segment.y, segment.x)^ = Tile{true, p.color}
  delete(p.segments)
}

FPS :: 60
FIELD_HEIGHT :: 20
FIELD_WIDTH :: 10

DirRot :: enum {
  LEFT,
  RIGHT,
}

DirRef :: enum {
  HOR,
  VER,
}

shift_piece :: proc(p: ^Piece, d: DirRot, f: Field) {
  old_segments := make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  for &segment in p.segments {
    segment.x += -1 if d == .LEFT else 1
    if conf.modulo {
      if segment.x < 0 do segment.x = f.width + segment.x
      segment.x %= f.width
    }
    if segment.x < 0 || segment.x >= f.width || segment.y >= f.height || (segment.y > 0 && at(f, segment.y, segment.x).filled) {
      copy(p.segments[:], old_segments[:])
      return
    }
  }
}

min_offset :: proc(p: Piece) -> Point {
  min := Point{max(int), max(int)}
  for segment in p.segments {
    if segment.x < min.x do min.x = segment.x
    if segment.y < min.y do min.y = segment.y
  }
  return min
}

max_offset :: proc(p: Piece) -> Point {
  max := Point{min(int), min(int)}
  for segment in p.segments {
    if segment.x > max.x do max.x = segment.x
    if segment.y > max.y do max.y = segment.y
  }
  return max
}

com_offset :: proc(p: Piece) -> Point {
  sum := slice.reduce(p.segments[:], Point{0, 0}, proc(a, b: Point) -> Point {return a + b})
  median: [2]f64 = cast([2]f64)(sum) / f64(len(p.segments))
  return {auto_cast math.round(median.x), auto_cast math.round(median.y)}
}

offset_piece :: proc(p: ^Piece, offset: Point) {
  for &segment in p.segments do segment += offset
}

check_collision :: proc(p: Piece, f: Field) -> bool {
  for segment in p.segments {
    if segment.y < 0 do continue
    if segment.x < 0 || segment.x >= f.width || segment.y >= f.height do return true
    if at(f, segment.y, segment.x).filled do return true
  }
  return false
}

rotate_piece :: proc(p: ^Piece, d: DirRot, f: Field) {
  old_segments := make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  com := com_offset(p^)
  for &segment in p.segments {
    if d == .LEFT {
      segment = (segment - com) * matrix[2, 2]int{
            0, -1,
            1, 0,
          }
    } else {
      segment = (segment - com) * matrix[2, 2]int{
            0, 1,
            -1, 0,
          }
    }
  }
  new_com := com_offset(p^)
  offset_piece(p, -new_com)
  offset_piece(p, com)
  min_o := min_offset(p^)
  max_o := max_offset(p^)
  if min_o.x < 0 do offset_piece(p, {-min_o.x, 0})
  if max_o.x >= f.width do offset_piece(p, {f.width - max_o.x - 1, 0})
  if max_o.y >= f.height do offset_piece(p, {0, f.height - max_o.y - 1})
  if check_collision(p^, f) {
    for x in ([]int{-1, 1, 2, -2}) {
      for y in ([]int{1, 2, -1, -2}) {
        offset_piece(p, {x, y})
        if !check_collision(p^, f) do return
        offset_piece(p, -{x, y})
      }
    }
    if conf.tunnel {
      for x in ([]int{-3, 3, 4, -4, 5, -5}) {
        for y in ([]int{3, 4, 5, -3, -4, -5}) {
          offset_piece(p, {x, y})
          if !check_collision(p^, f) do return
          offset_piece(p, -{x, y})
        }
      }
    }
    copy(p.segments[:], old_segments[:])
  }
}

reflect_piece :: proc(p: ^Piece, d: DirRef, f: Field) {
  old_segments := make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  com := com_offset(p^)
  if d == .HOR {com.y = 0} else {com.x = 0}
  for &segment in p.segments {
    if d == .HOR {
      segment = (segment - com) * matrix[2, 2]int{
            -1, 0,
            0, 1,
          }
    } else {
      segment = (segment - com) * matrix[2, 2]int{
            1, 0,
            0, -1,
          }
    }
  }
  new_com := com_offset(p^)
  if d == .HOR {new_com.y = 0} else {new_com.x = 0}
  offset_piece(p, -new_com)
  offset_piece(p, com)
  min_o := min_offset(p^)
  max_o := max_offset(p^)
  if min_o.x < 0 do offset_piece(p, {-min_o.x, 0})
  if max_o.x >= f.width do offset_piece(p, {f.width - max_o.x - 1, 0})
  if max_o.y >= f.height do offset_piece(p, {0, f.height - max_o.y - 1})
  if check_collision(p^, f) {
    for x in ([]int{-1, 1, 2, -2}) {
      for y in ([]int{1, 2, -1, -2}) {
        offset_piece(p, {x, y})
        if !check_collision(p^, f) do return
        offset_piece(p, -{x, y})
      }
    }
    if conf.tunnel {
      for x in ([]int{-3, 3, 4, -4, 5, -5}) {
        for y in ([]int{3, 4, 5, -3, -4, -5}) {
          offset_piece(p, {x, y})
          if !check_collision(p^, f) do return
          offset_piece(p, -{x, y})
        }
      }
    }
    copy(p.segments[:], old_segments[:])
  }
}

Action :: enum {
  MOVE_LEFT,
  MOVE_RIGHT,
  MOVE_LEFT_CONT,
  MOVE_RIGHT_CONT,
  SOFT_DROP,
  ROT_CW,
  ROT_CCW,
  HARD_DROP,
  POCKET_SWAP,
  PAUSE,
  REFLECT_HOR,
  REFLECT_VER,
}
ActionSet :: bit_set[Action]

handle_input :: proc(p: ^Piece, f: Field) -> (res: ActionSet) {
  if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) do res |= {.MOVE_LEFT}
  if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) do res |= {.MOVE_RIGHT}
  if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) do res |= {.MOVE_LEFT_CONT}
  if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do res |= {.MOVE_RIGHT_CONT}
  if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) do res |= {.SOFT_DROP}
  if rl.IsKeyPressed(.SPACE) do res |= {.HARD_DROP}
  if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) do res |= {.ROT_CCW} if rl.IsKeyDown(.LEFT_SHIFT) else {.ROT_CW}
  if rl.IsKeyPressed(.Q) do res |= {.POCKET_SWAP}
  if rl.IsKeyPressed(.P) do res |= {.PAUSE}
  if rl.IsKeyPressed(.R) do res |= {.REFLECT_VER} if rl.IsKeyDown(.LEFT_SHIFT) else {.REFLECT_HOR}
  return
}

bedris :: proc(f: ^Field) -> int {
  tile_size := 40
  lines := 0
  for i := f.height - 1; i >= 0; i -= 1 {
    if slice.all_of_proc(f.data[i * f.width:][:f.width], proc(v: Tile) -> bool {return v.filled}) {
      if conf.particles do for j in 0 ..< f.width {
        spawn_particle({f32(j * tile_size + tile_size / 2), f32(tile_size * i + tile_size / 2)}, at(f^, i, j).color)
      }
      copy(f.data[f.width:], f.data[:len(f.data) - (f.height - i) * f.width])
      slice.fill(f.data[:f.width], Tile{false, rl.BLANK})
      i += 1
      lines += 1
    }
  }
  return lines
}

render_hud :: proc(s: int, l: int) {
  w := rl.GetScreenWidth()
  text := fmt.ctprintf("SCORE: %v", s)
  text2 := fmt.ctprintf("LEVEL: %v", l)
  tl := rl.MeasureText(text, 20)
  tl2 := rl.MeasureText(text2, 20)
  rl.DrawText(text, w - tl - 10, 10, 20, rl.LIGHTGRAY)
  rl.DrawText(text2, w - tl2 - 10, 40, 20, rl.LIGHTGRAY)
}

render_queue :: proc(qs: [dynamic]Piece, f: Field) {
  tile_size := 40
  small_tile_size := len(qs) > 3 ? tile_size / 2 : tile_size
  width := f.width
  for q, idx in qs do for s in q.segments {
    rect := rl.Rectangle{f32(width * tile_size + s.x * small_tile_size + tile_size / 2), f32(2 * tile_size + s.y * small_tile_size + idx * 4 * small_tile_size), auto_cast small_tile_size, auto_cast small_tile_size}
    render_tile(rect, q.color)
  }
}

render_pocket :: proc(p: Piece, f: Field) {
  pocket := copy_piece(p)
  defer delete(pocket.segments)
  tile_size := 40
  width := f.width
  min_off := min_offset(pocket)
  offset_piece(&pocket, -min_off)
  for s in pocket.segments {
    rect := rl.Rectangle{f32(width * tile_size + s.x * tile_size + tile_size / 2), f32(tile_size + s.y * tile_size + 14 * tile_size), auto_cast tile_size, auto_cast tile_size}
    render_tile(rect, pocket.color)
  }
}

copy_piece :: proc(p: Piece) -> Piece {
  new_p := p
  new_p.segments = make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(new_p.segments[:], p.segments[:])
  return new_p
}

Bag :: struct {
  this_bag: [dynamic]Shape,
  next_bag: [dynamic]Shape,
}

init_bag :: proc() -> (b: Bag) {
  b.this_bag = make([dynamic]Shape, 7)
  b.next_bag = make([dynamic]Shape, 7)
  for &t, idx in b.this_bag do t = Shape(idx % 7)
  for &t, idx in b.next_bag do t = Shape(idx % 7)
  rand.shuffle(b.this_bag[:])
  rand.shuffle(b.next_bag[:])
  return
}

delete_bag :: proc(b: Bag) {
  delete(b.this_bag)
  delete(b.next_bag)
}

get_shape :: proc(b: ^Bag) -> Shape {
  if len(b.this_bag) > 0 {
    return pop(&b.this_bag)
  }
  resize(&b.this_bag, 7)
  copy(b.this_bag[:], b.next_bag[:])
  for &t, idx in b.next_bag do t = Shape(idx)
  rand.shuffle(b.next_bag[:])
  return get_shape(b)
}

get_queue_shape :: proc(b: Bag, i: int) -> Shape {
  if len(b.this_bag) > i {
    return b.this_bag[len(b.this_bag) - 1 - i]
  }
  return b.next_bag[len(b.next_bag) + len(b.this_bag) - 1 - i]
}

generate_garbage :: proc(f: ^Field) {
  copy(f.data[:len(f.data) - f.width], f.data[f.width:])
  for i in 0 ..< f.width {
    at(f, FIELD_HEIGHT - 1, i)^ = Tile{true, rl.BROWN} if rand.uint64() % 2 == 0 else Tile{}
  }
}

Particle :: struct {
  alive: bool,
  pos:   rl.Vector2,
  vel:   rl.Vector2,
  color: rl.Color,
}
particles: [1024]Particle

spawn_particle :: proc(p: rl.Vector2, c: rl.Color) {
  for &particle in particles {
    if !particle.alive {
      particle.alive = true
      particle.pos = p
      particle.vel = {rand.float32_range(-10, 10), -20}
      particle.color = c
      break
    }
  }
}

process_particles :: proc() {
  h := rl.GetScreenHeight()
  for &p in particles {
    if p.alive {
      if p.pos.y > auto_cast h {
        p.alive = false
        continue
      }
      p.pos += p.vel
      p.vel += {0, 1}
    }
  }
}

render_particles :: proc() {
  tile_size := 40
  for p in particles {
    rect := rl.Rectangle{p.pos.x - f32(tile_size / 2), p.pos.y - f32(tile_size / 2), auto_cast tile_size, auto_cast tile_size}
    rl.DrawRectangleRec(rect, p.color)
  }
}


Config :: struct {
  modulo:       bool `usage:"Shift with modulo"`,
  weird_shapes: bool `usage:"Some weird pieces"`,
  speed:        int `usage:"Speed"`,
  tunnel:       bool `usage:"Some insane rotations"`,
  garbage:      bool `usage:"Some garbage"`,
  particles:    bool `usage:"Some particles"`,
  queue:        int `usage:"Queue size"`,
}
conf: Config

main :: proc() {
  when ODIN_DEBUG {
    context.allocator = debug_stuff_init()
    defer debug_stuff_defer()
  }
  flags.parse_or_exit(&conf, os.args[:])
  rl.SetTargetFPS(FPS)
  rl.SetConfigFlags({.WINDOW_RESIZABLE})
  rl.InitWindow(600, 800, "BEDRIS")
  defer rl.CloseWindow()
  bag := init_bag()
  defer delete_bag(bag)
  field := make_field(FIELD_WIDTH, FIELD_HEIGHT)
  defer delete_field(field)
  piece := make_piece(&bag)
  defer delete(piece.segments)
  preview_piece := copy_piece(piece)
  frame_counter := 1
  fast := false
  acceleration := 2
  score := 0
  queue_size := max(1, min(6, conf.queue == 0 ? 3 : conf.queue))
  piece_queue := make([dynamic]Piece, queue_size)
  defer delete(piece_queue)
  pocket := Piece{.SQUARE, rl.GRAY, {}}
  defer delete(pocket.segments)
  for i in 0 ..< queue_size {
    piece_queue[i].shape = get_queue_shape(bag, i)
    piece_queue[i].color = rl.RAYWHITE
    piece_queue[i].segments = make([dynamic]Point, 4)
    copy(piece_queue[i].segments[:], traditional_shapes[piece_queue[i].shape][:])
  }
  defer for i in 0 ..< 3 do delete(piece_queue[i].segments)
  level := 0
  piece_counter := 0
  pause := false
  move_counter := 0
  gravity := 0
  game_over := false
  for !rl.WindowShouldClose() {
    defer free_all(context.temp_allocator)
    defer if !pause {
      frame_counter += 1
      move_counter += 1
    }
    actions := handle_input(&piece, field)
    if .MOVE_LEFT in actions {
      shift_piece(&piece, .LEFT, field)
      move_counter = 0
      frame_counter = 1
    }
    if .MOVE_RIGHT in actions {
      shift_piece(&piece, .RIGHT, field)
      move_counter = 0
      frame_counter = 1
    }
    if .MOVE_LEFT not_in actions && .MOVE_LEFT_CONT in actions do if move_counter > FPS / 3 && frame_counter % 6 == 0 do shift_piece(&piece, .LEFT, field)
    if .MOVE_RIGHT not_in actions && .MOVE_RIGHT_CONT in actions do if move_counter > FPS / 3 && frame_counter % 6 == 0 do shift_piece(&piece, .RIGHT, field)
    if .SOFT_DROP in actions do fast = true
    if .ROT_CCW in actions {
      rotate_piece(&piece, .LEFT, field)
      frame_counter = 1
    }
    if .ROT_CW in actions {
      rotate_piece(&piece, .RIGHT, field)
      frame_counter = 1
    }
    if .REFLECT_HOR in actions {
      reflect_piece(&piece, .HOR, field)
      frame_counter = 1
    }
    if .REFLECT_VER in actions {
      reflect_piece(&piece, .VER, field)
      frame_counter = 1
    }
    if .HARD_DROP in actions {
      for drop_piece(&piece, field) {}
      frame_counter = 1
    }
    if .POCKET_SWAP in actions {
      if pocket.color == rl.GRAY {
        pocket = piece
        piece = make_piece(&bag)
      } else {
        pocket.color, piece.color = piece.color, pocket.color
        pocket.shape, piece.shape = piece.shape, pocket.shape
        slice.swap_between(pocket.segments[:], piece.segments[:])
      }
    }
    if .PAUSE in actions do pause = !pause
    period := FPS - level * (conf.speed + 1) - gravity
    moving_pieces: if frame_counter % period == 0 || (fast && frame_counter % (period / acceleration) == 0) {
      if fast do acceleration = min(acceleration + 1, 15)
      fast = false
      dropped := drop_piece(&piece, field)
      if !dropped {
        gravity = 0
        if slice.all_of_proc(piece.segments[:], proc(p: Point) -> bool {return p.y < 0}) {
          game_over = true
          break moving_pieces
        }
        cement_piece(&field, piece)
        piece = make_piece(&bag)
        piece_counter += 1
        for i in 0 ..< queue_size {
          piece_queue[i].shape = get_queue_shape(bag, i)
          copy(piece_queue[i].segments[:], traditional_shapes[piece_queue[i].shape][:])
        }
        if piece_counter % 10 == 0 {
          level += 1
          if conf.garbage do generate_garbage(&field)
        }
      } else {
        gravity += 1
      }
    }
    if game_over {
      game_over = false
      score = 0
      level = 0
      acceleration = 2
      piece_counter = 0
      frame_counter = 1
      delete_field(field)
      field = make_field(FIELD_WIDTH, FIELD_HEIGHT)
    }
    preview_piece = copy_piece(piece)
    for drop_piece(&preview_piece, field) {}
    lines := bedris(&field)
    if lines > 0 do switch lines {
    case 1: score += 100 * (level + 1)
    case 2: score += 300 * (level + 1)
    case 3: score += 500 * (level + 1)
    case 4: score += 800 * (level + 1)
    }
    if conf.particles do process_particles()
    rl.BeginDrawing()
    rl.ClearBackground(rl.GRAY)
    render_field(field)
    render_piece(piece)
    render_preview_piece(preview_piece)
    render_hud(score, level)
    render_queue(piece_queue, field)
    render_pocket(pocket, field)
    if conf.particles do render_particles()
    if pause {
      w := rl.GetScreenWidth()
      h := rl.GetScreenHeight()
      text := fmt.ctprint("PAUSE")
      l := rl.MeasureText(text, 40)
      rl.DrawText(text, w / 2 - l / 2 - 1, h / 2 - 20 - 1, 40, rl.WHITE)
      rl.DrawText(text, w / 2 - l / 2, h / 2 - 20, 40, rl.BLACK)
    }
    rl.EndDrawing()
  }
}

// TODO: Multiple randomizers
// TODO: Palettes
