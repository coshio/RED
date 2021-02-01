/**
 * @file multiPointLightF.glsl
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

out vec4 frag_color;

uniform sampler2DRect depthMap;
uniform sampler2DRect diffuseRect;
uniform sampler2DRect specularRect;
uniform sampler2DRect normalMap;
uniform samplerCube environmentMap;
uniform sampler2D noiseMap;
uniform sampler2D bumpMap;
uniform sampler2DRect lightMap;
uniform sampler2D     lightFunc;


//Screen Matrix Stuff
uniform mat4 inv_proj;
uniform vec4 light[LIGHT_COUNT];
uniform vec4 light_col[LIGHT_COUNT];

in vec2 vary_rectcoord; //[0,  1]
in vec4 vary_fragcoord;	//[-1, 1]
uniform vec2 screen_res;


vec4 getPosition(vec2 pos_screen);
vec3 getNorm(vec2 pos_screen);
vec3 srgb_to_linear(vec3 c);
vec3 linear_to_srgb(vec3 c);

//Cook Torrance Enhancements
// ----------------------------------------------------------------------------
const float PI = 3.14159265359;
float DistributionGGX(vec3 N, vec3 H, float roughness){
    float a = roughness * roughness;
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
float GeometrySmith(vec3 N, vec3 eyeDirection, vec3 unitLightDirection, float roughness){
    float NdotV = max(dot(N, eyeDirection), 0.0);
    float NdotL = max(dot(N, unitLightDirection), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0){
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}
// ----------------------------------------------------------------------------


void main(){
  vec3  outputColor = vec3(0.0);
  float bloom = 0.0;

#if defined(LOCAL_LIGHT_KILL)
    discard;
#else
  float depth = texture2DRect(depthMap, vary_rectcoord.xy).r;
  vec4 ndc = vec4(vary_fragcoord.xy, fma(depth,2.0,-1.0), 1.0);
  vec4 vertexPosition = inv_proj * ndc;
    vertexPosition /= vertexPosition.w;
    vertexPosition.w = 1.0;

  vec3 Diffuse = texture2D(diffuseRect, vary_rectcoord.xy).rgb;
    Diffuse.rgb = srgb_to_linear(Diffuse.rgb);
	vec3 Normal = getNorm(vary_rectcoord.xy);
  vec4 Specular = texture2D(specularRect, vary_rectcoord.xy);
  float Roughness = clamp(1.00 -  Specular.a, 0.0, 1.0);
  float Metallic = texture2D(normalMap, vary_rectcoord.xy).z;
	float noise = texture2D(noiseMap, vary_rectcoord.xy/128.0).b;
  vec3 F0 = vec3(0.04);
    F0 = mix(F0, Diffuse.rgb,  Metallic);

  vec3 eyeDirection = normalize(-vertexPosition.xyz); //Eye Direction
	for (int i = 0; i < LIGHT_COUNT; ++i){
    vec3 lightDirection = (light[i].xyz - vertexPosition.xyz);
		vec3 unitLightDirection = normalize(lightDirection);
    float distance = length(lightDirection);
    distance /= light[i].w;
		if (distance <= 1.0){
      //Quadratic Falloff Distance Attenuation Equation
      float fa = light_col[i].a + 1.0;
      float dist_atten = clamp(1.0 - (distance - 1.0 * (1.0 - fa) ) / fa, 0.0, 1.0);
        dist_atten *= dist_atten;
			  dist_atten *= 2.0;
        dist_atten *= noise;
      vec3 radiance = dist_atten *  light_col[i].rgb;
			vec3 H = normalize(unitLightDirection + eyeDirection);
      float NDF = DistributionGGX(Normal.xyz, H, Roughness);
      float G   = GeometrySmith(Normal.xyz, eyeDirection, unitLightDirection, Roughness);
      vec3 F    = fresnelSchlick(max(dot(H, eyeDirection), 0.0), F0);
      vec3 nominator    = NDF * G * F;                                  //
      float denominator = 4 * max(dot(Normal.xyz, eyeDirection), 0.0) * max(dot(Normal.xyz,  unitLightDirection), 0.0) + 0.001; // 0.001 to prevent divide by zero.
      vec3 specular = nominator / denominator;
      vec3 kS = F;
      vec3 kD = vec3(1.0) - kS;
      kD *= 1.0 - Metallic;
      float NdotL = max(dot(Normal.xyz, unitLightDirection.xyz), 0.0) * 6;
      outputColor += ((kD * Diffuse.rgb)  / PI + specular * Specular.rgb) * radiance  * NdotL;
      bloom += dot(specular, specular) * 0.166667;
      //
      float da = dot(Normal.xyz, unitLightDirection);
      float NdotH = dot(Normal.xyz, H);
      float NdotV = dot(Normal.xyz, eyeDirection);
      float VdotH = dot(eyeDirection, H);
      float gtdenom = 2 * NdotH;
      float gt = max(0, min(gtdenom * NdotV / VdotH, gtdenom * da / VdotH));
      float scol = F.r * texture2D(lightFunc, vec2(NdotH, Specular.a)).r * gt / (NdotH * da);
      outputColor += da * dist_atten * scol * light_col[i].rgb * Specular.rgb;
		}
	}

#endif








	frag_color.rgb = linear_to_srgb(outputColor);
	frag_color.a = bloom;

#ifdef IS_AMD_CARD
	// If it's AMD make sure the GLSL compiler sees the arrays referenced once by static index. Otherwise it seems to optimise the storage awawy which leads to unfun crashes and artifacts.
	vec4 dummy1 = light[0];
	vec4 dummy2 = light_col[0];
	vec4 dummy3 = light[LIGHT_COUNT-1];
	vec4 dummy4 = light_col[LIGHT_COUNT-1];
#endif
}
