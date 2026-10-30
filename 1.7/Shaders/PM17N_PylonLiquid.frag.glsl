#version 450
layout(set=2,binding=0) uniform MaterialUniforms {
 vec4 _Tint; // @default = vec4(1, 0.7, 0.1, 1)
 vec4 _PixelOffset;
 float _Phase;
 float _Charged;
} uMaterial;
layout(location=0) in vec2 texUV;
layout(location=1) in vec3 worldNormal;
layout(location=0) out vec4 outColor;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1),f.x),f.y);}
void main(){
 vec2 p=texUV;float t=uMaterial._Phase;
 vec2 flow=vec2(noise(p*5+vec2(t*.18,-t*.24)),noise(p*6+vec2(-t*.13,t*.22)))-.5;
 vec2 q=(p+flow*.045)*vec2(5,9);
 vec2 a=mod(q,vec2(1.73205,3))-vec2(.866025,1.5);
 vec2 b=mod(q+vec2(.866025,1.5),vec2(1.73205,3))-vec2(.866025,1.5);
 vec2 h=dot(a,a)<dot(b,b)?a:b;
 float edge=.866025-max(abs(h.x),dot(abs(h),vec2(.5,.866025)));
 float aa=max(fwidth(edge),.015);
 float hex=1-smoothstep(.035-aa,.035+aa,edge);
 float ripple=.5+.5*sin(p.y*21-t*2.3+flow.x*7);
 float border=1.0-(abs(p.x-.5)+abs(p.y-.5))*2.0;
 float rim=1-smoothstep(.02,.12,border);
 vec3 gold=mix(vec3(.8,.22,.008),vec3(1,.85,.16),.35+.4*ripple);
 gold+=vec3(1,.92,.55)*(hex*.7+rim*.6);
 outColor=vec4(gold,clamp(.42+hex*.36+rim*.2+uMaterial._Charged*.08,0,1));
}

