Shader "URPPostProcess/RayMarching"
{
    Properties
    {
        [HideInInspector]_MainTex("MainTex",2D)="white"{}

        [HideInInspector]_NoiseTexture("NoiseTex",3D)="white"{}
		_shapeTilling("shapeTilling",float)=0.0

		[HideInInspector]_NoiseDetailTexture("NoiseDetailTexture",3D)="white"{}
		_detailTilling("detailTilling",float)=0.0
		_detailFBMWeights("detailFBMWeights",float)=0.0
		_detailNoiseWeight("detailNoiseWeight",float)=0.0

		[HideInInspector]_MaskNoise("MaskNoise",3D)="white"{}

		[HideInInspector]_BlueNoiseTexture("BlueNoiseTex",2D)="white"{}//解决伪影

		[HDR]_Color("Color",Color)=(1,1,1,1)
		_ColorA("ColorA",Color)=(1,1,1,1)
		_ColorB("ColorB",Color)=(1,1,1,1)

		_Blend("Blend",float)=0.0

		//精度 步长 解决伪影
		_rayOffsetStrength("rayOffsetStrength",float)=1.5
		_step("step",float)=3.5
		_rayStep("rayStep",float)=0.06

		//亮暗部color
		_lightAbsorptionTowardSun("lightAbsorptionTowardSun",float)=0.0
 		_darknessThreshold("darknessThreshold",float)=0.0
		_colorOffset1("colorOffset1",float)=0.0
		_colorOffset2("colorOffset2",float)=0.0
		
		//散射
		_phaseParams("phaseParams",vector)=(0.72,1.0,0.5,1.58) 
		
		//Weather
		[HideInInspector]_WeatherTexture("WeatherTexture",2D)="white"{}
		_shapeNoiseWeight("shapeNoiseWeight",vector)=(-0.17,27.17,-3.65,-0.08) 
		_densityOffset("densityOffset",float)=-10.9 
		_densityMultiplier("densityMultiplier",float)=1.0

		//边缘过渡距离
		_containerEdgeFadeDst("containerEdgeFadeDst",float)=60

		_heightWeights("_heightWeights",float)=0.5

		//AABB
		_boundMin("BoundMin",vector)=(0,0,0)
		_boundMax("BoundMax",vector)=(0,0,0)

		//Speed
		_Speed_xy_Wrap_zw("_Speed_xy",vector)=(0,0,0,0)
    }
    SubShader
    {
       Tags{
		"RenderPipeline"="UniversalRenderPipeline"
	   }
	   Cull Off
	   ZWrite Off
	   ZTest Always

	   HLSLINCLUDE

	   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

	   CBUFFER_START(UnityPerMaterial)
		float _Blend;
		float4 _Color;

		float _rayOffsetStrength;
		float _step;
		float _rayStep;

		float _lightAbsorptionTowardSun;
		float _lightAbsorptionTowardCloud;
		float _darknessThreshold;

		float4 _ColorA;
		float4 _ColorB;
		float _colorOffset1;
		float _colorOffset2;

		float4 _phaseParams;

		float4 _shapeNoiseWeight;
		float _densityOffset;
		float _densityMultiplier;

		float _containerEdgeFadeDst;

		float _heightWeights;

		float _shapeTilling;

		float _detailTilling;
		float _detailFBMWeights;
		float _detailNoiseWeight;

		float3 _boundMin;
		float3 _boundMax;
	
		float4x4 _InverseP;
		float4x4 _InverseV;
		
		float4 _Speed_xy_Wrap_zw;

		float4 _CameraDepthTexture_TexelSize;
	   CBUFFER_END

	   TEXTURE2D(_MainTex);
	   SAMPLER(sampler_MainTex);

	   TEXTURE2D(_CameraDepthTexture);
	   SAMPLER(sampler_CameraDepthTexture);

	   TEXTURE2D(_DownSampleDepthTexture);
	   SAMPLER(sampler_DownSampleDepthTexture);

	   TEXTURE2D(_SampleCloudColor);
	   SAMPLER(sampler_SampleCloudColor);


	   TEXTURE3D(_NoiseTexture);
	   SAMPLER(sampler_NoiseTexture);

	   TEXTURE3D(_NoiseDetailTexture);
	   SAMPLER(sampler_NoiseDetailTexture);

	   TEXTURE2D(_BlueNoiseTexture);
	   SAMPLER(sampler_BlueNoiseTexture);

	   TEXTURE2D(_WeatherTexture);
	   SAMPLER(sampler_WeatherTexture);

	   TEXTURE2D(_MaskNoise);
	   SAMPLER(sampler_MaskNoise);

	   struct Attributes{
		float4 positionOS:POSITION;
		float2 texcoord:TEXCOORD;
	   };
	   struct Varyings{
		float4 positionCS:SV_POSITION;
		float2 texcoord:TEXCOORD;
	   };
	   ENDHLSL

	   pass{
		HLSLPROGRAM
			#pragma vertex vertexShader
			#pragma fragment fragmentShader

			Varyings vertexShader(Attributes input){
				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.texcoord=input.texcoord;
				return output;
			}

			float2 RayBoxDst(float3 boundMin,float3 boundMax,float3 origin,float3 dir){
				float3 dir_rev=1/dir;			
				float3 t0=(boundMin-origin)*dir_rev;
				float3 t1=(boundMax-origin)*dir_rev;

				float3 tMin=min(t0,t1);
				float3 tMax=max(t0,t1);
				
				float dstA=max(max(tMin.x,tMin.y),tMin.z);
				float dstB=min(min(tMax.x,tMax.y),tMax.z);

				float dstBound=max(0,dstA);
				float dstInsideInBox=max(0,dstB-dstBound);
				
				return float2(dstBound,dstInsideInBox);
			}

			float4 GetWorldSpacePostion(float2 uv,float depth){
				float4 viewPos=mul(_InverseP,float4(uv*2-1,depth,1));
				viewPos.xyz/=viewPos.w;

				float4 worldPos=mul(_InverseV,float4(viewPos.xyz,1));
				return worldPos;
			}
			//RayMarching version 1.0
			float RayMarching(float3 start,float3 dir){
				float3 curPoint=start;
				float sum=0;
				dir*=0.5f;
				for(int i=0;i<256;i++){
					curPoint+=dir;
					if(curPoint.x>-10&&curPoint.x<10&&
					curPoint.y>-10&&curPoint.y<10&&
					curPoint.z>-10&&curPoint.z<10
					)
					sum+=0.02f;
				}
				return sum;
			}

			//RayMarching version 2.0
			float RayMarching(float dstLimit){
				float sum=0;
				float step=1;
				float curStep=0;

				for(int i=0;i<32;i++){
					if(curStep<dstLimit){
						curStep+=step;
						sum+=0.05f;
					}
					else
						break;
				}
				return saturate(sum);
			}

			//RayMarching version 3.0
			//Weather part
			float remap(float origin_Value,float origin_Min,float origin_Max,float new_Min,float new_Max){
				return new_Min+(((origin_Value-origin_Min)/(origin_Max-origin_Min))*(new_Max-new_Min));
			}

			float SampleDensity(float3 rayPos){
				float3 boxCenter=(_boundMin+_boundMax)*0.5;
				float3 boxSize=(_boundMax-_boundMin);

				float speedShape=_Time.y*_Speed_xy_Wrap_zw.x;
				float speedDetail=_Time.y*_Speed_xy_Wrap_zw.y;

				float3 uvwShape=rayPos*_shapeTilling+float3(speedShape,speedShape*0.3,0);
				float3 uvwDetail=rayPos*_detailTilling+float3(speedDetail,speedDetail*0.1,0.0);

				//Weather part
				float2 uv=(boxSize*0.5f+(rayPos.xz-boxCenter.xz))/max(boxSize.x,boxSize.z);
				float2 uv_Weather=uv+float2(speedShape*0.5,0);
				float2 uv_MaskNoise=uv+float2(speedShape*0.4,0);

				float4 maskNoise=SAMPLE_TEXTURE2D_LOD(_MaskNoise,sampler_MaskNoise,uv_MaskNoise,0);
				float4 weatherMap=SAMPLE_TEXTURE2D_LOD(_WeatherTexture,sampler_WeatherTexture,uv_Weather,0);

				float4 shapeNoise=SAMPLE_TEXTURE3D_LOD(_NoiseTexture,sampler_NoiseTexture,uvwShape+(maskNoise.r*_Speed_xy_Wrap_zw.z*0.1),0);
				float4 detailNoise=SAMPLE_TEXTURE3D_LOD(_NoiseDetailTexture,sampler_NoiseDetailTexture,uvwDetail+(shapeNoise.r*_Speed_xy_Wrap_zw.w*0.1),0);

				//边缘衰减
				
				float dstFromEdgeX=min(_containerEdgeFadeDst,min(rayPos.x-_boundMin.x,_boundMax.x-rayPos.x));
				float dstFromEdgeZ=min(_containerEdgeFadeDst,min(rayPos.z-_boundMin.z,_boundMax.z-rayPos.z));
				float edgeWeight=min(dstFromEdgeX,dstFromEdgeZ)/_containerEdgeFadeDst;
				
				//Weather 控制云的分布
				float gMin=remap(weatherMap.x,0,1,0.1,0.6);
				float gMax=remap(weatherMap.x,0,1,gMin,0.9);

				float heightPercent=(rayPos.y-_boundMin.y)/boxSize.y;
				
				float heightGradient=saturate(remap(heightPercent,0,gMin.r,0,1))*saturate(remap(heightPercent,1,gMax,0,1));
				float heightGradient2=saturate(remap(heightPercent,0,weatherMap.x,1,0))*saturate(remap(heightPercent,0,gMin,0,1));
				heightGradient=saturate(lerp(heightGradient,heightGradient2,_heightWeights));
				//边缘衰减
				heightGradient*=edgeWeight;

				float4 normalizeShapeWeight=_shapeNoiseWeight/dot(_shapeNoiseWeight,1);
				float shapeFBM=dot(shapeNoise,normalizeShapeWeight)*heightGradient;
				float baseShapeDensity=shapeFBM+_densityOffset*0.01;

				if(baseShapeDensity>0){
					float detailFBM=pow(detailNoise.r,_detailFBMWeights);
					float oneMinusShape=1-baseShapeDensity;
					float detailErodeWeight=oneMinusShape*oneMinusShape*oneMinusShape;
					float cloudDensity=baseShapeDensity-detailFBM*detailErodeWeight*_detailNoiseWeight;

					return saturate(cloudDensity*_densityMultiplier);
				}

				
				return baseShapeDensity;
			}
			
			float RayMarching0(float3 enter,float3 dir,float dstLimit){
				float sum=0;
				float step=0.5;
				float curStep=0;
				float3 curPoint=enter;
				float3 stepDir=dir*step;
				
				for(int i=0;i<8;i++){
					if(curStep<dstLimit){
						curStep+=step;
						curPoint+=stepDir;
						float _density=SampleDensity(curPoint);
						sum+=_density*_density*_density;
						if(sum>1)
							break;
					}
					else
						break;
				}
				return sum;
			}


			//RayMarching version 4.0
			//散射
			float hg(float a,float g){
				float g2=g*g;
				return (1-g2)/(4*3.1415*pow(1+g2-2*g*a,1.5));

			}

			float phase(float a){
				float blend=0.5f;
				float hgBlend=hg(a,_phaseParams.x)*(1-blend)+hg(a,_phaseParams.y)*blend;

				return _phaseParams.z+hgBlend*_phaseParams.w;
			}





			float3 lightMarch(float3 position,float dstTravelled){
				float3 dirToLight=_MainLightPosition.xyz;

				float dstInsideInBox=RayBoxDst(_boundMin,_boundMax,position,1/dirToLight).y;
				float stepSize=dstInsideInBox/10;
				float totalDensity=0;

				for(int step=0;step<8;step++){
					position+= dirToLight*stepSize;
					totalDensity+=max(0,SampleDensity(position)*stepSize);
				}

				float transmittance=exp(-totalDensity*_lightAbsorptionTowardSun);

				float3 cloudColor=lerp(_ColorA,_MainLightColor.xyz,saturate(transmittance*_colorOffset1));
				cloudColor=lerp(_ColorB,cloudColor,saturate(pow(transmittance*_colorOffset2,3)));

				return _darknessThreshold+transmittance*(1-_darknessThreshold)*cloudColor;
			}
			float4 RayMarching1(float3 enter,float3 dir,float dstLimit,float blueNoise){
				float3 rayPos=_WorldSpaceCameraPos;
				float sumDensity=1;
				float3 lightEnergy=0;


				float dstTravelled=blueNoise.r*_rayOffsetStrength;
				float stepSize=exp(_step)*_rayStep;

				//散射
				float cosAngle=dot(dir,_MainLightPosition.xyz);
				float3 phaseVal=phase(cosAngle);
				
				
				for(int j=0;j<512;j++)
				{
					if(dstTravelled<dstLimit)
					{
						rayPos=enter+(dir*dstTravelled);
						float _density=SampleDensity(rayPos);
						if(_density>0){
							float3 lightTransmittance = lightMarch(rayPos,dstTravelled);
							lightEnergy+=_density*stepSize*sumDensity*lightTransmittance*phaseVal;
							sumDensity*=exp(-_density*stepSize*_lightAbsorptionTowardCloud);

							if(sumDensity<0.01)
								break;
						}
					}
					dstTravelled+=stepSize;
				}
				return float4(lightEnergy,sumDensity);
			}

			float4 fragmentShader(Varyings input):SV_TARGET{	
				float4 depth=SAMPLE_DEPTH_TEXTURE(_DownSampleDepthTexture,sampler_DownSampleDepthTexture,input.texcoord);
				
				float3 worldPos=GetWorldSpacePostion(input.texcoord,depth.x).xyz;
				float3 Ray=worldPos-_WorldSpaceCameraPos;
				float3 dir=normalize(Ray);

				//Collider Box part
				float2 boxDst=RayBoxDst(_boundMin,_boundMax,_WorldSpaceCameraPos,dir);

				float dstBound=boxDst.x;
				float dstInside=boxDst.y;
				float depthLinear=length(Ray);
				float dstLimit=min(depthLinear-dstBound,dstInside);
				//float marched=RayMarching0(_WorldSpaceCameraPos+dir*dstBound,dir,dstLimit); //ver 3.0 tex+marched

				float blueNoise=SAMPLE_TEXTURE2D_LOD(_BlueNoiseTexture,sampler_BlueNoiseTexture,input.texcoord,0);

				//ver 4.0 tex*marched[Denisty+Lighting]
				float4 marched=RayMarching1(_WorldSpaceCameraPos+dir*dstBound,dir,dstLimit,blueNoise);

				//float marched=RayMarching(dstLimit); //ver 2.0 
				//float marched=RayMarching(_WorldSpaceCameraPos,dir);//ver 1.0
				//return float4(worldPos,1.0);
				return marched;
			}

		ENDHLSL
	   }

		pass{
		HLSLPROGRAM
			#pragma vertex vertexShader
			#pragma fragment DownsampleDepth	
			Varyings vertexShader(Attributes input){
				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.texcoord=input.texcoord;
				return output;
			}

			float DownsampleDepth(Varyings input):SV_TARGET{
				float2 texelSize=0.5*_CameraDepthTexture_TexelSize.xy;
				float2 UVs[4]={
					float2(input.texcoord+float2(-1,-1)*texelSize),
					float2(input.texcoord+float2(-1,1)*texelSize),
					float2(input.texcoord+float2(1,-1)*texelSize),
					float2(input.texcoord+float2(1,1)*texelSize),
				};

				float depth0=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,UVs[0]);
				float depth1=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,UVs[1]);
				float depth2=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,UVs[2]);
				float depth3=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,UVs[3]);

				return min(depth0,min(depth1,min(depth2,depth3)));
			}
		ENDHLSL
		}

		pass{
		HLSLPROGRAM
			#pragma vertex vertexShader
			#pragma fragment combineFragShader	

			Varyings vertexShader(Attributes input){
				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.texcoord=input.texcoord;
				return output;
			}

			float4 combineFragShader(Varyings input):SV_TARGET{
				float4 color=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
				float4 cloudColor=SAMPLE_TEXTURE2D(_SampleCloudColor,sampler_SampleCloudColor,input.texcoord);

				color.rgb*=cloudColor.a;
				color.rgb+=cloudColor.rgb;
				return color;
			}

		ENDHLSL
		}


    }

}
