#import "Basic";
#import "Machine_X64";
#import "File";
#import "File_Utilities";
#import "Math";
#import "Random";
#import "Sound_Player";
#import "Thread";
#import "Wav_File";
#import "Window_Creation";
#import "Input"; // update_window_events
#import "GL";
Simp :: #import "Simp"; // ???

// My own includes
#load "gl_renderer.jai";
#load "schnitzel_lib.jai";
#load "assets.jai";

isRunning := true;
is_fullscreened := false;
saved_window_info : Saved_Window_Info;
screenSize : Vector2 = .{1440, 810};
orthoProjection : Matrix4;
TILESIZE :: 8.0;
VIEW_SIZE :: Vector2.{480, 270};
gameTime : float = 0.0;
deltaTime : float = 0.0;
sound_player : *Sound_Player;

main :: () 
{
  window := create_window(cast(int)screenSize.x, cast(int)screenSize.y, "moving_box", 240, 100);
  gameCamera.dimensions = VIEW_SIZE;
  gameCamera.position.x = gameCamera.dimensions.x / 2.0;
  gameCamera.position.y = -gameCamera.dimensions.y / 2.0;

  sound_player = New(Sound_Player);
  sound_player.update_history = true;

  // wglMakeCurrent equivalent
  Simp.set_render_target(window);

  wglSwapIntervalEXT(1);

  seed_world();

  gl_init();

  success := init(sound_player, xx window, true, true);
  // assert(success); // @Incomplete We need an audio pass. Low priority (for now).

  lastTime := get_time();

  while isRunning 
  {
    newTime := get_time();
    deltaTime = cast(float)(newTime - lastTime);
    lastTime = newTime;
    gameTime += deltaTime;

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
            screenSize.x = xx w;
            screenSize.y = xx h;
            toggled_fullscreen = true;
          }
        }
      }
    }
  }

  // Resize events
  for get_window_resizes() 
  {
    screenSize.x = xx it.width;
    screenSize.y = xx it.height;
  }
}

// #############################################################################
//                           Game Constants
// #############################################################################
swingDuration :: 0.2;
healthArray : [] int = .[2, 3, 5];
WORLD_HEIGHT :: 340;
WORLD_WIDTH :: 600;
BASE_HEIGHT :: WORLD_HEIGHT - 20;
WORLD_COLS :: WORLD_WIDTH;
WORLD_ROWS :: WORLD_HEIGHT;

// #############################################################################
//                           Game Structs
// #############################################################################
Tile :: struct
{
  health : int = 0;
  spriteID : SpriteID = .WHITE;
};

GameState :: struct
{
  WORLD_GRID : [WORLD_WIDTH][WORLD_HEIGHT] Tile; // 480 / 8, 272 / 8
  HEIGHT_MAP : [WORLD_WIDTH] int;

  toolbarIdx : int = 0;
  toolbar : [] SpriteID = .[.DIRT, .SAND, .STONE];
};

// #############################################################################
//                           Game Structs
// #############################################################################
Rect :: struct 
{
    x, y: float;
    w, h: float;
}

// #############################################################################
//                           Game Globals/Consts
// #############################################################################
gameState : GameState = .{};
playerPos : Vector2 = .{1000, -40};
swingTimer : float = 0.0;
speed : Vector2 = .{};
remainder : Vector2 = .{};
grounded : bool = false;
gameInitialized : bool = false;
pickaxe_hit:          *Mixer_Sound_Data;

// #############################################################################
//                           Game Functions
// #############################################################################
load_audio_file :: (name : string) -> *Mixer_Sound_Data 
{
  data : *Mixer_Sound_Data = null;

  file_data, success := read_entire_file(name);
  if !success return data;

  has_extension :: (name: string, extension: string) -> bool 
  {
    if name.count < extension.count  return false;
    test := name;
    advance(*test, name.count - extension.count);
    return test == extension;
  }

  if has_extension(name, "wav") 
  {
    data = New(Mixer_Sound_Data);
    data.name = copy_string(name);
    data.buffer = file_data;

    format, samples, success2, extra := get_wav_header(data.buffer);
    if !success2 
    {
      log_error("Unable to parse '%' as wav.\n", data.full_path);
      return data;
    }

    if format.wFormatTag == WAVE_FORMAT_PCM 
    {
      data.type                     = .LINEAR_SAMPLE_ARRAY;
      data.nchannels                = cast(u16) format.nChannels;
      data.nsamples_times_nchannels = samples.count / 2;
    } 
    else if format.wFormatTag == WAVE_FORMAT_DVI_ADPCM 
    {
      data.type             = .ADPCM_COMPRESSED;
      data.wSamplesPerBlock = extra.wSamplesPerBlock;
      data.nBlockAlign      = format.nBlockAlign;

      data.nchannels = cast(u16) format.nChannels;
      // The value in the FACT chunk is number of samples by time.
      data.nsamples_times_nchannels = extra.wSamplesAccordingToFactChunk * data.nchannels;
    } 
    else 
    {
      assert(false);
    }

    data.samples       = cast(*s16) samples.data;
    data.sampling_rate = cast(u32) format.nSamplesPerSec;
  } 
  else if has_extension(name, "ogg") 
  {
    data = New(Mixer_Sound_Data);
    data.name   = copy_string(name);
    data.buffer = file_data;
    data.type   = .OGG_COMPRESSED;
  } 
  else 
  {
      // Unsupported format.
  }

  return data;
}

play_sound :: (data: *Mixer_Sound_Data, perturb: bool = true) -> *Sound_Stream 
{
  stream := make_stream(sound_player, data);

  if stream 
  {
    stream.sound_data = data;
  }

  if perturb && stream 
  {
    stream.user_volume_scale = random_get_within_range(0.7, 1);
    stream.desired_rate = random_get_within_range(0.8, 1.22);
  }

  // @Temporary @Hack! We do not get the duration by default from an ogg file...
  stream.repeat_end_position = cast(int)(data.sampling_rate * 234.475);  

  return stream;
}

//
// Load sound effects
//
load_sound :: (fileName: string) -> *Mixer_Sound_Data 
{
  data := load_audio_file(fileName);

  if !data {
    print("Error: Could not load wav file: %\n", fileName);
    exit(1); // Hard-exit for now.
    return null;
  }

  return data;
}

get_grid_indices :: (worldPos : Vector2) -> int, int
{
  return cast(int)(worldPos.x / TILESIZE), cast(int)(worldPos.y / TILESIZE);
}

seed_world :: ()
{
  SEED = xx rdtsc();

  // Height Map
  for y: 0..(gameState.HEIGHT_MAP.count - 1)
  {
    perlinValue := perlin2d(cast(float)y, cast(float)y, 0.1, 1) * 
                   (gameState.WORLD_GRID[0].count - BASE_HEIGHT);
    gameState.HEIGHT_MAP[y] = cast(int)perlinValue;
  }

  // Initialize Biom
  {
    biomArray : [] SpriteID = .[.SAND, .DIRT, .STONE];
    for y: 0..(gameState.WORLD_GRID[0].count - 1)
    {
      for x: 0..(gameState.WORLD_GRID.count - 1)
      {
        if y < gameState.HEIGHT_MAP[x]
        {
          gameState.WORLD_GRID[x][y].health = 0;
        }
        else
        {
          perlinValue := perlin2d(cast(float)x, cast(float)y, 0.1, 1) * biomArray.count;

          gameState.WORLD_GRID[x][y].health = healthArray[cast(int)perlinValue];
          gameState.WORLD_GRID[x][y].spriteID = biomArray[cast(int)perlinValue];
        }
      }
    }
  }
}

approach :: (current : float, target : float, increase : float) -> float
{
  if current < target
  {
    return min(current + increase, target);
  }

  return max(current - increase, target);
}

fraction :: (value : float) -> float
{
  if value > -1.0 && value < 1.0
  {
    return value;
  }

  if value < -1.0
  {
    return value + cast(int)value;
  }
  return value - cast(int)value;
}

round :: (value : float) -> float
{
  if value > 0
  {
    return floor(value + 0.5);
  }
  else
  {
    return ceil(value - 0.5);
  }
}

sign :: (value : float) -> float
{
  if value < 0
  {
    return -1;
  }
  return 1;
}

get_player_rect :: () -> Rect
{
  playerRect : Rect = .{};

  playerRect.x = playerPos.x - 6;
  playerRect.y = playerPos.y - 12;
  playerRect.w = 12;
  playerRect.h = 28;

  return playerRect;
}

get_tile_pos :: (gridPos : Vector2) -> Vector2
{
  return .{gridPos.x * TILESIZE + TILESIZE / 2,
           gridPos.y * TILESIZE + TILESIZE / 2};
}

get_tile_rect :: (gridPos : Vector2) -> Rect
{
  tilePos := get_tile_pos(gridPos);

  tileRect : Rect = .{};

  tileRect.x = tilePos.x - 4;
  tileRect.y = tilePos.y - 4;
  tileRect.w = 8;
  tileRect.h = 8;

  return tileRect;
}

get_tile :: (gridPos : Vector2) -> *Tile
{
  if gridPos.x >= WORLD_COLS || gridPos.x < 0 ||
     gridPos.y >= WORLD_ROWS || gridPos.y < 0
  {
    return null;
  }

  return *gameState.WORLD_GRID[cast(int)gridPos.x][cast(int)gridPos.y];
}

rect_collision :: (a : Rect, b : Rect) -> bool
{
  return a.x < b.x + b.w && // Collision on Left of a and right of b
         a.x + a.w > b.x && // Collision on Right of a and left of b
         a.y < b.y + b.h && // Collision on Bottom of a and Top of b
         a.y + a.h > b.y;   // Collision on Top of a and Bottom of b
}

update_sound_player :: (dt: float) 
{
    //
    // Move sound streams forward by dt.
    //
    lock(*sound_player.sound_mutex);
    defer unlock(*sound_player.sound_mutex);

    pre_entity_update(sound_player);

    //
    // @Incomplete We're not removing sound streams once they're consumed.
    //
    for sound_player.streams {
        it.marked = true;
    }

    post_entity_update(sound_player, dt);
}

update_game :: ()
{ 
  if !gameInitialized
  {
    pickaxe_hit          = load_sound("assets/sounds/button_mono.wav");
    gameInitialized = true;
  }

  update_sound_player(deltaTime);

  runAcceleration :: 12.0;
  runSpeed :: 2.0;
  friction :: 10.0;
  jumpSpeed :: -7.0;

  // Moving the Player
  {
    if input_button_states[#char "D"] & Key_Current_State.DOWN
    {
      mult := 1.0;
      if speed.x < 0.0
      {
        mult = 3.0;
      }

      speed.x = approach(speed.x, runSpeed, runAcceleration * mult * deltaTime);
    }

    if input_button_states[#char "A"] & Key_Current_State.DOWN
    {
      mult := 1.0;
      if speed.x > 0.0
      {
        mult = 3.0;
      }

      speed.x = approach(speed.x, -runSpeed, runAcceleration * mult * deltaTime);
    }

    // Friction
    if !(input_button_states[#char "D"] & Key_Current_State.DOWN) &&
       !(input_button_states[#char "A"] & Key_Current_State.DOWN)
    {
      speed.x = approach(speed.x, 0, friction * deltaTime);
    }

    // Jumping
    if input_button_states[Key_Code.SPACEBAR] & Key_Current_State.START
       && grounded
    {
      speed.y = jumpSpeed;
      grounded = false;
    }

    // Gravity
    {
      gravity :: 40.0;
      fallSpeed :: 5.0;
      speed.y = approach(speed.y, fallSpeed, gravity * deltaTime);
    }

    // Move X
    {
      remainder.x += speed.x;
      moveX := cast(int)round(remainder.x);
      if moveX != 0
      {
        remainder.x -= moveX;
        moveSign := cast(int)sign(cast(float)moveX);
        collisionHappened := false;

        while move_loop := moveX
        {
          playerRect := get_player_rect();
          playerRect.x += moveSign;

          gridX, gridY := get_grid_indices(playerPos);
          for y: (gridY - 3).. (gridY + 3)
          {
            for x: (gridX - 2).. (gridX + 2)
            {
              tile := get_tile(.{cast(float)x, cast(float)y});

              if !tile || tile.health <= 0
                continue;

              tileRect := get_tile_rect(.{cast(float)x, cast(float)y});

              if rect_collision(playerRect, tileRect)
              {
                speed.x = 0.0;
                break move_loop;
              }
            }
          }

          moveX -= moveSign;
          playerPos.x += moveSign;
        }
      }
    }

    // Move Y
    {
      remainder.y += speed.y;
      moveY := cast(int)round(remainder.y);
      if moveY != 0
      {
        remainder.y -= moveY;
        moveSign := cast(int)sign(cast(float)moveY);
        collisionHappened := false;

        while move_loop := moveY
        {
          playerRect := get_player_rect();
          playerRect.y += moveSign;

          gridX, gridY := get_grid_indices(playerPos);
          for y: (gridY - 3).. (gridY + 3)
          {
            for x: (gridX - 2).. (gridX + 2)
            {
              tile := get_tile(.{cast(float)x, cast(float)y});

              if !tile || tile.health <= 0
                continue;

              tileRect := get_tile_rect(.{cast(float)x, cast(float)y});

              if rect_collision(playerRect, tileRect)
              {
                if speed.y > 0.0
                {
                  grounded = true;
                }

                speed.y = 0.0;
                break move_loop;
              }
            }
          }

          moveY -= moveSign;
          playerPos.y += moveSign;
        }
      }
    }
  }

  if input_button_states[#char "1"] & Key_Current_State.START
  {
    gameState.toolbarIdx = 0;
  }
  if input_button_states[#char "2"] & Key_Current_State.START
  {
    gameState.toolbarIdx = 1;
  }
  if input_button_states[#char "3"] & Key_Current_State.START
  {
    gameState.toolbarIdx = 2;
  }

  swingTimer = max(0.0, swingTimer - deltaTime);
  if input_button_states[Key_Code.MOUSE_BUTTON_LEFT] & Key_Current_State.DOWN
  {
    if swingTimer == 0.0
    {
      swingTimer = swingDuration;

      play_sound(pickaxe_hit);

      mousePos := mouse_pos_world();
      mouseX, mouseY := get_grid_indices(mousePos);
      playerX, playerY := get_grid_indices(playerPos);

      tile := *gameState.WORLD_GRID[mouseX][mouseY];

      if abs(playerX - mouseX) < 4 && abs(playerY - mouseY) < 5
      {
        tile.health -= 1;
      }
    }
  }

  if input_button_states[Key_Code.MOUSE_BUTTON_RIGHT] & Key_Current_State.DOWN
  {
    mousePos := mouse_pos_world();
    x, y := get_grid_indices(mousePos);

    if gameState.WORLD_GRID[x][y].health <= 0
    {
      gameState.WORLD_GRID[x][y].spriteID = gameState.toolbar[gameState.toolbarIdx];
      gameState.WORLD_GRID[x][y].health = healthArray[gameState.toolbarIdx];
    }
  }

  // Draw Grid
  {
    for y: 0..(gameState.WORLD_GRID[0].count - 1)
    {
      for x: 0..(gameState.WORLD_GRID.count - 1)
      {
        if gameState.WORLD_GRID[x][y].health <= 0
          continue;

        // WORLD_GRID[x][y] = biomArray[idx];
        pos : Vector2 = .{cast(float) (x * TILESIZE + TILESIZE / 2), 
                          cast(float) (y * TILESIZE + TILESIZE / 2)};

        if gameState.WORLD_GRID[x][y].health == 1
        {
          draw_sprite(.BROKEN, pos);
        }


        draw_sprite(gameState.WORLD_GRID[x][y].spriteID, pos);
      }
    }
  }

  
// draw_sprite :: (spriteID : SpriteID, pos : Vector2, drawData : DrawData = .{})
  if swingTimer > 0.0
  {
    draw_sprite(.PICKAXE, playerPos + .{-12, -12}, .{-5 - 3* (1.0 - (swingTimer / swingDuration)), .{12.0, 12.0}, 0});
  }

  // gameCamera.position = playerPos + WORLD_SIZE / 2;
  gameCamera.position.x = playerPos.x;
  gameCamera.position.y = -playerPos.y;
  draw_sprite(.SKELETON, playerPos);
  
  playerRect := get_player_rect();
  // draw_quad(.{playerRect.x + playerRect.w / 2, playerRect.y + playerRect.h / 2}, 
  //           .{playerRect.w, playerRect.h});
}



