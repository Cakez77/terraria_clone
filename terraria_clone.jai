#import "Basic";
#import "Machine_X64";
#import "File";
#import "Math";
#import "Random";
#import "Window_Creation";

// update_window_events
#import "Input";

#import "GL";
Simp :: #import "Simp"; // ???
#load "gl_renderer.jai";
#load "schnitzel_lib.jai";

isRunning := true;
is_fullscreened := false;
saved_window_info : Saved_Window_Info;
width : s32 = 1440;
height : s32 = 810;
orthoProjection : Matrix4;
TILESIZE :: 8;
WORLD_SIZE :: Vector2.{480, 270};
WORLD_ROWS :: 480 / 8;
WORLD_COLS :: 272 / 8;
boxPos : Vector2 = .{100, 100};

main :: () 
{
  window := create_window(width, height, "moving_box", 240, 100);
  // wglMakeCurrent equivalent
  Simp.set_render_target(window);

  wglSwapIntervalEXT(1);

  seed_world();

  gl_init();

  while isRunning 
  {
    update_window(window);
    update_game();
    gl_render();
    Simp.swap_buffers(window);
  }
}

update_window :: (window: $T)
{
  toggled_fullscreen := false;
  update_window_events();

  // Keyboard events
  for event: events_this_frame
  {
    if event.type == 
    {
      case .QUIT; isRunning = false;
      case .KEYBOARD;
      if event.key_pressed if event.key_code == 
      {
        case #char "R";
          seed_world();
          
        case .ESCAPE; isRunning = false;
        case .F11;
        if !toggled_fullscreen 
        {
          is_fullscreened = !is_fullscreened;
          success, w, h := 
            toggle_fullscreen(window, is_fullscreened, *saved_window_info);
          if success 
          {
            width = w;
            height = h;
            toggled_fullscreen = true;
          }
        }
      }
    }
  }

  // Resize events
  for get_window_resizes() 
  {
    width = it.width;
    height = it.height;
  }
}


// #############################################################################
//                           Game Structs
// #############################################################################
SpriteID :: enum 
{
  WHITE;
  SKELETON;
  DIRT;
  DIRT_TOP;
  SAND;
  SAND_TOP;
  STONE;
  STONE_TOP;
};

Sprite :: struct
{
  atlasOffset : Vector2;
  size : Vector2;
};

get_sprite :: (spriteID : SpriteID) -> Sprite
{
  sprite : Sprite = .{};

  if spriteID ==
  {
    case .WHITE;
      sprite.atlasOffset = .{0, 0};
      sprite.size = .{1, 1};

    case .SKELETON;
      sprite.atlasOffset = .{0, 16};
      sprite.size = .{32, 32};

    case .DIRT;
      sprite.atlasOffset = .{32, 8};
      sprite.size = .{8, 8};

    case .DIRT_TOP;
      sprite.atlasOffset = .{32, 0};
      sprite.size = .{8, 8};

    case .SAND;
      sprite.atlasOffset = .{40, 8};
      sprite.size = .{8, 8};

    case .SAND_TOP;
      sprite.atlasOffset = .{40, 0};
      sprite.size = .{8, 8};

    case .STONE;
      sprite.atlasOffset = .{48, 8};
      sprite.size = .{8, 8};

    case .STONE_TOP;
      sprite.atlasOffset = .{48, 0};
      sprite.size = .{8, 8};
  }

  return sprite;
}

// #############################################################################
//                           Game Globals
// #############################################################################
WORLD_GRID : [60][34] SpriteID; // 480 / 8, 272 / 8
HEIGHT_MAP : [60] int;
BASE_HEIGHT :: 10;

// #############################################################################
//                           Game Functions
// #############################################################################
seed_world :: ()
{
  SEED = xx rdtsc();

  // Height Map
  for y: 0..(HEIGHT_MAP.count - 1)
  {
    perlinValue := perlin2d(cast(float)y, cast(float)y, 0.1, 1) * (WORLD_GRID[0].count - BASE_HEIGHT);
    HEIGHT_MAP[y] = BASE_HEIGHT + cast(int)perlinValue;
  }

  // Initialize Biom
  {
    biomArray : [] SpriteID = .[.SAND, .DIRT, .STONE];
    for y: 0..(WORLD_GRID[0].count - 1)
    {
      for x: 0..(WORLD_GRID.count - 1)
      {
        if y < HEIGHT_MAP[x]
        {
          WORLD_GRID[x][y] = .WHITE;
        }
        else
        {
          perlinValue := perlin2d(cast(float)x, cast(float)y, 0.1, 1) * biomArray.count;
          print("% \n", perlinValue);
          WORLD_GRID[x][y] = biomArray[cast(int)perlinValue];
        }
      }
    }
  }

}

update_game :: ()  
{
  if input_button_states[#char "W"] & Key_Current_State.DOWN
  {
    boxPos.y -= 1;
  }
  if input_button_states[#char "A"] & Key_Current_State.DOWN
  {
    boxPos.x -= 1;
  }
  if input_button_states[#char "S"] & Key_Current_State.DOWN
  {
    boxPos.y += 1;
  }
  if input_button_states[#char "D"] & Key_Current_State.DOWN
  {
    boxPos.x += 1;
  }

  // Draw Grid
  {
    for y: 0..(WORLD_GRID[0].count - 1)
    {
      for x: 0..(WORLD_GRID.count - 1)
      {
        if WORLD_GRID[x][y] == .WHITE
          continue;

        // WORLD_GRID[x][y] = biomArray[idx];
        pos : Vector2 = .{cast(float) (x * TILESIZE + TILESIZE / 2), 
                          cast(float) (y * TILESIZE + TILESIZE / 2)};

        draw_sprite(WORLD_GRID[x][y], pos);
      }
    }

  }

  draw_sprite(.SKELETON, boxPos);
}





