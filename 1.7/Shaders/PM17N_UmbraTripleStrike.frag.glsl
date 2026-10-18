#version 450
layout(push_constant) uniform Push { mat4 modelMatrix; } push;
layout(set = 0, binding = 0) uniform VertexUniforms { mat4 ViewProj; } uVertex;
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _BallColor; // @color @default = vec4(1.0, 0.800000011920929, 0.20000000298023224, 1.0)
    vec4 _BeamColor; // @color @default = vec4(0.0, 0.5, 1.0, 0.20000000298023224)
    vec4 _PointA; // @default = vec4(0.0, 0.0, 0.0, 1.0)
    vec4 _PointB; // @default = vec4(5.0, 5.0, 5.0, 1.0)
    float _BallActive0; // @default = 0.0
    float _BallActive1; // @default = 0.0
    float _BallActive2; // @default = 0.0
    float _BallProgress0; // @default = 0.0
    float _BallProgress1; // @default = 0.0
    float _BallProgress2; // @default = 0.0
    float _BallSize; // @default = 0.15000000596046448
    float _BeamReveal; // @default = 1.0
    float _BeamWidth; // @default = 0.05000000074505806
    float _DrawBeamLink; // @default = 1.0
    float _DrawSlug; // @default = 1.0
    float _GlowIntensity; // @default = 5.0
    float _RibbonHalfWidth; // @default = 1.649999976158142
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
                vec2 texcoord ;
            };

            struct v2f
            {
                vec4 vertex ;
                vec3 worldPos ;
                vec2 uv ;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                vec2 uv = v.texcoord.xy;
                if (length(uv) < 1e-6)
                    uv = v.vertex.xz * 0.1 + 0.5;
                o.uv = saturate(uv);
                return o;
            }

            float distToSegment(vec3 p, vec3 a, vec3 b)
            {
                vec3 pa = p - a, ba = b - a;
                float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
                return length(pa - ba * h);
            }

            float BallSlugAlphaXZ(vec3 p, vec3 ballPos, vec2 trNorm, float bs)
            {
                vec2 d = p.xz - ballPos.xz;
                float a = dot(d, trNorm);
                float pe = length(d - trNorm * a);
                float halfLen = max(0.035, bs * 0.68);
                float rad = max(0.028, bs * 0.21);
                float ell = (a * a) / (halfLen * halfLen) + (pe * pe) / (rad * rad);
                return pow(saturate(1.0 - ell), 2.75);
            }

            vec4 frag (v2f i) 
            {
                vec3 p = i.worldPos;
                vec3 A = uMaterial._PointA.xyz;
                vec3 B = uMaterial._PointB.xyz;
                vec3 dir = B - A;

                float drawBeam = saturate(uMaterial._DrawBeamLink);
                float drawSlug = saturate(uMaterial._DrawSlug);
                float dLine = distToSegment(p, A, B);
                
                float beamAlpha = pow(saturate(1.0 - smoothstep(0.0, uMaterial._BeamWidth * 0.72, dLine)), 1.45);

                vec2 trF = B.xz - A.xz;
                float trFLen = length(trF);
                vec2 trNorm = trFLen > 1e-6 ? (trF / trFLen) : vec2(1, 0);
                vec2 vwF = p.xz - A.xz;
                float hF = clamp(dot(vwF, trF) / max(dot(trF, trF), 1e-8), 0.0, 1.0);

                float beamReveal = saturate(uMaterial._BeamReveal);
                float beamAlongMask;
                if (beamReveal <= 1e-4)
                    beamAlongMask = 0.0;
                else if (beamReveal >= 0.999)
                    beamAlongMask = 1.0;
                else
                {
                    float rw = 0.055;
                    beamAlongMask = 1.0 - smoothstep(beamReveal - rw, min(beamReveal + 0.02, 1.0), hF);
                }

                vec4 finalColor = uMaterial._BeamColor * beamAlpha * drawBeam * beamAlongMask;

                vec2 closestF = A.xz + trF * hF;
                float perpWorld = length(p.xz - closestF);
                float rhF = max(0.25, uMaterial._RibbonHalfWidth);
                float ribbonEdge = (1.0 - smoothstep(rhF * 0.58, rhF * 0.992, perpWorld));
                float quadFeather = smoothstep(0.0, 0.09, i.uv.x) * smoothstep(1.0, 0.91, i.uv.x) * smoothstep(0.0, 0.09, i.uv.y) * smoothstep(1.0, 0.91, i.uv.y);
                float edgeMask = saturate(ribbonEdge * 0.5 + quadFeather * 0.72);
                
                float incandW = max(0.002, uMaterial._BeamWidth * 0.15);
                float incandAlpha = pow(saturate(1.0 - smoothstep(0.0, incandW, dLine)), 2.85);
                float endCap = smoothstep(0.015, 0.06, hF) * smoothstep(1.0, 0.94, hF);
                vec3 incandRgb = vec3(1.0, 0.992, 0.98) * incandAlpha * endCap * (1.55 + 0.42 * uMaterial._GlowIntensity) * beamAlongMask;
                
                finalColor.rgb += incandRgb * drawBeam;

                if (uMaterial._BallActive0 > 0.5)
                {
                    vec3 ballPos0 = A + dir * saturate(uMaterial._BallProgress0);
                    float ballAlpha0 = BallSlugAlphaXZ(p, ballPos0, trNorm, uMaterial._BallSize);
                    finalColor += uMaterial._BallColor * ballAlpha0 * uMaterial._GlowIntensity * edgeMask * drawSlug;
                }

                if (uMaterial._BallActive1 > 0.5)
                {
                    vec3 ballPos1 = A + dir * saturate(uMaterial._BallProgress1);
                    float ballAlpha1 = BallSlugAlphaXZ(p, ballPos1, trNorm, uMaterial._BallSize);
                    finalColor += uMaterial._BallColor * ballAlpha1 * uMaterial._GlowIntensity * edgeMask * drawSlug;
                }

                if (uMaterial._BallActive2 > 0.5)
                {
                    vec3 ballPos2 = A + dir * saturate(uMaterial._BallProgress2);
                    float ballAlpha2 = BallSlugAlphaXZ(p, ballPos2, trNorm, uMaterial._BallSize);
                    finalColor += uMaterial._BallColor * ballAlpha2 * uMaterial._GlowIntensity * edgeMask * drawSlug;
                }

                finalColor.rgb *= edgeMask;
                finalColor.a *= edgeMask;
                return finalColor;
            }
            
layout(location = 0) in vec3 pmVworldPos;
layout(location = 1) in vec2 pmVuv;
layout(location = 0) out vec4 outColor;
void main() {
v2f pmInput;
pmInput.vertex = gl_FragCoord;
pmInput.worldPos = pmVworldPos;
pmInput.uv = pmVuv;
outColor = frag(pmInput);
}
