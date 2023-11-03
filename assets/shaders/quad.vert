#version 430


// Output
layout (location = 0) out vec2 textureCoordsOut;

struct Transform
{
  vec2 pos;
  vec2 size;
  vec2 atlasOffset;
  vec2 spriteSize;
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