/**
 * @file pointLightV.glsl
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

uniform mat4 modelview_projection_matrix;
uniform mat4 modelview_matrix;
uniform vec3 center;
uniform float size;
uniform vec2 screen_res;


layout (location = 0) in vec3 position; 				//[-1, 1]
out vec4 vary_fragcoord;	//[-1, 1]
out vec4 vary_rectcoord;	//[0,  1]
out vec3 trans_center;

void main(){

	vec3 p = position * size + center; //this is aids need to fix this.
	vec4 pos = modelview_projection_matrix * vec4(p.xyz, 1.0);

	vary_rectcoord = pos;


	trans_center = (modelview_matrix * vec4(center.xyz, 1.0)).xyz;
	gl_Position = pos;




	// trans_center = (modelview_matrix * vec4(center.xyz, 1.0)).xyz



}
