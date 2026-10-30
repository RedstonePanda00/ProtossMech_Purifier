#version 450
layout(set=2,binding=0) uniform MaterialUniforms {vec4 _ScreenParams;} uMaterial;
layout(set=2,binding=1) uniform sampler2D _ModelMask;
layout(location=0) in vec4 screen;
layout(location=0) out vec4 outColor;
float coverage(vec2 uv){return texture(_ModelMask,uv).r;}
void main(){vec2 uv=screen.xy/screen.w,pixel=1/uMaterial._ScreenParams.xy;
 float center=coverage(uv),outer=center;
 for(int i=0;i<16;i++){float a=float(i)*6.2831853/16;vec2 offset=vec2(cos(a),sin(a))*pixel;
 outer=max(outer,coverage(uv+offset*2.8));outer=max(outer,coverage(uv+offset*1.4));}
 float alpha=clamp(outer-center,0,1);if(alpha<.005)discard;
 outColor=vec4(.018,.013,.009,alpha);}

