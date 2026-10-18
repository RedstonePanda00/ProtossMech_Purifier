#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _Time;
    float _BlackHoleShrink; // @default = 0.0
    float _EdgeWidth; // @default = 0.017999999225139618
    float _GlowIntensity; // @default = 3.799999952316284
    float _LayerAlpha; // @default = 1.0
    float _ShatterScale; // @default = 11.0
    float _WarpProgress; // @default = 0.550000011920929
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



            struct appdata
            {
                vec4 vertex ;
                vec2 uv ;
            };

            struct v2f
            {
                vec4 pos ;
                vec2 uv ;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            vec2 Hash22(vec2 p)
            {
                p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
                return fract(sin(p) * 43758.5453);
            }

            float Hash12(vec2 p)
            {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            vec3 VoronoiCell(vec2 uv)
            {
                vec2 i = floor(uv);
                vec2 f = fract(uv);
                float minDist1 = 8.0;
                float minDist2 = 8.0;
                float cellId = 0.0;

                for (int y = -2; y <= 2; y++)
                for (int x = -2; x <= 2; x++)
                {
                    vec2 neighbor = vec2(x, y);
                    vec2 pt = Hash22(i + neighbor);
                    vec2 diff = neighbor + pt - f;
                    float d = dot(diff, diff);

                    if (d < minDist1)
                    {
                        minDist2 = minDist1;
                        minDist1 = d;
                        cellId = Hash12(i + neighbor);
                    }
                    else if (d < minDist2)
                    {
                        minDist2 = d;
                    }
                }

                return vec3(sqrt(minDist1), sqrt(minDist2), cellId);
            }

            vec4 frag(v2f i) 
            {
                float t = saturate(uMaterial._WarpProgress);
                vec2 centerVec = i.uv - 0.5;
                float dist = length(centerVec);
                float circleMask = smoothstep(0.5, 0.45, dist);

                vec2 shakeOffset = vec2(sin(uMaterial._Time.y * 75.0), cos(uMaterial._Time.y * 83.0))
                    * step(0.1, t) * (1.0 - smoothstep(0.1, 0.2, t)) * 0.035;

                vec3 vor = VoronoiCell((centerVec + 0.5 + shakeOffset) * uMaterial._ShatterScale);
                float edgeDist = vor.y - vor.x;
                float cellId = vor.z;

                float crackMask = smoothstep(0.0, uMaterial._EdgeWidth * 2.5, edgeDist);
                float gapOpaque = saturate(1.0 - crackMask);

                float shrinkPhase = mix(0.4, 0.02, smoothstep(0.0, 0.1, t));
                float spreadRadius = mix(shrinkPhase, 0.8, smoothstep(0.1, 0.15, t));
                float spreadMask = smoothstep(spreadRadius, spreadRadius - 0.2, dist);
                float crackLife = smoothstep(0.0, 0.055, t) * (1.0 - smoothstep(0.13, 0.24, t));
                gapOpaque *= spreadMask * crackLife;

                float shardHeight = Hash12(vec2(cellId, 77.7));
                float baseGrayscale = mix(0.15, 0.95, shardHeight);
                float canyonShadow = smoothstep(0.0, uMaterial._EdgeWidth * 0.8, edgeDist);
                float cliffHighlight = (1.0 - smoothstep(0.0, uMaterial._EdgeWidth * 0.4, edgeDist)) * shardHeight;
                float finalShade = baseGrayscale * canyonShadow + cliffHighlight * 2.0;

                vec3 rgb = finalShade.xxx * uMaterial._GlowIntensity * 0.5 * spreadMask * crackLife;
                float alpha = saturate(gapOpaque) * circleMask * saturate(1.0 - smoothstep(0.9, 1.0, t)) * uMaterial._LayerAlpha;
                return vec4(rgb, alpha);
            }
            
layout(location = 0) in vec2 pmVuv;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.pos = gl_FragCoord;
pmInput.uv = pmVuv;
outColor = frag(pmInput);
}
