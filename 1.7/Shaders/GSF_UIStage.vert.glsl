#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } camera;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _Accent; // @default = vec4(0.72, 0.78, 0.40, 1.0)
    vec4 _Viewport; // @default = vec4(1440.0, 1040.0, 0.0, 0.0)
    vec4 _Interaction; // @default = vec4(1.0, 1.0, 0.0, 0.0)
} material;
layout(set = 2, binding = 1) uniform sampler2D _MainTex;
layout(set = 2, binding = 2) uniform sampler2D _PreviousTex;
layout(location = 0) in vec3 position; // @vertex Position required
layout(location = 3) in vec2 uv; // @vertex TexCoord0 optional @default = vec4(0.0)
// Waylith's IMGUI material pass uses the GUI vertex interface: color=0, UV=1.
layout(location = 1) out vec2 texcoord;
void main() {
    gl_Position = camera.ViewProj * push.modelMatrix * vec4(position, 1.0);
    texcoord = uv;
}
