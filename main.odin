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
  segments: [dynamic][2]int,
}

square := [][2]int{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
line := [][2]int{{0, 0}, {1, 0}, {2, 0}, {3, 0}}
snake1 := [][2]int{{0, 0}, {1, 0}, {1, 1}, {2, 1}}
snake2 := [][2]int{{0, 1}, {1, 1}, {1, 0}, {2, 0}}
lshape1 := [][2]int{{0, 0}, {1, 0}, {2, 0}, {2, 1}}
lshape2 := [][2]int{{0, 0}, {1, 0}, {2, 0}, {0, 1}}
tshape := [][2]int{{0, 0}, {1, 0}, {2, 0}, {1, 1}}

make_piece :: proc() -> Piece {
  color := rand.choice([]rl.Color{rl.RED, rl.GREEN, rl.BLUE, rl.YELLOW, rl.MAGENTA})
  shape := rand.choice([][][2]int{square, line, snake1, snake2, lshape1, lshape2, tshape})
  p := Piece{color, make([dynamic][2]int, len(shape))}
  copy(p.segments[:], shape[:])
  return p
}

make_field :: proc(w, h: int) -> Field {
  return Field{w, h, make([dynamic]Tile, w * h)}
}

render_field :: proc(f: Field) {
  tile_size := 40
  for i in 0 ..< f.height {
    for j in 0 ..< f.width {
      rect := rl.Rectangle{f32(j * tile_size), f32(i * tile_size), auto_cast tile_size, auto_cast tile_size}
      color := f.data[i * f.width + j].color
      rl.DrawRectangleRec(rect, color)
      rl.DrawRectangleLinesEx(rect, 2, rl.LIGHTGRAY)
    }
  }
}

render_piece :: proc(p: Piece) {
  tile_size := 40
  for segment in p.segments {
    rl.DrawRectangle(i32(segment.x * tile_size), i32(segment.y * tile_size), i32(tile_size), i32(tile_size), p.color)
  }
}

render_preview_piece :: proc(p: Piece) {
  tile_size := 40
  color := p.color
  color.a = 100
  for segment in p.segments {
    rl.DrawRectangle(i32(segment.x * tile_size), i32(segment.y * tile_size), i32(tile_size), i32(tile_size), color)
  }
}

drop_piece :: proc(p: ^Piece, f: Field) -> (res: bool) {
  old_segments := make([dynamic][2]int, len(p.segments), context.temp_allocator)
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
  for segment in p.segments {
    f.data[segment.y * f.width + segment.x] = Tile{true, p.color}
  }
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
  old_segments := make([dynamic][2]int, len(p.segments), context.temp_allocator)
  copy(old_segments[:], p.segments[:])
  for &segment in p.segments {
    if d == .LEFT {
      segment.x -= 1
    } else {
      segment.x += 1
    }
    // if segment.x < 0 do segment.x = f.width + segment.x
    // segment.x %= f.width
    if segment.x < 0 || segment.x >= f.width || f.data[segment.y * f.width + segment.x].filled {
      fmt.eprintln("TOO FAR")
      copy(p.segments[:], old_segments[:])
      return
    }
  }
}

min_offset :: proc(p: Piece) -> [2]int {
  min := [2]int{max(int), max(int)}
  for segment in p.segments {
    if segment.x < min.x do min.x = segment.x
    if segment.y < min.y do min.y = segment.y
  }
  return min
}

max_offset :: proc(p: Piece) -> [2]int {
  max := [2]int{min(int), min(int)}
  for segment in p.segments {
    if segment.x > max.x do max.x = segment.x
    if segment.y > max.y do max.y = segment.y
  }
  return max
}

offset_piece :: proc(p: ^Piece, offset: [2]int) {
  for &segment in p.segments do segment += offset
}

rotate_piece :: proc(p: ^Piece, d: Dir, f: Field) {
  old_segments := make([dynamic][2]int, len(p.segments), context.temp_allocator)
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
    // if segment.x < 0 do segment.x = f.width + segment.x
    // segment.x %= f.width
    // if segment.x < 0 || segment.x >= f.width || segment.y >= f.height {
    //   fmt.eprintln("ROTATED WRONG")
    //   copy(p.segments[:], old_segments[:])
    //   return
    // }
  }
  new_min_offset := min_offset(p^)
  offset_piece(p, -new_min_offset)
  offset_piece(p, min)
  min_o := min_offset(p^)
  max_o := max_offset(p^)
  if min_o.x < 0 {
    offset_piece(p, {-min_o.x, 0})
  }
  if max_o.x >= f.width {
    offset_piece(p, {f.width - max_o.x - 1, 0})
  }
}

Action :: enum {
  SOFT_DROP,
  ROT_CW,
  ROT_CC,
  HARD_DROP,
}
ActionSet :: bit_set[Action]

handle_input :: proc(p: ^Piece, f: Field) -> (res: ActionSet) {
  if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) do shift_piece(p, .LEFT, f)
  if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) do shift_piece(p, .RIGHT, f)
  if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) do res |= {.SOFT_DROP}
  if rl.IsKeyPressed(.SPACE) do res |= {.HARD_DROP}
  if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) do res |= {.ROT_CC} if rl.IsKeyPressed(.LEFT_SHIFT) else {.ROT_CW}
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

copy_piece :: proc(p: Piece) -> Piece {
  new_p := p
  new_p.segments = make([dynamic][2]int, len(p.segments))
  copy(new_p.segments[:], p.segments[:])
  return new_p
}

main :: proc() {
  when ODIN_DEBUG {
    context = debug_stuff_init()
    defer debug_stuff_defer()
  }
  fmt.println("FUCK")
  rl.SetTargetFPS(FPS)
  rl.InitWindow(600, 800, "BEDRIS")
  defer rl.CloseWindow()
  field := make_field(FIELD_WIDTH, FIELD_HEIGHT)
  piece := make_piece()
  preview_piece := copy_piece(piece)
  frame_counter := 0
  speed := false
  acceleration := 2
  score := 0
  for !rl.WindowShouldClose() {
    defer free_all(context.temp_allocator)
    defer frame_counter += 1
    actions := handle_input(&piece, field)
    if .SOFT_DROP in actions {
      speed = true
    }
    if .ROT_CC in actions {
      rotate_piece(&piece, .LEFT, field)
    }
    if .ROT_CW in actions {
      rotate_piece(&piece, .RIGHT, field)
    }
    if .HARD_DROP in actions {
      for drop_piece(&piece, field) {}
      frame_counter = 1
    }
    if frame_counter % FPS == 0 || (speed && frame_counter % (FPS / acceleration) == 0) {
      if speed do acceleration = min(acceleration + 1, 10)
      speed = false
      dropped := drop_piece(&piece, field)
      if !dropped {
        cement_piece(&field, piece)
        piece = make_piece()
      }
    }
    preview_piece = copy_piece(piece)
    for drop_piece(&preview_piece, field) {}
    lines := bedris(&field)
    if lines == -1 {
      score = 0
      field = make_field(FIELD_WIDTH, FIELD_HEIGHT)
    }
    if lines > 0 do score += 10 * lines + (lines - 1) * (lines - 1) * 5
    rl.ClearBackground(rl.GRAY)
    rl.BeginDrawing()
    render_field(field)
    render_piece(piece)
    render_preview_piece(preview_piece)
    render_score(score)
    rl.EndDrawing()
  }
}
