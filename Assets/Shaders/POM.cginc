// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

#pragma once

// Shamelessly derived from: 
// https://www.gamedev.net/resources/_/technical/graphics-programming-and-theory/a-closer-look-at-parallax-occlusion-mapping-r3262
// License: https://www.gamedev.net/resources/_/gdnethelp/gamedevnet-open-license-r2956

float3 GetDisplacementObjectScale()
{
    float3 objectScale = float3(1.0, 1.0, 1.0);
    float4x4 worldTransform = unity_ObjectToWorld;
    objectScale.x = length(float3(worldTransform._m00, worldTransform._m01, worldTransform._m02));
    objectScale.z = length(float3(worldTransform._m20, worldTransform._m21, worldTransform._m22));
    return objectScale;
}
//float GetOddNegativeScale()
//{
//    return unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0;
//}

// TODO: VIEW DIRECTION BREAKS WITH OBJECTS ROTATION :((

void parallax_vert(
	float4 positionWS,
	float3 normalWS,
	float4 tangentWS,
	out float3 eye,
	out float sampleRatio
) {
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

	//half4 viewDirWS = (float4(_WorldSpaceCameraPos, 1) - positionWS);
	float4x4 mW = unity_ObjectToWorld;
	
	// Need to do it this way for W-normalisation and.. stuff.
	float4 localCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
	float3 eyeLocal = positionWS - localCameraPos;
	float4 viewDirWS = mul( float4(eyeLocal, 1), mW  );

    half3x3 tangentSpaceTransform = half3x3(WorldSpaceTangent, WorldSpaceBiTangent, WorldSpaceNormal);
    half3 viewDirTS = mul(tangentSpaceTransform, viewDirWS);

    eye = viewDirTS;
	sampleRatio = 1;
	/*
	float4x4 mW = unity_ObjectToWorld;
	float3 binormal = cross( normal, tangent.xyz ) * tangent.w;
	float3 EyePosition = _WorldSpaceCameraPos;
	
	// Need to do it this way for W-normalisation and.. stuff.
	float4 localCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
	float3 eyeLocal = vertex - localCameraPos;
	float4 eyeGlobal = mul( float4(eyeLocal, 1), mW  );
	float3 E = eyeGlobal.xyz;
	
	float3x3 tangentToWorldSpace;

	tangentToWorldSpace[0] = mul( normalize( tangent ), mW );
	tangentToWorldSpace[1] = mul( normalize( binormal ), mW );
	tangentToWorldSpace[2] = mul( normalize( normal ), mW );
	
	float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);
	
	eye	= mul( E, worldToTangentSpace );
	sampleRatio = 1-dot( normalize(E), -normal );*/
}

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
}