// #############################################################################
//                           Render Interface Structs
// #############################################################################
Transform :: struct 
{
  pos : Vector2 = .{0, 0};
  size : Vector2 = .{0, 0};
  atlasOffset : Vector2 = .{0, 0};
  spriteSize : Vector2 = .{0, 0};
  pivotPoint : Vector2 = .{0, 0};
  angle : float = 0.0;
  padding : float;
};

Camera2D :: struct
{
  zoom : float;
  dimensions : Vector2;
  position : Vector2;
};

DrawData :: struct
{
  angle : float;
  pivotPoint : Vector2;
  renderOptions : int;
};

// #############################################################################
//                           Render Interface Globals
// #############################################################################
MAX_TRANSFORMS :: 5000;
transforms : [..] Transform;
gameCamera : Camera2D;

// #############################################################################
//                           Render Interface Utility
// #############################################################################
mouse_pos_world :: () -> Vector2
{
  x, y, success := get_mouse_pointer_position();
  screenPos : Vector2 = .{xx x, xx y};

  // Offset using dimensions and position
  xPos : float = screenPos.x / screenSize.x * gameCamera.dimensions.x; // [0; dimensions.x]
  xPos += -gameCamera.dimensions.x / 2.0 + gameCamera.position.x;

  // Offset using dimensions and position
  yPos : float = screenPos.y / screenSize.y * gameCamera.dimensions.y; // [0; dimensions.y]
  yPos += -gameCamera.dimensions.y / 2.0 - gameCamera.position.y;

  return .{xPos, yPos};
}

// #############################################################################
//                           Render Interface Functions
// #############################################################################
draw_quad :: (transform : *Transform)
{
  // GameCamera Rect
  rect : Rect = .{
    gameCamera.position.x - gameCamera.dimensions.x / 2 - 10,
    -gameCamera.position.y - gameCamera.dimensions.y / 2 - 10,
    gameCamera.dimensions.x + 20,
    gameCamera.dimensions.y + 20,
  };

  if !point_in_rect(transform.pos, rect)
    return;

  // Center Quad
  transform.pos -= transform.size / 2;


  array_add(*transforms, transform);
}

draw_quad :: (pos : Vector2, size : Vector2, drawData : DrawData = .{})
{
  white := get_sprite(.WHITE);

  transform : Transform = .{};
  transform.pos = pos;
  transform.size = size;
  transform.atlasOffset = white.atlasOffset;
  transform.spriteSize = white.size;
  transform.angle = drawData.angle;
  transform.pivotPoint = drawData.pivotPoint;

  draw_quad(*transform);
}

draw_sprite :: (spriteID : SpriteID, pos : Vector2, drawData : DrawData = .{})
{
  sprite := get_sprite(spriteID);

  transform : Transform = .{};
  transform.pos = pos;
  transform.size = sprite.size;
  transform.atlasOffset = sprite.atlasOffset;
  transform.spriteSize = sprite.size;
  transform.angle = drawData.angle;
  transform.pivotPoint = drawData.pivotPoint;

  draw_quad(*transform);
}

// #############################################################################
//                           OpenGL Stuff
// #############################################################################
transformSBOID : GLuint = 0;
projectionID : GLint = 0;

gl_create_shader :: (shaderType : GLuint, shaderPath : string) -> GLuint
{
	file, success := read_entire_file(shaderPath);
  if !success
  {
    log_error("Unable to read shader file '%'! \n", shaderPath);
    return 0;
  }

  shaderID : GLuint = glCreateShader(shaderType);
  glShaderSource(shaderID, 1, *file.data, null);
  glCompileShader(shaderID);

  // Test if Shader compiled successfully 
  {
    success : s32;
    glGetShaderiv (shaderID, GL_COMPILE_STATUS, *success);

    if !success 
    {
      info_len : s32;
      glGetShaderiv (shaderID, GL_INFO_LOG_LENGTH, *info_len);
      info_data := cast (*u8) alloc (info_len, temp);
      glGetShaderInfoLog (shaderID, xx info_len, xx *info_len, info_data);
      result : string;
      result.data = info_data;
      result.count = info_len;

      print(result);

      return 0;
    }
  }

  return shaderID;
}

gl_init :: () -> bool
{
  vertShaderID := gl_create_shader(GL_VERTEX_SHADER, "assets/shaders/quad.vert");
  fragShaderID := gl_create_shader(GL_FRAGMENT_SHADER, "assets/shaders/quad.frag");

  programID := glCreateProgram();
  glAttachShader(programID, vertShaderID);
  glAttachShader(programID, fragShaderID);
  glLinkProgram(programID);
  glUseProgram(programID);

  // This is preemtively, because they are still bound
  // They are already marked for deletion tho
  glDetachShader(programID, vertShaderID);
  glDetachShader(programID, fragShaderID);
  glDeleteShader(vertShaderID);
  glDeleteShader(fragShaderID);

  // Transform Storage Buffer
  {
    glGenBuffers(1, *transformSBOID);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, transformSBOID);
    glBufferData(GL_SHADER_STORAGE_BUFFER, size_of(Transform) * MAX_TRANSFORMS,
                 transforms.data, GL_DYNAMIC_DRAW);
  }

  // Texture Loading
  {
    texture: Simp.Texture;
    tetxureID : GLuint;
    success := Simp.texture_load_from_file(*texture, "assets/textures/terraria_atlas.png");
  }

  // This needs to be bound, otherwise OpenGL doesn't draw anything
  // We won't use it tho!
  VAO : GLuint = 0;
  glGenVertexArrays(1, *VAO);
  glBindVertexArray(VAO);

  // Depth Tesing
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_GREATER);

  // sRGB output (even if input texture is non-sRGB -> don't rely on texture used)
  // Your font is not using sRGB, for example (not that it matters there, because no actual color is sampled from it)
  // But this could prevent some future bug when you start mixing different types of textures
  // Of course, you still need to correctly set the image file source format when using glTexImage2D()
  // glEnable(GL_FRAMEBUFFER_SRGB);
  glDisable(GL_MULTISAMPLE); // disable multisampling

  projectionID = glGetUniformLocation(programID, "orthoProjection");

  return true;
}

gl_render :: ()
{
  orthoProjection = orthographic_projection(
    gameCamera.position.x - gameCamera.dimensions.x / 2.0, 
    gameCamera.position.x + gameCamera.dimensions.x / 2.0, 
    gameCamera.position.y - gameCamera.dimensions.y / 2.0, 
    gameCamera.position.y + gameCamera.dimensions.y / 2.0);
  glUniformMatrix4fv(projectionID, 1, GL_FALSE, *orthoProjection._11);

  glClearColor(79.0 / 255.0, 140.0 / 255.0, 235.0 / 255.0, 1.0);
  glClearDepth(0.0);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glViewport(0, 0, xx screenSize.x, xx screenSize.y);

  // Copy transforms to the GPU
  assert(transforms.count < MAX_TRANSFORMS, "Reached Maximum Transforms");
  glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, size_of(Transform) * transforms.count,
                  transforms.data);

  glDrawArraysInstanced(GL_TRIANGLES, 0, 6, xx transforms.count);
  transforms.count = 0;
  // glDrawArrays(GL_TRIANGLES, 0, 6);
}
