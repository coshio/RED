/**
 * @file class1/deferred/aoUtil.glsl
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

uniform sampler2D       noiseMap;
uniform sampler2DRect   normalMap;
uniform sampler2DRect   depthMap;

uniform float ssao_radius;
uniform float ssao_max_radius;
uniform float ssao_factor;
uniform float ssao_factor_inv;

uniform mat4 inv_proj;
uniform vec2 screen_res;

vec2 getScreenCoordinateAo(vec2 screenpos)
{
    vec2 sc = screenpos.xy * 2.0;
    if (screen_res.x > 0 && screen_res.y > 0)
    {
       sc /= screen_res;
    }
    return sc - vec2(1.0, 1.0);
}

float getDepthAo(vec2 pos_screen)
{
    float depth = texture2DRect(depthMap, pos_screen).r;
    return depth;
}

vec4 getPositionAo(vec2 pos_screen)
{
    float depth = getDepthAo(pos_screen);
    vec2 sc = getScreenCoordinateAo(pos_screen);
    vec4 ndc = vec4(sc.xy, fma(depth,2.0,-1.0), 1.0);
    vec4 pos = inv_proj * ndc;
    pos /= pos.w;
    pos.w = 1.0;
    return pos;
}

vec2 getKern(int i)
{
    vec2 kern[32];
    // exponentially (^2) distant occlusion samples spread around origin
    kern[0] = vec2(0.5588, -0.6478);
    kern[1] = vec2(-0.6156, -0.3037);
    kern[2] = vec2(0.4793, -0.3502);
    kern[3] = vec2(-0.0256, 0.2539);
    kern[4] = vec2(-0.6076, -0.0868);
    kern[5] = vec2(-0.4345, 0.5241);
    kern[6] = vec2(0.6761, 0.5124);
    kern[7] = vec2(0.7146, -0.329);
    kern[8] = vec2(-0.7441, 0.2013);
    kern[9] = vec2(0.6939, 0.5134);
    kern[10] = vec2(0.4717, 0.5922);
    kern[11] = vec2(0.3632, 0.1362);
    kern[12] = vec2(-0.5886, -0.3133);
    kern[13] = vec2(0.4116, -0.3455);
    kern[14] = vec2(0.3545, -0.1868);
    kern[15] = vec2(-0.4661, -0.2461);
    kern[16] = vec2(-0.412, 0.2362);
    kern[17] = vec2(0.4455, 0.285);
    kern[18] = vec2(-0.314, 0.1362);
    kern[19] = vec2(-0.0432, -0.0667);
    kern[20] = vec2(0.2858, 0.295);
    kern[21] = vec2(0.031, 0.0607);
    kern[22] = vec2(-0.0619, 0.0178);
    kern[23] = vec2(-0.0741, -0.1339);
    kern[24] = vec2(-0.0264, 0.0173);
    kern[25] = vec2(-0.1371, 0.1852);
    kern[26] = vec2(0.1851, 0.1712);
    kern[27] = vec2(0.0209, -0.0592);
    kern[28] = vec2(0.0932, 0.0859);
    kern[29] = vec2(0.0888, -0.0179);
    kern[30] = vec2(-0.062, -0.0607);
    kern[31] = vec2(0.0075, 0.0016);

    return kern[i];
}

//calculate decreases in ambient lighting when crowded out (SSAO)
float calcAmbientOcclusion(vec4 pos, vec3 norm, vec2 pos_screen)
{
    float ret = 1.0;
    vec3 pos_world = pos.xyz;
    vec2 noise_reflect = texture2D(noiseMap, pos_screen.xy/128.0).xy;

    float angle_hidden = 0.0;
    float points = 0;
    float bias = 0.025;
    float scale = min(ssao_radius / -pos_world.z, ssao_max_radius);

    // it was found that keeping # of samples a constant was the fastest, probably due to compiler optimizations (unrolling?)
    for (int i = 0; i < 32; i++)
    {
        vec2 samppos_screen = pos_screen + scale * reflect(getKern(i), noise_reflect);
        vec3 samppos_world = getPositionAo(samppos_screen).xyz;

        vec3 diff = pos_world - samppos_world;
        float dist2 = dot(diff, diff);

        // assume each sample corresponds to an occluding sphere with constant radius, constant x-sectional area
        // --> solid angle shrinking by the square of distance
        //radius is somewhat arbitrary, can approx with just some constant k * 1 / dist^2
        //(k should vary inversely with # of samples, but this is taken care of later)

        float funky_val = (dot((samppos_world - bias * norm - pos_world), norm) > 0.0) ? 1.0 : 0.0;
        angle_hidden = angle_hidden + funky_val * min(1.0/dist2, ssao_factor_inv);

        // 'blocked' samples (significantly closer to camera relative to pos_world) are "no data", not "no occlusion"
        float diffz_val = (diff.z > -1.0) ? 1.0 : 0.0;
        points = points + diffz_val;
    }

    angle_hidden = min(ssao_factor*angle_hidden/points, 1.0);

    float points_val = (points > 0.0) ? 1.0 : 0.0;
    ret = (1.0 - (points_val * angle_hidden));

    ret = max(ret, 0.0);
    return min(ret, 1.0);
}
