#version 450
layout(location = 0) in vec3 inPosition; // @vertex Position required
layout(location = 3) in vec4 inUv0; // @vertex TexCoord0 optional @default = vec4(0.0, 0.0, 0.0, 0.0)
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(location = 0) out vec2 vUv;
void main()
{
    gl_Position = uVertex.ViewProj * push.modelMatrix * vec4(inPosition, 1.0);
    vUv = inUv0.xy;
}
