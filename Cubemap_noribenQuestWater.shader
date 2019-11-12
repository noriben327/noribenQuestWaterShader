Shader "Noriben/noribenQuestWaterCubemap"
{
	Properties
	{	
		[Header(Color)]
		_Color ("MainColor", Color) = (0.1, 0.2, 0.3, 1)
		_Transparency ("Transparency", Range(0, 1)) = 0.8

		[Space]
		[Header(Texture)]
		[Normal]_MainTex ("NormalWaveTexture", 2D) = "white" {}
		[NoScaleOffset]_HeightTex ("HeightTexture", 2D) = "white" {} //_MainTexとUVは同一なのでNoScaleOffset
		_EnvMap ("EnvCubeMap", Cube) = "white"{}

		[Space]
		[Header(Wave)]
		_WaveScale ("WaveScale", Range(0, 3)) = 1
		_NormalPower ("WaveNormalPower", Range(0, 1)) = 0.2
		_WaveHeight ("WaveHeight", Range(0, 5)) = 0.1

		[Space]
		[Header(Reflection)]
		_Reflection ("Reflection", Range(0, 10)) = 1
		[Enum(Sky, 0, Gound, 1)] _RefMode ("ReflectionMode", Int) = 0

		[Space]
		[Header(Scroll)]
		[PowerSlider(2)]_Scrollx ("Scroll_X" , Range(-0.5, 0.5)) = 0.01
		[PowerSlider(2)]_Scrolly ("Scroll_Y" , Range(-0.5, 0.5)) = 0

		[Space]
		[Header(Lighting)]
		_Fresnel ("Fresnel", Range(0, 1)) = 0.5
		_Diffuse ("Diffuse", Range(0, 1)) = 1
		_Specular ("Specular", Range(0, 3)) = 0.3

		[Space]
		[Header(Cull Mode)]
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2

	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
		LOD 100
		Cull [_Cull]
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				half3 normal : NORMAL;
				half4 tangent : TANGENT;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 worldPos : TEXCOORD2;
				half3 normal : TEXCOORD3;
				half3 lightDir : TEXCOORD4;
				half3 viewDir : TEXCOORD5;
			};

			fixed4 _Color;
			fixed4 _LightColor0;
			sampler2D _MainTex;
			sampler2D _HeightTex;
			samplerCUBE _EnvMap;
			float4 _MainTex_ST;
			fixed _Specular;
			fixed _Reflection;
			fixed _Transparency;
			fixed _NormalPower;
			fixed _WaveHeight;
			fixed _Diffuse;
			half _Scrollx;
			half _Scrolly;
			fixed _Fresnel;
			int _RefMode;
			fixed _WaveScale;
			
			v2f vert (appdata v)
			{
				v2f o;

				o.normal = UnityObjectToWorldNormal(v.normal);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				//uvスケール
				o.uv *= _WaveScale;
				
				//テクスチャで頂点移動
				half4 heighttex = tex2Dlod(_HeightTex, half4(half2(o.uv.x + _Time.y * _Scrollx, o.uv.y + _Time.y * _Scrolly), 0, 0));
				v.vertex.xyz = v.vertex.xyz + heighttex.xyz * v.normal * _WaveHeight;

				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				TANGENT_SPACE_ROTATION;
				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
				o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));

				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{	
				//uvスケール
				i.uv *= _WaveScale;

				//ノーマルマップ
				half3 normalmap = UnpackNormal(tex2D(_MainTex, half2(i.uv.x + _Time.y * _Scrollx, i.uv.y + _Time.y * _Scrolly)));
				normalmap = normalize(normalmap);
				normalmap = lerp(float3(0,0,1), normalmap, _NormalPower);

				//環境マップ
				i.normal = normalize(i.normal);
				i.lightDir = normalize(i.lightDir);
                half3 cubeviewDir = normalize(_WorldSpaceCameraPos - i.worldPos); //cubemap用のviewDir
				half3 viewDir = normalize(i.viewDir);
                half3 refDir = reflect(-cubeviewDir, normalmap);
				//キューブマップの空の方向の色を使う
				half3 refDirsky = refDir;
				refDirsky.y *= refDirsky.y < 0 ? -1 : 1;
				//リフレクションの方向の切り替え
				refDir = lerp(refDirsky, refDir, _RefMode);
                // キューブマップと反射方向のベクトルから反射先の色を取得する
                half4 refColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refDir, 0);

				//Custom Cube map
				half4 cubemap = texCUBE(_EnvMap, refDir);
				refColor = cubemap;

				//フレネル反射
				half fresnelColor = pow(1.0 - max(0, dot(normalmap, viewDir)), _Fresnel);
				fresnelColor = lerp(fresnelColor, 1, 0.4);
				
				//ライティング
				half3 halfDir = normalize(i.lightDir + viewDir);
				half3 diffuse = max(0, dot(normalmap, i.lightDir)) * _LightColor0.rgb;
				half3 specular = pow(max(0, dot(normalmap, halfDir)), 128.0) * _LightColor0.rgb;

				//mix
				fixed4 col = _Color;
				col.rgb = col.rgb * diffuse * _Diffuse + refColor.rgb * _Reflection + specular * _Specular;
				col.rgb *= half3(fresnelColor, fresnelColor, fresnelColor);
				col = saturate(col);
				col = fixed4(fixed3(col.xyz), _Transparency);

				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
