// #############################################################################
//                           Render Interface Structs
// #############################################################################
Transform :: struct 
{
  pos : Vector2 = .{0, 0};
  size : Vector2 = .{0, 0};
  atlasOffset : Vector2 = .{0, 0};
  spriteSize : Vector2 = .{0, 0};
};

MAX_TRANSFORMS :: 5000;
transforms : [..] Transform;

// #############################################################################
//                           Render Interface Functions
// #############################################################################
draw_quad :: (transform : *Transform)
{
  // Center Quad
  transform.pos -= transform.size / 2;
  array_add(*transforms, transform);
}

draw_quad :: (pos : Vector2, size : Vector2)
{
  white := get_sprite(.WHITE);

  transform : Transform = .{};
  transform.pos = pos;
  transform.size = size;
  transform.atlasOffset = white.atlasOffset;
  transform.spriteSize = white.size;

  draw_quad(*transform);
}

draw_sprite ::(spriteID : SpriteID, pos : Vector2)
{
  sprite := get_sprite(spriteID);

  transform : Transform = .{};
  transform.pos = pos;
  transform.size = sprite.size;
  transform.atlasOffset = sprite.atlasOffset;
  transform.spriteSize = sprite.size;

  draw_quad(*transform);
}


// #############################################################################
//                           OpenGL Stuff
// #############################################################################
transformSBOID : GLuint = 0;

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

  orthoProjection = orthographic_projection(0.0, 480, -270, 0);
  projectionID := glGetUniformLocation(programID, "orthoProjection");
  glUniformMatrix4fv(projectionID, 1, GL_FALSE, *orthoProjection._11);

  return true;
}

gl_render :: ()
{
  glClearColor(119.0 / 255.0, 33.0 / 255.0, 111.0 / 255.0, 1.0);
  glClearDepth(0.0);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glViewport(0, 0, xx width, xx height);

  // Copy transforms to the GPU
  assert(transforms.count < MAX_TRANSFORMS, "Reached Maximum Transforms");
  glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, size_of(Transform) * transforms.count,
                  transforms.data);

  glDrawArraysInstanced(GL_TRIANGLES, 0, 6, xx transforms.count);
  transforms.count = 0;
  // glDrawArrays(GL_TRIANGLES, 0, 6);
}
