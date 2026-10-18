#version 450
#define PM_VERTEX
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _FresnelColor; // @color @default = vec4(0.800000011920929, 0.8999999761581421, 1.0, 1.0)
    vec4 _GlowColor; // @color @default = vec4(1.0, 1.0, 1.0, 1.0)
    vec4 _LightDir; // @default = vec4(0.30000001192092896, 0.699999988079071, 0.5, 0.0)
    vec4 _StrandColor; // @color @default = vec4(0.9200000166893005, 0.949999988079071, 1.0, 1.0)
    vec4 _Time;
    float _AnisotropyShift; // @default = 0.11999999731779099
    float _BaseAlpha; // @default = 0.550000011920929
    float _CatenaryStrength; // @default = 0.0
    float _CatenaryVariation; // @default = 1.0
    float _FresnelPower; // @default = 2.0
    float _GlowIntensity; // @default = 2.5
    float _GrowthSharpness; // @default = 12.0
    float _LateralSpread; // @default = 0.019999999552965164
    float _Progress; // @default = 0.0
    float _RootFade; // @default = 0.10000000149011612
    float _Specular1Width; // @default = 0.18000000715255737
    float _Specular2Strength; // @default = 0.4000000059604645
    float _Specular2Width; // @default = 0.550000011920929
    float _StrandCount; // @default = 38.0
    float _StrandDelay; // @default = 0.18000000715255737
    float _StrandWidth; // @default = 0.004000000189989805
    float _TipFade; // @default = 0.10000000149011612
    float _WaveAmp; // @default = 0.029999999329447746
    float _WaveFreq; // @default = 12.0
    float _WidthVariation; // @default = 0.6000000238418579
} uMaterial;

#define UNITY_PI 3.14159265358979323846
#define UNITY_TWO_PI 6.28318530717958647692
#define saturate(x) clamp(x, 0.0, 1.0)
#define rsqrt(x) inversesqrt(x)
#define fmod(x,y) ((x) - (y) * trunc((x)/(y)))
#define TRANSFORM_TEX(uv,tex) ((uv).xy * tex##_ST.zw + tex##_ST.xy)
#define mul(a,b) ((a)*(b))
#define unity_ObjectToWorld push.modelMatrix
vec4 UnityObjectToClipPos(vec4 p) { return uVertex.ViewProj * push.modelMatrix * p; }
vec4 UnityObjectToClipPos(vec3 p) { return UnityObjectToClipPos(vec4(p,1.0)); }
vec4 ComputeGrabScreenPos(vec4 p) { return vec4(p.xy * .5 + p.ww * .5, p.zw); }
vec4 PMTexture(sampler2D image, vec2 uv) { return texture(image,vec2(uv.x,1.0-uv.y)); }
void PMSincos(float a, out float s, out float c) {s=sin(a);c=cos(a);}
float distance(vec2 p, float q) {return length(p-vec2(q));}
#ifdef PM_VERTEX
#define fwidth(x) ((x)*0.0)
#define dFdx(x) ((x)*0.0)
#define dFdy(x) ((x)*0.0)
void clip(float v) {}
#else
// Unity's Vulkan binaries use coarse derivatives for HLSL fwidth/ddx/ddy.
// Native GLSL's unspecified derivative choice can change fine line coverage.
#define fwidth(x) (abs(dFdxCoarse(x)) + abs(dFdyCoarse(x)))
#define dFdx(x) dFdxCoarse(x)
#define dFdy(x) dFdyCoarse(x)
void clip(float v) {if(v<0.0)discard;}
#endif



            struct appdata { vec4 vertex; vec2 uv; };
            struct v2f    { vec4 pos;  vec2 uv; };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv  = v.uv;
                return o;
            }

            float hash11(float n) { return fract(sin(n) * 43758.5453123); }
            float hash12(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }

            float smootherstep(float e0, float e1, float x)
            {
                x = saturate((x - e0) / (e1 - e0));
                return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
            }

            float KajiyaKay(vec3 T, vec3 L, vec3 V, float shift, float width)
            {
                vec3 H    = normalize(L + V);
                float  dotTH = dot(T, H) + shift;
                float  sinTH = sqrt(max(0.0, 1.0 - dotTH * dotTH));
                return pow(max(0.0, sinTH), max(0.001, 1.0 / (width * width)));
            }

            vec4 frag(v2f i) 
            {
                vec2 uv = i.uv; 

                float totalAlpha    = 0.0;
                float totalSpec1    = 0.0;
                float totalSpec2    = 0.0;
                float totalFresnel  = 0.0;
                int   count         = int(uMaterial._StrandCount);

                for (int s = 0; s < count; s++)
                {
                    float sid = float(s);

                    float h0 = hash11(sid * 1.7321 + 0.137);
                    float h1 = hash11(sid * 2.3456 + 0.537);
                    float h2 = hash11(sid * 3.1415 + 0.837);
                    float h3 = hash11(sid * 4.6692 + 0.237);

                    float normPos  = (sid + 0.5) / float(count);        
                    float centered = (normPos - 0.5) * 2.0;             
                    float centerY  = centered + (h0 - 0.5) * 0.18;     
                    
                    float baseY    = centerY * 0.5 * uMaterial._LateralSpread * 2.0 + 0.5;

                    float width    = uMaterial._StrandWidth * (1.0 + (h1 - 0.5) * uMaterial._WidthVariation * 2.0);
                    width         *= max(0.2, 1.0 - abs(centered) * 0.5); 

                    float catAmp   = uMaterial._CatenaryStrength * (1.0 + (h2 - 0.5) * uMaterial._CatenaryVariation * 2.0);

                    float delay    = h3 * uMaterial._StrandDelay;
                    float localProg = saturate((uMaterial._Progress - delay) / (1.0 - delay + 0.001));

                    float strandVisible = smootherstep(
                        localProg,
                        localProg - 1.0 / uMaterial._GrowthSharpness,
                        uv.x
                    );
                    if (strandVisible < 0.001) continue;

                    float xCentered = uv.x * 2.0 - 1.0;
                    float catY      = baseY + catAmp * (1.0 - xCentered * xCentered);
                    
                    float wave      = sin(uv.x * uMaterial._WaveFreq + h0 * 6.2832 + uMaterial._Time.y * (2.0 + h1 * 3.0))
                                    * uMaterial._WaveAmp * (1.0 - abs(xCentered)); 
                    catY += wave;

                    float dist  = abs(uv.y - catY);
                    float inner = smoothstep(width, 0.0, dist);
                    if (inner < 0.001) continue;

                    float tipAlpha  = smootherstep(0, uMaterial._TipFade, 1.0 - uv.x)
                                    * smootherstep(0, uMaterial._RootFade, uv.x);

                    float strandAlpha = inner * tipAlpha * strandVisible;

                    float dydx = -2.0 * catAmp * xCentered / max(0.001, 1.0);
                    vec3 T   = normalize(vec3(1.0, dydx, 0.0));
                    vec3 L   = normalize(uMaterial._LightDir.xyz);
                    
                    vec3 V   = vec3(0.0, 0.0, 1.0);

                    float spec1 = KajiyaKay(T, L, V,  uMaterial._AnisotropyShift,                  uMaterial._Specular1Width);
                    float spec2 = KajiyaKay(T, L, V,  uMaterial._AnisotropyShift - 0.08, uMaterial._Specular2Width);

                    float fresnel = pow(1.0 - inner, uMaterial._FresnelPower);

                    totalAlpha   += strandAlpha;
                    totalSpec1   += spec1 * strandAlpha;
                    totalSpec2   += spec2 * strandAlpha * uMaterial._Specular2Strength;
                    totalFresnel += fresnel * strandAlpha;
                }

                if (totalAlpha < 0.001) clip(-1.0);

                float  normAlpha = saturate(totalAlpha);
                float  s1        = saturate(totalSpec1 / max(0.001, totalAlpha));
                float  s2        = saturate(totalSpec2 / max(0.001, totalAlpha));
                float  fres      = saturate(totalFresnel / max(0.001, totalAlpha));

                vec3 col = uMaterial._StrandColor.rgb;
                
                col += uMaterial._GlowColor.rgb * s1 * uMaterial._GlowIntensity;
                col += uMaterial._GlowColor.rgb * s2;
                
                col  = mix(col, uMaterial._FresnelColor.rgb, fres * 0.4);

                float alpha = uMaterial._BaseAlpha * normAlpha;
                alpha      += s1 * 0.3 * normAlpha;   
                alpha       = saturate(alpha);

                return vec4(col, alpha);
            }
            
layout(location = 0) in vec3 pmInvertex; // @vertex Position required
layout(location = 3) in vec2 pmInuv; // @vertex TexCoord0 optional @default = vec4(0.0)
layout(location = 0) out vec2 pmVuv;
void main() {
appdata pmInput;
pmInput.vertex = vec4(pmInvertex, 1.0);
pmInput.uv = pmInuv;
v2f pmOutput = vert(pmInput);
gl_Position = pmOutput.pos;
pmVuv = pmOutput.uv;
}
