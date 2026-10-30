#version 450
layout(push_constant) uniform Push {mat4 modelMatrix;} push;
layout(set=0,binding=0) uniform VertexUniforms {mat4 ViewProj;} uVertex;
layout(location=0) in vec3 position; // @vertex Position required
layout(location=0) out vec4 screen;
void main(){gl_Position=uVertex.ViewProj*push.modelMatrix*vec4(position,1);screen=vec4(gl_Position.xy*.5+gl_Position.ww*.5,gl_Position.zw);}
