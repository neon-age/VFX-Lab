

// other resources:
// https://github.com/KaimaChen/Unity-Shader-Demo

/*
float3 GetDisplacementObjectScale()
{
    float3 objectScale = float3(1.0, 1.0, 1.0);
    float4x4 worldTransform = unity_ObjectToWorld;
    objectScale.x = length(float3(worldTransform._m00, worldTransform._m01, worldTransform._m02));
    objectScale.z = length(float3(worldTransform._m20, worldTransform._m21, worldTransform._m22));
    return objectScale;
}
half3 ObjectScale() {
	float3 scale = float3(
	    length(unity_ObjectToWorld._m00_m10_m20),
	    length(unity_ObjectToWorld._m01_m11_m21),
	    length(unity_ObjectToWorld._m02_m12_m22)
	);
}*/
//float GetOddNegativeScale()
//{
//    return unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0;
//}

/*
// URP version
// Return view direction in tangent space, make sure tangentWS.w is already multiplied by GetOddNegativeScale()
half3 GetViewDirectionTangentSpace(half4 tangentWS, half3 normalWS, half3 viewDirWS)
{
    // must use interpolated tangent, bitangent and normal before they are normalized in the pixel shader.
    half3 unnormalizedNormalWS = normalWS;
    const half renormFactor = 1.0 / length(unnormalizedNormalWS);

    // use bitangent on the fly like in hdrp
    // IMPORTANT! If we ever support Flip on double sided materials ensure bitangent and tangent are NOT flipped.
    half crossSign = (tangentWS.w > 0.0 ? 1.0 : -1.0); // we do not need to multiple GetOddNegativeScale() here, as it is done in vertex shader
    half3 bitang = crossSign * cross(normalWS.xyz, tangentWS.xyz);

    half3 WorldSpaceNormal = renormFactor * normalWS.xyz;       // we want a unit length Normal Vector node in shader graph

    // to preserve mikktspace compliance we use same scale renormFactor as was used on the normal.
    // This is explained in section 2.2 in "surface gradient based bump mapping framework"
    half3 WorldSpaceTangent = renormFactor * tangentWS.xyz;
    half3 WorldSpaceBiTangent = renormFactor * bitang;

    half3x3 tangentSpaceTransform = half3x3(WorldSpaceTangent, WorldSpaceBiTangent, WorldSpaceNormal);
    half3 viewDirTS = mul(tangentSpaceTransform, viewDirWS);

    return viewDirTS;
}
*/


float2 parallax_offset (
	float fHeightMapScale,
	float3 eye,
	float sampleRatio,
	float2 texcoord,
	sampler2D heightMap,
	int nMinSamples,
	int nMaxSamples,
	out float sampledHeight
) {
	
	/*
	///// secant method /////
	this portion of code requires a linear search to first be performed, with the two points right before and right after collision stored as the upper and lower variables
	pixel_color.a = 1;
	float int_depth = 0;
	
	for(int i = 0; (i < 10) && (abs(pixel_color.a - int_depth) > .01); i++)
	{
		float line_slope = (upper_h - lower_h) / (upper_d - lower_d);
		float line_inter = upper_h - line_slope * upper_d;
	
		float dem = view_slope - line_slope;
		float inter_pt = line_inter / dem;
	
		tex_coords_offset2D = inter_pt * float2(view_vec.y, -view_vec.x);
		int_depth = view_slope * inter_pt;
		pixel_color = tex2D(heightSampler,(tex_coords_offset2D)+input.tex_coords);
	
		if(pixel_color.a < int_depth) //new upper bound
		{
			upper_h = pixel_color.a;
			upper_d = inter_pt;
			best_depth = upper_h;
		}
		else //new lower bound
		{
			lower_h = pixel_color.a;
			lower_d = inter_pt;
			best_depth = lower_h;
		}
	}
	// compute our final texture offset
	tex_coords_offset2D = ((1.0f/view_slope)*best_depth)*float2(view_vec.y,-view_vec.x);
	
	// store pixel color
	pixel_color = tex2D(textureSampler, tex_coords_offset2D+input.tex_coords);*/

	// Shamelessly derived from: 
// https://www.gamedev.net/resources/_/technical/graphics-programming-and-theory/a-closer-look-at-parallax-occlusion-mapping-r3262
// License: https://www.gamedev.net/resources/_/gdnethelp/gamedevnet-open-license-r2956
	/*
	float fParallaxLimit = -length( eye.xy ) / eye.z;
	fParallaxLimit *= fHeightMapScale;
	
	float2 vOffsetDir = normalize( eye.xy );
	float2 vMaxOffset = vOffsetDir * fParallaxLimit;
	
	int nNumSamples = (int)lerp( nMinSamples, nMaxSamples, saturate(sampleRatio) );
	
	float fStepSize = 1.0 / (float)nNumSamples;
	
	float2 dx = ddx( texcoord );
	float2 dy = ddy( texcoord );
	
	float fCurrRayHeight = 1.0;
	float2 vCurrOffset = float2( 0, 0 );
	float2 vLastOffset = float2( 0, 0 );

	float fLastSampledHeight = 1;
	float fCurrSampledHeight = 1;

	int nCurrSample = 0;
	
	for (float i = 0; i < min(nNumSamples, 16); i++)
	{
	  fCurrSampledHeight = GetPOMHeight(texcoord + vCurrOffset); //lerp(0, tex2Dlod(heightMap, float4(texcoord + vCurrOffset, mipBias, mipBias) ).r  * heightMidPoint.y, heightMidPoint.x) *  heightMidPoint.z;
	  if ( fCurrSampledHeight > fCurrRayHeight )
	  {
		float delta1 = fCurrSampledHeight - fCurrRayHeight;
		float delta2 = ( fCurrRayHeight + fStepSize ) - fLastSampledHeight;

		float ratio = delta1/(delta1+delta2);

		vCurrOffset = (ratio) * vLastOffset + (1.0-ratio) * vCurrOffset;

		nCurrSample = nNumSamples + 1;
		break;
	  }
	  else
	  {
		nCurrSample++;

		fCurrRayHeight -= fStepSize;

		vLastOffset = vCurrOffset;
		vCurrOffset += fStepSize * vMaxOffset;

		fLastSampledHeight = fCurrSampledHeight;
	  }
	}
	sampledHeight = fLastSampledHeight;
	return vCurrOffset;
	*/
	
	// slightly modified version
	
	float fParallaxLimit = -length( eye.xy ) / eye.z;
	//fParallaxLimit = (eye.xy / -eye.z);
	fParallaxLimit *= fHeightMapScale;

	int nNumSamples = (int)min(64, lerp( nMinSamples, nMaxSamples, saturate(sampleRatio) ));
	float fStepSize = 1.0 / (float)nNumSamples;
	
	float2 vOffsetDir = normalize( eye.xy );
	float2 vMaxOffset = vOffsetDir * fParallaxLimit;
	float2 vStepOffset = fStepSize * vMaxOffset;
	
	
	float2 dx = ddx( texcoord );
	float2 dy = ddy( texcoord );
	
	float fCurrRayHeight = 1.0 - fStepSize;
	float2 vCurrOffset = float2( 0, 0 );
	float2 vLastOffset = float2( 0, 0 );

	float fLastSampledHeight = GetPOMHeight(texcoord);
	vCurrOffset += vStepOffset;
	float fCurrSampledHeight = GetPOMHeight(texcoord + vCurrOffset);

	int nCurrSample = 0;
	
	for (float i = 1; i < nNumSamples && fCurrSampledHeight < fCurrRayHeight; i++)
	{
		//if (fCurrSampledHeight > fCurrRayHeight)
		//	break;
		nCurrSample++;

		fCurrRayHeight -= fStepSize;

		vLastOffset = vCurrOffset;
		vCurrOffset += vStepOffset;

		fLastSampledHeight = fCurrSampledHeight;
		fCurrSampledHeight = GetPOMHeight(texcoord + vCurrOffset); //lerp(0, tex2Dlod(heightMap, float4(texcoord + vCurrOffset, mipBias, mipBias) ).r  * heightMidPoint.y, heightMidPoint.x) *  heightMidPoint.z;

	}
	sampledHeight = fLastSampledHeight;

	float delta1 = fCurrSampledHeight - fCurrRayHeight;
	float delta2 = ( fCurrRayHeight + fStepSize ) - fLastSampledHeight;

	float ratio = delta1/(delta1+delta2);
	
	vCurrOffset = vCurrOffset - vStepOffset * ratio;
	//vCurrOffset = (ratio) * vLastOffset + (1.0-ratio) * vCurrOffset;

	nCurrSample = nNumSamples + 1;
	return vCurrOffset;


	// https://catlikecoding.com/unity/tutorials/rendering/part-20/
	float3 viewDir = normalize(eye);
	#define PARALLAX_BIAS 0
	viewDir.xy /= (viewDir.z + PARALLAX_BIAS);

	float2 viewOffset = (viewDir.xy);
	/*
	

	#define PARALLAX_FUNCTION ParallaxRaymarching

	float2 uvOffset = PARALLAX_FUNCTION(fHeightMapScale, texcoord.xy, eye.xy, sampledHeight);
	return uvOffset;*/

	//#if !defined(PARALLAX_RAYMARCHING_STEPS)
	#define PARALLAX_RAYMARCHING_STEPS nMaxSamples
	//#endif
	float2 uvOffset = 0;
	float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;
	float2 uvDelta = viewOffset * (stepSize * fHeightMapScale);

	float stepHeight = 1;
	float surfaceHeight = GetPOMHeight(texcoord);

	float2 prevUVOffset = uvOffset;
	float prevStepHeight = stepHeight;
	float prevSurfaceHeight = surfaceHeight;

	for (
		int i = 1;
		i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight;
		i++
	) {
		prevUVOffset = uvOffset;
		prevStepHeight = stepHeight;
		prevSurfaceHeight = surfaceHeight;
		
		uvOffset -= uvDelta;
		stepHeight -= stepSize;
		surfaceHeight = GetPOMHeight(texcoord + uvOffset);
	}

	//#if !defined(PARALLAX_RAYMARCHING_SEARCH_STEPS)
	/*
		#define PARALLAX_RAYMARCHING_SEARCH_STEPS 3
	//#endif
	//#if PARALLAX_RAYMARCHING_SEARCH_STEPS > 0
	
		for (int i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEPS; i++) {
			uvDelta *= 0.5;
			stepSize *= 0.5;

			if (stepHeight < surfaceHeight) {
				uvOffset += uvDelta;
				stepHeight += stepSize;
			}
			else {
				uvOffset -= uvDelta;
				stepHeight -= stepSize;
			}
			surfaceHeight = GetPOMHeight(texcoord + uvOffset);
		}*/
	// PARALLAX_RAYMARCHING_INTERPOLATE
	/*
	real delta0 = currHeight - rayHeight;
    real delta1 = (rayHeight + stepSize) - prevHeight;
    real ratio = delta0 / (delta0 + delta1);
    real2 offset = texOffsetCurrent - ratio * texOffsetPerStep;
	*/
	
	float d0 = prevStepHeight - prevSurfaceHeight;
	float d1 = surfaceHeight - stepHeight;
	float t = d0 / (d0 + d1);
	uvOffset = uvOffset - uvDelta * t;
	
   /*
	float delta0 = surfaceHeight - stepHeight;
	float delta1 = (stepHeight + stepSize) - prevSurfaceHeight;
    float ratio = delta0 / (delta0 + delta1);
    uvOffset = uvOffset - uvDelta * ratio;*/
	//#endif

	sampledHeight = saturate(prevSurfaceHeight);
	return uvOffset;

	//i.uv.xy += uvOffset;
	//i.uv.zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy);
}

		


void parallax_vert(
	float3 positionWS,
	float3 normalWS,
	float4 tangentWS,
	out float3 eye,
	out float sampleRatio
) {
	/*
	 // must use interpolated tangent, bitangent and normal before they are normalized in the pixel shader.
    half3 unnormalizedNormalWS = normalWS;
    const half renormFactor = 1.0 / length(unnormalizedNormalWS);

    // use bitangent on the fly like in hdrp
    // IMPORTANT! If we ever support Flip on double sided materials ensure bitangent and tangent are NOT flipped.
    half crossSign = (tangentWS.w > 0.0 ? 1.0 : -1.0); // we do not need to multiple GetOddNegativeScale() here, as it is done in vertex shader
    half3 bitang = crossSign * cross(normalWS.xyz, tangentWS.xyz);

    half3 WorldSpaceNormal = renormFactor * normalWS.xyz;       // we want a unit length Normal Vector node in shader graph

    // to preserve mikktspace compliance we use same scale renormFactor as was used on the normal.
    // This is explained in section 2.2 in "surface gradient based bump mapping framework"
    half3 WorldSpaceTangent = renormFactor * tangentWS.xyz;
    half3 WorldSpaceBiTangent = renormFactor * bitang;

	float4x4 mW = unity_ObjectToWorld;
	// Need to do it this way for W-normalisation and.. stuff.
	float4 localCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
	float3 eyeLocal = positionWS - localCameraPos;
	float4 eyeGlobal = mul( float4(eyeLocal, 1), mW  );
	float3 viewDirWS = eyeGlobal.xyz;

	//float3 viewDirWS = positionWS - _WorldSpaceCameraPos;

    half3x3 tangentSpaceTransform = half3x3(WorldSpaceTangent, WorldSpaceBiTangent, WorldSpaceNormal);
    half3 viewDirTS = mul(tangentSpaceTransform, viewDirWS);

	eye	= viewDirWS;
	sampleRatio = 1;*/

	
	float4x4 mW = unity_ObjectToWorld;
	float3 binormal = cross( normalWS, tangentWS.xyz ) * tangentWS.w;
	float3 EyePosition = _WorldSpaceCameraPos;
	
	// Need to do it this way for W-normalisation and.. stuff.
	float4 localCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
	float3 eyeLocal = localCameraPos - positionWS;
	float3 eyeGlobal = mul( eyeLocal, mW );
	
	float3x3 tangentToWorldSpace;

	tangentToWorldSpace[0] = mul( normalize( tangentWS ), mW );
	tangentToWorldSpace[1] = mul( normalize( binormal ), mW );
	tangentToWorldSpace[2] = mul( normalize( normalWS ), mW );
	
	float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);
	
	eye	= mul( eyeGlobal, worldToTangentSpace );
	//eye /= ObjectScale().xzy;
	//sampleRatio = 1-dot( normalize(eyeGlobal), -normalWS );
	sampleRatio = 1;
}