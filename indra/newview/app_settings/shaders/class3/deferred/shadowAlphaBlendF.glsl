/** 
 * @file shadowAlphaMaskF.glsl
 *
 * $LicenseInfo:firstyear=2011&license=viewerlgpl$
 * Second Life Viewer Source Code
 * Copyright (C) 2011, Linden Research, Inc.
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

uniform sampler2D diffuseMap;

#if !defined(DEPTH_CLAMP)
in float pos_zd2;
#endif

in float pos_w;

in float target_pos_x;
in vec4 vertex_color;
in vec2 vary_texcoord0;
in vec3 pos;

vec4 computeMoments(float depth, float a);

void main() 
{
	float alpha = diffuseLookup(vary_texcoord0.xy).a * vertex_color.a;

    frag_color = computeMoments(length(pos), float a);

#if !defined(DEPTH_CLAMP)
	gl_FragDepth = max(pos_zd2/pos_w+0.5, 0.0);
#endif
}
