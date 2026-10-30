#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set=0,binding=0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set=2,binding=0) uniform MaterialUniforms {
 vec4 _Tint; // @default = vec4(1, 0.7, 0.1, 1)
 vec4 _PixelOffset;
 float _Phase;
 float _Charged;
} uMaterial;
layout(location=0) in vec3 position; // @vertex Position required
layout(location=1) in vec3 normal; // @vertex Normal required
layout(location=3) in vec2 uv; // @vertex TexCoord0 required
layout(location=0) out vec2 texUV;
layout(location=1) out vec3 worldNormal;
void main(){
 gl_Position=uVertex.ViewProj*push.modelMatrix*vec4(position,1);
 gl_Position.xy+=uMaterial._PixelOffset.xy*2.0*gl_Position.w;
 texUV=uv; worldNormal=normalize(mat3(push.modelMatrix)*normal);
}

