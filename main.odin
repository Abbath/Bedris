#+feature dynamic-literals
package main

import "core:fmt"
import "core:math/rand"
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

Piece :: struct {
  color:    rl.Color,
  segments: [dynamic]Point,
}

Point :: distinct [2]int

square := []Point{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
line := []Point{{0, 0}, {1, 0}, {2, 0}, {3, 0}}
snake1 := []Point{{0, 0}, {1, 0}, {1, 1}, {2, 1}}
snake2 := []Point{{0, 1}, {1, 1}, {1, 0}, {2, 0}}
lshape1 := []Point{{0, 0}, {1, 0}, {2, 0}, {2, 1}}
lshape2 := []Point{{0, 0}, {1, 0}, {2, 0}, {0, 1}}
tshape := []Point{{0, 0}, {1, 0}, {2, 0}, {1, 1}}
shapes := [][]Point{square, line, snake1, snake2, lshape1, lshape2, tshape}

make_piece :: proc(bag: ^[dynamic][]Point) -> Piece {
  color := rand.choice([]rl.Color{rl.RED, rl.GREEN, rl.BLUE, rl.YELLOW, rl.MAGENTA, rl.ORANGE, rl.LIME, rl.PURPLE, rl.SKYBLUE, rl.VIOLET})
  if len(bag) == 0 {
    delete(bag^)
    bag^ = generate_bag()
  }
  shape := pop(bag)
  p := Piece{color, make([dynamic]Point, len(shape))}
  copy(p.segments[:], shape[:])
  offset_piece(&p, {FIELD_WIDTH / 2 - 1, 0})
  return p
}

make_field :: proc(w, h: int) -> Field {
  return Field{w, h, make([dynamic]Tile, w * h)}
}

delete_field :: proc(f: Field) {
  delete(f.data)
}

render_field :: proc(f: Field) {
  tile_size := 40
  for i in 0 ..< f.height {
    for j in 0 ..< f.width {
      rect := rl.Rectangle{f32(j * tile_size), f32(i * tile_size), auto_cast tile_size, auto_cast tile_size}
      color := f.data[i * f.width + j].color
      rl.DrawRectangleRec(rect, color)
      rl.DrawRectangleLinesEx(rect, 1, rl.LIGHTGRAY)
    }
  }
}

render_piece :: proc(p: Piece) {
  tile_size := 40
  for segment in p.segments do rl.DrawRectangle(i32(segment.x * tile_size), i32(segment.y * tile_size), i32(tile_size), i32(tile_size), p.color)
}

render_preview_piece :: proc(p: Piece) {
  tile_size := 40
  color := p.color
  color.a = 100
  for segment in p.segments do rl.DrawRectangle(i32(segment.x * tile_size), i32(segment.y * tile_size), i32(tile_size), i32(tile_size), color)
}

drop_piece :: proc(p: ^Piece, f: Field) -> (res: bool) {
  old_segments := make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  for &segment in p.segments {
    if segment.y + 1 < FIELD_HEIGHT && !f.data[(segment.y + 1) * f.width + segment.x].filled {
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
  for segment in p.segments do f.data[segment.y * f.width + segment.x] = Tile{true, p.color}
  delete(p.segments)
}

FPS :: 60
FIELD_HEIGHT :: 20
FIELD_WIDTH :: 10

Dir :: enum {
  LEFT,
  RIGHT,
}

shift_piece :: proc(p: ^Piece, d: Dir, f: Field) {
  old_segments := make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  for &segment in p.segments {
    segment.x += -1 if d == .LEFT else 1
    // if segment.x < 0 do segment.x = f.width + segment.x
    // segment.x %= f.width
    if segment.x < 0 || segment.x >= f.width || f.data[segment.y * f.width + segment.x].filled {
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

offset_piece :: proc(p: ^Piece, offset: Point) {
  for &segment in p.segments do segment += offset
}

check_collision :: proc(p: Piece, f: Field) -> bool {
  for segment in p.segments do if f.data[segment.y * f.width + segment.x].filled do return true
  return false
}

rotate_piece :: proc(p: ^Piece, d: Dir, f: Field) {
  old_segments := make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  min := min_offset(p^)
  for &segment in p.segments {
    if d == .LEFT {
      segment = (segment - min) * matrix[2, 2]int{
            0, -1,
            1, 0,
          }
    } else {
      segment = (segment - min) * matrix[2, 2]int{
            0, 1,
            -1, 0,
          }
    }
  }
  new_min_offset := min_offset(p^)
  offset_piece(p, -new_min_offset)
  offset_piece(p, min)
  min_o := min_offset(p^)
  max_o := max_offset(p^)
  if min_o.x < 0 do offset_piece(p, {-min_o.x, 0})
  if max_o.x >= f.width do offset_piece(p, {f.width - max_o.x - 1, 0})
  if max_o.y >= f.height do offset_piece(p, {0, f.height - max_o.y - 1})
  if check_collision(p^, f) {
    for x in -1 ..= 1 {
      for y in -1 ..= 1 {
        if x != 0 && y != 0 {
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
}
ActionSet :: bit_set[Action]

handle_input :: proc(p: ^Piece, f: Field) -> (res: ActionSet) {
  if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) do res |= {.MOVE_LEFT}
  if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) do res |= {.MOVE_RIGHT}
  if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) do res |= {.MOVE_LEFT_CONT}
  if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do res |= {.MOVE_RIGHT_CONT}
  if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) do res |= {.SOFT_DROP}
  if rl.IsKeyPressed(.SPACE) do res |= {.HARD_DROP}
  if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) do res |= {.ROT_CCW} if rl.IsKeyPressed(.LEFT_SHIFT) else {.ROT_CW}
  if rl.IsKeyPressed(.Q) do res |= {.POCKET_SWAP}
  if rl.IsKeyPressed(.P) do res |= {.PAUSE}
  return
}

bedris :: proc(f: ^Field) -> int {
  lines := 0
  for i := f.height - 1; i > 0; i -= 1 {
    if slice.all_of_proc(f.data[i * f.width:][:f.width], proc(v: Tile) -> bool {return v.filled}) {
      copy(f.data[f.width:], f.data[:len(f.data) - (f.height - i) * f.width])
      slice.fill(f.data[:f.width], Tile{false, rl.BLANK})
      i += 1
      lines += 1
    }
  }
  if slice.any_of_proc(f.data[:f.width], proc(v: Tile) -> bool {return v.filled}) do return -1
  return lines
}

render_score :: proc(s: int) {
  w := rl.GetScreenWidth()
  text := fmt.ctprint(s)
  l := rl.MeasureText(text, 20)
  rl.DrawText(text, w - l - 10, 10, 20, rl.LIGHTGRAY)
}

render_queue :: proc(qs: [3]Piece, f: Field) {
  tile_size := 40
  width := f.width
  for q, idx in qs do for s in q.segments do rl.DrawRectangle(i32(width * tile_size + s.x * tile_size + tile_size / 2), i32(tile_size + s.y * tile_size + idx * 4 * tile_size), auto_cast tile_size, auto_cast tile_size, q.color)
}

render_pocket :: proc(p: Piece, f: Field) {
  pocket := copy_piece(p)
  defer delete(pocket.segments)
  tile_size := 40
  width := f.width
  min_off := min_offset(pocket)
  offset_piece(&pocket, -min_off)
  for s in pocket.segments do rl.DrawRectangle(i32(width * tile_size + s.x * tile_size + tile_size / 2), i32(tile_size + s.y * tile_size + 12 * tile_size), auto_cast tile_size, auto_cast tile_size, pocket.color)
}

copy_piece :: proc(p: Piece) -> Piece {
  new_p := p
  new_p.segments = make([dynamic]Point, len(p.segments), context.temp_allocator)
  copy(new_p.segments[:], p.segments[:])
  return new_p
}

generate_bag :: proc() -> [dynamic][]Point {
  bag := make([dynamic][]Point, len(shapes) * 1024)
  for i in 0 ..< 1024 do copy(bag[i * len(shapes):], shapes[:])
  rand.shuffle(bag[:])
  return bag
}

main :: proc() {
  when ODIN_DEBUG {
    context.allocator = debug_stuff_init()
    defer debug_stuff_defer()
  }
  rl.SetTargetFPS(FPS)
  rl.InitWindow(600, 800, "BEDRIS")
  defer rl.CloseWindow()
  bag := generate_bag()
  defer delete(bag)
  field := make_field(FIELD_WIDTH, FIELD_HEIGHT)
  defer delete_field(field)
  piece := make_piece(&bag)
  defer delete(piece.segments)
  preview_piece := copy_piece(piece)
  frame_counter := 1
  fast := false
  acceleration := 2
  score := 0
  piece_queue: [3]Piece
  pocket := Piece{rl.GRAY, {}}
  defer delete(pocket.segments)
  for i in 0 ..< 3 {
    piece_queue[i].color = rl.RAYWHITE
    piece_queue[i].segments = make([dynamic]Point, len(bag[len(bag) - 1 - i]))
    copy(piece_queue[i].segments[:], bag[len(bag) - 1 - i])
  }
  defer for i in 0 ..< 3 do delete(piece_queue[i].segments)
  speed := 0
  piece_counter := 0
  pause := false
  move_counter := 0
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
    }
    if .MOVE_RIGHT in actions {
      shift_piece(&piece, .RIGHT, field)
      move_counter = 0
    }
    if .MOVE_LEFT not_in actions && .MOVE_LEFT_CONT in actions do if move_counter > FPS / 3 && frame_counter % 6 == 0 do shift_piece(&piece, .LEFT, field)
    if .MOVE_RIGHT not_in actions && .MOVE_RIGHT_CONT in actions do if move_counter > FPS / 3 && frame_counter % 6 == 0 do shift_piece(&piece, .RIGHT, field)
    if .SOFT_DROP in actions do fast = true
    if .ROT_CCW in actions do rotate_piece(&piece, .LEFT, field)
    if .ROT_CW in actions do rotate_piece(&piece, .RIGHT, field)
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
        slice.swap_between(pocket.segments[:], piece.segments[:])
      }
    }
    if .PAUSE in actions do pause = !pause
    if frame_counter % (FPS - speed) == 0 || (fast && frame_counter % ((FPS - speed) / acceleration) == 0) {
      if fast do acceleration = min(acceleration + 1, 15)
      fast = false
      dropped := drop_piece(&piece, field)
      if !dropped {
        cement_piece(&field, piece)
        piece = make_piece(&bag)
        piece_counter += 1
        for i in 0 ..< 3 {
          resize(&piece_queue[i].segments, len(bag[len(bag) - 1 - i]))
          copy(piece_queue[i].segments[:], bag[len(bag) - 1 - i])
        }
        if piece_counter % 10 == 0 do speed += 1
      }
    }
    preview_piece = copy_piece(piece)
    for drop_piece(&preview_piece, field) {}
    lines := bedris(&field)
    if lines == -1 {
      score = 0
      speed = 0
      acceleration = 2
      piece_counter = 0
      frame_counter = 1
      delete_field(field)
      field = make_field(FIELD_WIDTH, FIELD_HEIGHT)
    }
    if lines > 0 do score += 10 * lines + (lines - 1) * (lines - 1) * 5
    rl.ClearBackground(rl.GRAY)
    rl.BeginDrawing()
    render_field(field)
    render_piece(piece)
    render_preview_piece(preview_piece)
    render_score(score)
    render_queue(piece_queue, field)
    render_pocket(pocket, field)
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
