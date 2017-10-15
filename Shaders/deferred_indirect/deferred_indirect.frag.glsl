#version 450

#ifdef GL_ES
precision mediump float;
#endif

#include "../compiled.glsl"
#include "../std/gbuffer.glsl"
#include "../std/math.glsl"
#include "../std/brdf.glsl"
#ifdef _Irr
	#include "../std/shirr.glsl"
#endif
#ifdef _VoxelGI
	#include "../std/conetrace.glsl"
#endif
#ifdef _VoxelAO
	#include "../std/conetrace.glsl"
#endif
#ifdef _DFAO
#include "../std/sdf.glsl"
#endif

uniform sampler2D gbufferD;
uniform sampler2D gbuffer0;
uniform sampler2D gbuffer1;

#ifdef _VoxelGI
	//!uniform sampler3D voxels;
	uniform vec3 eyeSnap;
#endif
#ifdef _VoxelAO
	//!uniform sampler3D voxels;
	uniform vec3 eyeSnap;
#endif

uniform float envmapStrength;
#ifdef _Irr
	//!uniform vec4 shirr[7];
#endif
#ifdef _Rad
	uniform sampler2D senvmapRadiance;
	uniform sampler2D senvmapBrdf;
	uniform int envmapNumMipmaps;
#endif

#ifdef _SSAO
	uniform sampler2D ssaotex;
#endif

#ifdef _Rad
	uniform vec3 eye;
	uniform vec3 eyeLook;
#endif
#ifdef _DFAO
	//!uniform sampler3D sdftex;
#endif

in vec2 texCoord;
#ifdef _Rad
	in vec3 viewRay;
#endif
out vec4 fragColor;

void main() {
	vec4 g0 = texture(gbuffer0, texCoord); // Normal.xy, metallic/roughness, depth
	
	vec3 n;
	n.z = 1.0 - abs(g0.x) - abs(g0.y);
	n.xy = n.z >= 0.0 ? g0.xy : octahedronWrap(g0.xy);
	n = normalize(n);

	vec2 metrough = unpackFloat(g0.b);

	vec4 g1 = texture(gbuffer1, texCoord); // Basecolor.rgb, 
	vec3 albedo = surfaceAlbedo(g1.rgb, metrough.x); // g1.rgb - basecolor

#ifdef _Rad
	#ifdef _InvY // D3D
	float depth = texture(gbufferD, texCoord).r * 2.0 - 1.0;
	#else
	// TODO: Firefox throws transform loop error even when no depth write is performed
	float depth = (1.0 - g0.a) * 2.0 - 1.0;
	#endif
	vec3 p = getPos(eye, eyeLook, viewRay, depth);
	vec3 v = normalize(eye - p.xyz);

	float dotNV = max(dot(n, v), 0.0);
	vec3 f0 = surfaceF0(g1.rgb, metrough.x);
	vec2 envBRDF = texture(senvmapBrdf, vec2(metrough.y, 1.0 - dotNV)).xy;
#endif

#ifdef _VoxelGI
	#ifdef _VoxelGICam
	vec3 voxpos = (p - eyeSnap) / voxelgiHalfExtents;
	#else
	vec3 voxpos = p / voxelgiHalfExtents;
	#endif

	vec4 indirectDiffuse = traceDiffuse(voxpos, n);
		
	vec3 indirectSpecular = traceSpecular(voxpos, n, v, metrough.y);
	indirectSpecular *= f0 * envBRDF.x + envBRDF.y;

	fragColor.rgb = indirectDiffuse.rgb * voxelgiDiff * g1.rgb + indirectSpecular * voxelgiSpec;

	// if (!isInsideCube(voxpos)) fragColor = vec4(1.0); // Show bounds

	#ifdef _SSAO
	fragColor.rgb *= texture(ssaotex, texCoord).r * 0.5 + 0.5;
	#endif

	// float opacity = g1.a;
	// if (opacity < 1.0) fragColor.rgb = mix(indirectRefractiveLight(-v, n, vec3(1.0), opacity, voxpos), fragColor.rgb, opacity);

	// return;
#endif

	// Envmap
#ifdef _Irr
	vec3 envl = shIrradiance(n);
	#ifdef _EnvTex
	envl /= PI;
	#endif
#else
	vec3 envl = vec3(1.0);
#endif

#ifdef _Rad
	vec3 reflectionWorld = reflect(-v, n);
	float lod = getMipFromRoughness(metrough.y, envmapNumMipmaps);
	vec3 prefilteredColor = textureLod(senvmapRadiance, envMapEquirect(reflectionWorld), lod).rgb;
#endif

#ifdef _EnvLDR
	envl.rgb = pow(envl.rgb, vec3(2.2));
	#ifdef _Rad
		prefilteredColor = pow(prefilteredColor, vec3(2.2));
	#endif
#endif

	envl.rgb *= albedo;
	
#ifdef _Rad // Indirect specular
	envl.rgb += prefilteredColor * (f0 * envBRDF.x + envBRDF.y) * 1.5;
#endif

#ifdef _SSS
	envl.rgb *= envmapStrength * fract(g1.a);
#else
	#ifndef _VoxelGIRefract
	envl.rgb *= envmapStrength * g1.a; // Occlusion
	#endif
#endif

#ifdef _DFGI
	envl.rgb = dfgi(p, n) * albedo;
#endif

#ifdef _SSAO
	envl.rgb *= texture(ssaotex, texCoord).r;
#endif

#ifdef _DFAO
	envl.rgb *= dfao(p, n);
#endif

#ifdef _VoxelAO

	#ifdef _VoxelGICam
	vec3 voxpos = (p - eyeSnap) / voxelgiHalfExtents;
	#else
	vec3 voxpos = p / voxelgiHalfExtents;
	#endif
	
	envl.rgb *= 1.0 - traceAO(voxpos, n);
#endif

#ifdef _VoxelGI
	fragColor.rgb += envl * voxelgiEnv;
#else
	fragColor.rgb = envl;
#endif

	// Show voxels
	// vec3 origin = vec3(texCoord * 2.0 - 1.0, 0.99);
	// vec3 direction = vec3(0.0, 0.0, -1.0);
	// vec4 color = vec4(0.0f);
	// for(uint step = 0; step < 400 && color.a < 0.99f; ++step) {
	// 	vec3 point = origin + 0.005 * step * direction;
	// 	color += (1.0f - color.a) * textureLod(voxels, point * 0.5 + 0.5, 0);
	// } 
	// fragColor.rgb += color.rgb;
}
