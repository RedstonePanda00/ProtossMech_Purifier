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

void main(){
 vec3 n=normalize(worldNormal);
 float light=.38+.62*max(0.0,dot(n,normalize(vec3(-.5,1,-.6))));
 float spec=pow(max(0.0,dot(n,normalize(vec3(-.2,1,-.1)))),24.0);
 vec3 color=uMaterial._Tint.rgb*(.65+.35*light)+vec3(1,.86,.5)*spec*.35;
 color+=uMaterial._Tint.rgb*uMaterial._Charged*.12;
 float edge=pow(1.0-abs(n.y),3.0);
 outColor=vec4(color+vec3(1,.94,.7)*edge*.12,clamp(uMaterial._Tint.a+edge*.16,0,1));
}

