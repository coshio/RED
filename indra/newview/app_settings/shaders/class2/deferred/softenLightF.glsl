/**
 * @file class2/deferred/softenLightF.glsl
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

#ifdef DEFINE_GL_FRAGCOLOR
  out vec4 frag_color;
#else
  #define frag_color gl_FragColor
#endif

uniform sampler2DRect diffuseRect;
uniform sampler2DRect specularRect;
uniform sampler2DRect normalMap;
uniform sampler2DRect depthMap;
uniform samplerCube   environmentMap;
uniform mat3 env_mat;

uniform sampler2D lightFunc;
uniform mat4 inv_proj;
uniform vec2 screen_res;


uniform sampler2DRect lightMap;
uniform vec3 sun_dir;
uniform vec3 moon_dir;
uniform int  sun_up_factor;
in vec2 vary_rectcoord; //[0,  screen_res]
in vec4 vary_fragcoord; //[-1, 1]


vec3 getNorm(vec2 pos_screen);
vec4 getPositionWithDepth(vec2 pos_screen, float depth);

void calcAtmosphericVars(vec3 inPositionEye, vec3 lightDirection, float ambFactor, out vec3 sunlit, out vec3 amblit, out vec3 additive, out vec3 atten, bool use_ao);
float getAmbientClamp();
vec3  atmosFragLighting(vec3 l, vec3 additive, vec3 atten);
vec3  scaleSoftClipFrag(vec3 l);
vec3  fullbrightAtmosTransportFrag(vec3 light, vec3 additive, vec3 atten);

vec3 linear_to_srgb(vec3 c);
vec3 srgb_to_linear(vec3 c);

#ifdef WATER_FOG
vec4 applyWaterFogView(vec3 vertexPosition, vec4 color);
#endif

//Cook Torrance BRDF Stuff
// ----------------------------------------------------------------------------
const float PI = 3.14159265359;
float DistributionGGX(vec3 N, vec3 H, float roughness){
    float a = roughness*roughness;
    float a2 = a*a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness){
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;
    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
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
vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness)
{
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}
// ----------------------------------------------------------------------------

void main(){
    vec3  color = vec3(0);
    float bloom = 0.0;

    //Position Data
    float depth = texture2DRect(depthMap, vary_rectcoord.xy).r;
    vec4 ndc = vec4(vary_fragcoord.xy, 2.0 * depth -1.0, 1.0);
    vec4 vertexPosition = inv_proj * ndc;
      vertexPosition /= vertexPosition.w;
      vertexPosition.w = 1.0;


    // <FS:Beq> Colour space and shader fixes for BUG-228586 (Rye)
    // convert to gamma space
    // </FS:Beq>
    vec4 albedo = texture(diffuseRect, vary_rectcoord.xy);
    albedo.rgb = linear_to_srgb(albedo.rgb);
    vec3  Normal  = getNorm(vary_rectcoord.xy);
    float Metallic = texture(normalMap, vary_rectcoord.xy).z;

    vec4 spec    = texture(specularRect, vary_rectcoord.xy);
    float Roughness = clamp(1.00 - spec.a, 0.0, 1.0);
    vec3 F0 = vec3(0.04);
      F0 = mix(F0, albedo.rgb,  Metallic);


    vec3  lightDirection   = (sun_up_factor == 1) ? sun_dir : moon_dir;
    float da          = clamp(dot(Normal.xyz, lightDirection.xyz), 0.0, 1.0);
    float light_gamma = 1.0 / 1.3;
    da                = pow(da, light_gamma);

    vec2 scol_ambocc = texture(lightMap, vary_rectcoord.xy).rg;
    scol_ambocc      = pow(scol_ambocc, vec2(light_gamma));
    float scol       = max(scol_ambocc.r, albedo.a);
    float ambocc     = scol_ambocc.g;


    vec3 sunlit;
    vec3 amblit;
    vec3 additive;
    vec3 atten;
    calcAtmosphericVars(vertexPosition.xyz, lightDirection, ambocc, sunlit, amblit, additive, atten, true);


    float ambient = min(abs(dot(Normal.xyz, sun_dir.xyz)), 1.0);
      ambient *= 0.5;
      ambient *= ambient;
      ambient = (1.0 - ambient);
      amblit *= ambient;
    vec3 sun_contrib = min(da, scol) * sunlit;

    //shadow is handled above
    vec3 radiance = sun_contrib;
    vec3 Lo = vec3(0.0);
    vec3 L = normalize(lightDirection);
    vec3 eyeDirection = normalize(-vertexPosition.xyz);
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
    vec3 ambientF = amblit * albedo.rgb * ambocc; //*ao
    color.rgb += ambientF + Lo;
    color.rgb = mix(color.rgb, albedo.rgb, albedo.a);

    float NdotH = dot(Normal.xyz, H);
    float NdotV = dot(Normal.xyz, eyeDirection);
    float VdotH = dot(eyeDirection, H);
    float gtdenom = 2 * NdotH;
    float gt = max(0, min(gtdenom * NdotV / VdotH, gtdenom * da / VdotH));

    float scontrib = F.r * texture2D(lightFunc, vec2(NdotH , spec.a)).r  * gt / (NdotH * da);
    vec3 sp = sun_contrib * scontrib / 6.0;
    sp = clamp(sp, vec3(0), vec3(1));
    bloom += dot(sp, sp) / 4.0;
    bloom = clamp(bloom, 0.0, 1.0);
    color += sp * spec.rgb;

    if (Metallic > 0.0){
      float NoH = dot(Normal.xyz, H);
      float VoH = dot(eyeDirection, H);
      float NoV = dot(Normal.xyz, eyeDirection);
      vec3 refnormpersp = normalize(reflect(vertexPosition.xyz, Normal.xyz));
      vec3 env_vec = env_mat * refnormpersp;
      vec3 reflected_color = textureCube(environmentMap, env_vec).rgb ;
      // reflected_color = (reflected_color * G * F * VoH) / ( NoH * NoV);
      reflected_color = clamp((reflected_color * G * F * VoH) / denominator, vec3(0.0), vec3(1.0));
      color.rgb += reflected_color * albedo.rgb;
    }
color = mix(atmosFragLighting(color, additive, atten), fullbrightAtmosTransportFrag(color, additive, atten), albedo.a);

#ifdef WATER_FOG
    vec4 fogged = applyWaterFogView(vertexPosition.xyz, vec4(color, bloom));
    color       = fogged.rgb;
    bloom       = fogged.a;
#endif

    // convert to linear as fullscreen lights need to sum in linear colorspace
    // and will be gamma (re)corrected downstream...
    frag_color.rgb = srgb_to_linear(color);
    frag_color.a   = bloom;
}
