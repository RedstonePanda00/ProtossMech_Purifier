#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(location = 0) in vec3 position; // @vertex Position required
layout(location = 0) out vec3 localPosition;
layout(location = 1) out vec3 worldPosition;
layout(location = 2) out vec3 worldNormal;
void main() {
    vec4 world = push.modelMatrix * vec4(position, 1.0);
    gl_Position = uVertex.ViewProj * world;
    localPosition = position;
    worldPosition = world.xyz;
    // The hemisphere's radial normal is corrected for the dome's nonuniform height.
    worldNormal = normalize(transpose(inverse(mat3(push.modelMatrix))) * position);
}
