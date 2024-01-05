#version 430

// Output
layout (location = 0) out vec2 textureCoordsOut;

#define BIT(x) x << 1
#define RENDER_OPTION_FLIP_X BIT(0)

struct Transform
{
  vec2 pos;
  vec2 size;
  vec2 atlasOffset;
  vec2 spriteSize;
  vec2 pivotPoint;
  float angle;
  int renderOptions;
};

// Input Buffers
layout(std430, binding = 0) buffer TransformSBO
{
  Transform transforms[];
};

// Input Uniforms
uniform mat4 orthoProjection;

void main()
{
  Transform transform = transforms[gl_InstanceID];

  // Creating Vertices on the GPU (2D Engine)
  // OpenGL Device Coordinates
  // -1 / 1                          1 / 1
  // -1 /-1                          1 /-1
  vec2 vertices[6] =
  {
    transform.pos,                                        // Top Left
    vec2(transform.pos + vec2(0.0, transform.size.y)),    // Bottom Left
    vec2(transform.pos + vec2(transform.size.x, 0.0)),    // Top Right
    vec2(transform.pos + vec2(transform.size.x, 0.0)),    // Top Right
    vec2(transform.pos + vec2(0.0, transform.size.y)),    // Bottom Left
    transform.pos + transform.size                        // Bottom Right
  };

  // Rotation
  {
    float angle = transform.angle;
    vec2 offset = transform.pos + transform.size / 2.0 + transform.pivotPoint;
    
    for (int i = 0; i < 6; i++)
    {
      float newX = (vertices[i].x - offset.x) * cos(angle) - 
      (vertices[i].y - offset.y) * sin(angle);
      
      float newY = (vertices[i].x - offset.x) * sin(angle) + 
      (vertices[i].y - offset.y) * cos(angle);
      
      vertices[i].xy = vec2(newX + offset.x, newY + offset.y);
    }
  }

  float left = transform.atlasOffset.x;
  float top = transform.atlasOffset.y;
  float right = transform.atlasOffset.x + transform.spriteSize.x;
  float bottom = transform.atlasOffset.y + transform.spriteSize.y;

  vec2 textureCoords[6] =
  {
    vec2(left,  top),
    vec2(left,  bottom),
    vec2(right, top),
    vec2(right, top),
    vec2(left,  bottom),
    vec2(right, bottom),
  };

  gl_Position =  orthoProjection * vec4(vertices[gl_VertexID], 1.0, 1.0);
  textureCoordsOut = textureCoords[gl_VertexID];
}