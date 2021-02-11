/**
* @file materialF.glsl
*
* $LicenseInfo:firstyear=2007&license=viewerlgpl$
* Second Life Viewer Source Code
* Copyright (C) 2007, Linden Research, Inc.
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation;
* version 2.1 of the License only.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this library; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*
* Linden Research, Inc., 945 Battery Street, San Francisco, CA  94111  USA
* $/LicenseInfo$
*/

/*[EXTRA_CODE_HERE]*/

//class1/deferred/materialF.glsl

// This shader is used for both writing opaque/masked content to the gbuffer and writing blended content to the framebuffer during the alpha pass.

#define DIFFUSE_ALPHA_MODE_NONE     0
#define DIFFUSE_ALPHA_MODE_BLEND    1
#define DIFFUSE_ALPHA_MODE_MASK     2
#define DIFFUSE_ALPHA_MODE_EMISSIVE 3

uniform float emissive_brightness;  // fullbright flag, 1.0 == fullbright, 0.0 otherwise
uniform int sun_up_factor;

#ifdef WATER_FOG
vec4 applyWaterFogView(vec3 pos, vec4 color);
#endif

vec3 atmosFragLighting(vec3 l, vec3 additive, vec3 atten);
vec3 scaleSoftClipFrag(vec3 l);

vec3 fullbrightAtmosTransportFrag(vec3 light, vec3 additive, vec3 atten);
vec3 fullbrightScaleSoftClip(vec3 light);

void calcAtmosphericVars(vec3 inPositionEye, vec3 light_dir, float ambFactor, out vec3 sunlit, out vec3 amblit, out vec3 additive, out vec3 atten, bool use_ao);

vec3 srgb_to_linear(vec3 cs);
vec3 linear_to_srgb(vec3 cs);

#if (DIFFUSE_ALPHA_MODE == DIFFUSE_ALPHA_MODE_BLEND)

out vec4 frag_color;

#ifdef HAS_SUN_SHADOW
float sampleDirectionalShadow(vec3 pos, vec3 norm, vec2 pos_screen);
#endif

uniform samplerCube environmentMap;
uniform sampler2D     lightFunc;

// Inputs
uniform vec4 morphFactor;
uniform vec3 camPosLocal;
uniform mat3 env_mat;

uniform vec3 sun_dir;
uniform vec3 moon_dir;
in vec2 vary_fragcoord;

in vec3 vary_position;
uniform mat4 proj_mat;
uniform mat4 inv_proj;
uniform vec2 screen_res;

uniform vec4 light_position[8];
uniform vec3 light_direction[8];
uniform vec4 light_attenuation[8];
uniform vec3 light_diffuse[8];

float getAmbientClamp();

vec3 calcPointLightOrSpotLight(vec3 light_col, vec3 npos, vec3 diffuse, vec4 spec, vec3 v, vec3 n, vec4 lp, vec3 ln, float la, float fa, float is_pointlight, inout float glare, float ambiance){
    vec3 col = vec3(0);

    //get light vector
    vec3 lv = lp.xyz - v;

    //get distance
    float dist = length(lv);
    float da = 1.0;

    dist /= la;

    if (dist > 0.0 && la > 0.0)
    {
        //normalize light vector
        lv = normalize(lv);
        //distance attenuation
        float dist_atten = clamp(1.0 - (dist - 1.0*(1.0 - fa)) / fa, 0.0, 1.0);
        dist_atten *= dist_atten;
        dist_atten *= 2.0f;
        if (dist_atten <= 0.0){
            return col;
        }

        // spotlight coefficient.
        float spot = max(dot(-ln, lv), is_pointlight);
        da *= spot*spot; // GL_SPOT_EXPONENT=2

        //angular attenuation
        da *= dot(n, lv);

        float lit = 0.0f;

        float amb_da = ambiance;
        if (da >= 0)
        {
            lit = max(da * dist_atten, 0.0);
            col = lit * light_col * diffuse;
            amb_da += fma(da, 0.5, 0.5) * ambiance;
        }
        amb_da += fma(da*da,0.5, 0.5) * ambiance;
        amb_da *= dist_atten;
        amb_da = min(amb_da, 1.0f - lit);

        // SL-10969 need to see why these are blown out
        //col.rgb += amb_da * light_col * diffuse;


            //vec3 ref = dot(pos+lv, norm);
            vec3 h = normalize(lv + npos);
            float nh = dot(n, h);
            float nv = dot(n, npos);
            float vh = dot(npos, h);
            float sa = nh;
            float fres = fma(pow(1 - dot(h, npos), 5),0.4, 0.5);

            float gtdenom = 2 * nh;
            float gt = max(0, min(gtdenom * nv / vh, gtdenom * da / vh));

            if (nh > 0.0)
            {
                float scol = fres * texture2D(lightFunc, vec2(nh, spec.a)).r * gt / (nh * da);
                vec3 speccol = lit*scol*light_col.rgb*spec.rgb;
                speccol = clamp(speccol, vec3(0), vec3(1));
                col += speccol;

                float cur_glare = max(speccol.r, speccol.g);
                cur_glare = max(cur_glare, speccol.b);
                glare = max(glare, speccol.r);
                glare += max(cur_glare, 0.0);
            }

    }

    return max(col, vec3(0.0, 0.0, 0.0));
}

#else
#ifdef DEFINE_GL_FRAGCOLOR
out vec4 frag_data[3];
#else
#define frag_data gl_FragData
#endif
#endif

uniform sampler2D diffuseMap;  //always in sRGB space

#ifdef HAS_NORMAL_MAP
uniform sampler2D bumpMap;
#endif

#ifdef HAS_SPECULAR_MAP
uniform sampler2D specularMap;

in vec2 vary_texcoord2;
#endif

uniform float env_intensity;
uniform vec4 specular_color;  // specular color RGB and specular exponent (glossiness) in alpha

#if (DIFFUSE_ALPHA_MODE == DIFFUSE_ALPHA_MODE_MASK)
uniform float minimum_alpha;
#endif

#ifdef HAS_NORMAL_MAP
in vec2 vary_texcoord1;
in mat3 TBN;

#else
in vec3 vary_normal;
#endif

in vec4 vertex_color;
in vec2 vary_texcoord0;


//Cook Torrance BRDF Stuff
// ----------------------------------------------------------------------------
const float PI = 3.14159265359;
float DistributionGGX(vec3 N, vec3 H, float roughness){
    float a = roughness*roughness;
    float a2 = a*a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
    float nom   = a2;
    float denom = fma(NdotH2, (a2 - 1.0), 1.0);
    denom = PI * denom * denom;
    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness){
    float r = (roughness + 1.0);
    float k = (r*r) * 0.125;
    float nom   = NdotV;
    float denom = fma(NdotV, (1.0 - k), k);
    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySmith(vec3 N, vec3 eyeDirection, vec3 L, float roughness){
    float NdotV = max(dot(N, eyeDirection), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0){
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness){
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}
// ----------------------------------------------------------------------------

vec2 encode_normal(vec3 n);
void main()
{
    vec2 pos_screen = vary_texcoord0.xy;

    vec4 diffcol = texture2D(diffuseMap, vary_texcoord0.xy);
	diffcol.rgb *= vertex_color.rgb;

#if (DIFFUSE_ALPHA_MODE == DIFFUSE_ALPHA_MODE_MASK)

    // Comparing floats cast from 8-bit values, produces acne right at the 8-bit transition points
    float bias = 0.001953125; // 1/512, or half an 8-bit quantization
    if (diffcol.a < minimum_alpha-bias)
    {
        discard;
    }
#endif

#if (DIFFUSE_ALPHA_MODE == DIFFUSE_ALPHA_MODE_BLEND)
	vec3 gamma_diff = diffcol.rgb;
	diffcol.rgb = srgb_to_linear(diffcol.rgb);
#endif
vec4 final_color = diffcol;

#ifdef HAS_SPECULAR_MAP
    vec4 spec = texture2D(specularMap, vary_texcoord2.xy);
    spec.rgb *= specular_color.rgb;
#else
    vec4 spec = vec4(specular_color.rgb, 1.0);
#endif

// #ifdef HAS_NORMAL_MAP
// 	vec4 norm = vec4(texture2D(bumpMap, vary_texcoord1.xy).xyz  * 2 - 1 , 1.0);
//   norm.xyz = normalize(norm.xyz * transpose(TBN)); //This makes no sense
// #else
// 	vec4 norm = vec4(normalize(vary_normal), 1.0);
// #endif

#ifdef HAS_NORMAL_MAP
	vec4 norm = texture2D(bumpMap, vary_texcoord1.xy);
	norm.xyz = norm.xyz * 2 - 1;
	vec3 tnorm = norm.xyz * transpose(TBN);
#else
	vec4 norm = vec4(0,0,0,1.0);
	vec3 tnorm = vary_normal;
#endif


vec4 final_specular = spec;
#ifdef HAS_SPECULAR_MAP
  vec4 final_normal = vec4(encode_normal(normalize(tnorm)), env_intensity * spec.a, 0.0);
	final_specular.a = specular_color.a * norm.a;
#else
  vec4 final_normal = vec4(encode_normal(normalize(tnorm)), env_intensity, 0.0);
	final_specular.a = specular_color.a;
#endif

#if (DIFFUSE_ALPHA_MODE != DIFFUSE_ALPHA_MODE_EMISSIVE)
	final_color.a = emissive_brightness;
#else
	final_color.a = max(final_color.a, emissive_brightness);
#endif

#if (DIFFUSE_ALPHA_MODE == DIFFUSE_ALPHA_MODE_BLEND)
  //forward rendering, output just lit sRGBA
  vec3 pos = vary_position;
  float shadow = 1.0f;
#ifdef HAS_SUN_SHADOW
    shadow = sampleDirectionalShadow(pos.xyz, norm.xyz, pos_screen);
#endif
  vec3 color = vec3(0,0,0);
  float bloom = 0.0;


  vec4 albedo = final_color;
  albedo.rgb  = linear_to_srgb(albedo.rgb);
  vec3 Normal = normalize(tnorm.xyz);
  float Metallic = final_normal.z;
  spec = final_specular;
  float Roughness = clamp(1.00 - final_specular.a, 0.0, 1.0);
  vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo.rgb,  Metallic);

  vec3 light_dir = (sun_up_factor == 1) ? sun_dir : moon_dir;
  float da = clamp(dot(normalize(tnorm.xyz), light_dir.xyz), 0.0, 1.0);
  da = pow(da, 1.0 / 1.3);

  vec3 sunlit;
  vec3 amblit;
  vec3 additive;
  vec3 atten;
  calcAtmosphericVars(pos.xyz, light_dir, 1.0, sunlit, amblit, additive, atten, false);

  float ambient = min(abs(dot(normalize(tnorm.xyz), light_dir)), 1.0);
  ambient *= 0.5;
  ambient *= ambient;
  ambient = (1.0 - ambient);
  amblit *= ambient;
  vec3 sun_contrib = min(da, shadow) * sunlit;

  vec3 radiance = sun_contrib;
  vec3 Lo = vec3(0.0);
  vec3 L = normalize(light_dir);
  vec3 eyeDirection = normalize(-pos.xyz);
  vec3 R = reflect(-eyeDirection, Normal.xyz);
  vec3 H    = normalize(eyeDirection + L);
  float NDF = DistributionGGX(Normal.xyz, H, Roughness);
  float G   = GeometrySmith(Normal.xyz, eyeDirection, L, Roughness);
  vec3 F    = fresnelSchlick(max(dot(H, eyeDirection), 0.0), F0);
  vec3 nominator    = NDF * G * F;
  float denominator = 4 * max(dot(Normal.xyz, eyeDirection), 0.0) * max(dot(Normal.xyz, L), 0.0) + 0.001; // 0.001 to prevent divide by zero.
  vec3 specular = nominator / denominator;
  vec3 kS = F;
  vec3 kD = vec3(1.0) - kS;
  kD *= 1.0 - Metallic;
  float NdotL = max(dot(Normal.xyz, L), 0.0);
  Lo += ((kD * albedo.rgb)  / PI + specular * spec.rgb) * radiance  * NdotL;
  vec3 ambientF = amblit * albedo.rgb;
  color.rgb += ambientF + Lo;
  color.rgb = mix(color.rgb, albedo.rgb, albedo.a);


  float NdotH = dot(Normal.xyz, H);
  float NdotV = dot(Normal.xyz, eyeDirection);
  float VdotH = dot(eyeDirection, H);
  float gtdenom = 2 * NdotH;
  float gt = max(0, min(gtdenom * NdotV / VdotH, gtdenom * da / VdotH));

  vec3 refnormpersp = normalize(reflect(pos.xyz, normalize(tnorm.xyz)));
  float sa        = dot(refnormpersp, sun_dir.xyz);

  float scontrib = F.r * texture2D(lightFunc, vec2(sa, spec.a)).r  * gt / (NdotH * da);
  vec3 sp = sun_contrib * scontrib * 0.166667;
  sp = clamp(sp, vec3(0), vec3(1));
  //TODO: INTEGRATE THIS WITH THE BLOOM SETTINGS.
  bloom += dot(sp, sp) * 0.25;
  bloom = clamp(bloom, 0.0, 1.0);
  color += sp * spec.rgb;

  float glare = 0.0;
  if (Metallic > 0.0){
    float NoH = dot(Normal.xyz, H);
    float VoH = dot(eyeDirection, H);
    float NoV = dot(Normal.xyz, eyeDirection);
    vec3 refnormpersp = normalize(reflect(pos.xyz, Normal.xyz));
    vec3 env_vec = env_mat * refnormpersp;
    vec3 reflected_color = texture(environmentMap, env_vec).rgb ;
    // reflected_color = clamp((reflected_color * G * F * VoH) / denominator, vec3(0.0), vec3(1.0)) * albedo.rgb;
    reflected_color = (reflected_color * G * F * VoH) / ( NoH * NoV);
    reflected_color *= albedo.rgb;
    glare = max(reflected_color.r, reflected_color.g);
    glare = max(glare, reflected_color.b);
    color.rgb += reflected_color;
  }
  color = atmosFragLighting(color, additive, atten);
  //convert to linear before adding local lights
  color = srgb_to_linear(color);
  vec3 npos = normalize(-pos.xyz);
  vec3 light = vec3(0, 0, 0);
  final_specular.rgb = srgb_to_linear(final_specular.rgb);// <FS:Beq/> Colour space and shader fixes for BUG-228586 (Rye)

#define LIGHT_LOOP(i) light.rgb += calcPointLightOrSpotLight(light_diffuse[i].rgb, npos, albedo.rgb, final_specular, pos.xyz, tnorm.xyz, light_position[i], light_direction[i].xyz, light_attenuation[i].x, light_attenuation[i].y, light_attenuation[i].z, glare, light_attenuation[i].w );
  LIGHT_LOOP(1)
  LIGHT_LOOP(2)
  LIGHT_LOOP(3)
  LIGHT_LOOP(4)
  LIGHT_LOOP(5)
  LIGHT_LOOP(6)
  LIGHT_LOOP(7)

    color += light;

    glare = min(glare, 1.0);
    float al = max(diffcol.a, glare) *vertex_color.a;

    //convert to srgb as this color is being written post gamma correction
    color = linear_to_srgb(color);

#ifdef WATER_FOG
    vec4 temp = applyWaterFogView(pos, vec4(color, al));
    color = temp.rgb;
    al = temp.a;
#endif

    frag_color = vec4(color, al);

#else // mode is not DIFFUSE_ALPHA_MODE_BLEND, encode to gbuffer

    // deferred path
    frag_data[0] = final_color; //gbuffer is sRGB
    frag_data[1] = final_specular; // XYZ = Specular color. W = Specular exponent.
    frag_data[2] = final_normal; // XY = Normal.  Z = Env. intensity.
#endif
}
