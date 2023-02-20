#include "ColorConversion.hlsl"

RWBuffer<float4> TileColors : register(u0);
RWBuffer<float4> WallColors : register(u1);
RWBuffer<float4> PaintColors : register(u2);

RWTexture2D<unorm float4> PaletteVisualizationTexture : register(u3);
RWTexture3D<uint> TileWallPalette : register(u4);
RWTexture3D<uint> PaintPalette : register(u5);

float4 GetTileColor(uint type, uint paint)
{
    float4 tileColor = TileColors[type];
    float4 paintColor = PaintColors[paint];
    
    float num = tileColor.r;
    float num2 = tileColor.b;
    float num3 = tileColor.g;
    if (num2 > num)
    {
        float num4 = num;
        num = num2;
        num2 = num4;
    }

    if (num3 > num)
    {
        float num5 = num;
        num = num3;
        num3 = num5;
    }
    
    switch (paint)
    {
        case 0:
        case 31:
            break;
        case 29:
            {
                float num7 = num3 * 0.3f;
                tileColor.r = paintColor.r * num7;
                tileColor.g = paintColor.g * num7;
                tileColor.b = paintColor.b * num7;
            }
            break;
        case 30:
            tileColor.xyz = (1.0 - tileColor.xyz);
            break;
        default:
            {
                float num6 = num;
                tileColor.r = paintColor.r * num6;
                tileColor.g = paintColor.g * num6;
                tileColor.b = paintColor.b * num6;
            }
            break;
    }
    
#ifdef LAB
    return float4(rgb2lab(tileColor.xyz), tileColor.w);
#else
    return tileColor;
#endif
}

float4 GetWallColor(uint type, uint paint)
{
    float4 wallColor = WallColors[type];
    float4 paintColor = PaintColors[paint];
    
    float num = wallColor.r;
    float num2 = wallColor.b;
    float num3 = wallColor.g;
    if (num2 > num)
    {
        float num4 = num;
        num = num2;
        num2 = num4;
    }

    if (num3 > num)
    {
        float num5 = num;
        num = num3;
        num3 = num5;
    }
    
    switch (paint)
    {
        case 0:
        case 31:
            break;
        case 29:
            {
                float num7 = num3 * 0.3f;
                wallColor.r = paintColor.r * num7;
                wallColor.g = paintColor.g * num7;
                wallColor.b = paintColor.b * num7;
            }
            break;
        case 30:
            wallColor.xyz = (1.0 - wallColor.xyz) / 2.0;
            break;
        default:
            {
                float num6 = num;
                wallColor.r = paintColor.r * num6;
                wallColor.g = paintColor.g * num6;
                wallColor.b = paintColor.b * num6;
            }
            break;
    }
    
#ifdef LAB
    return float4(rgb2lab(wallColor.xyz), wallColor.w);
#else
    return wallColor;
#endif
}

[numthreads(32, 32, 1)]
void CSMain(uint3 id : SV_DispatchThreadID)
{
    float2 uv = id.xy / float2(4096.0, 4096.0);
    
    float4 color = float4(hsv2rgb(float3(uv.x, saturate(uv.y * 2.0), 1.0 - uv.y)), 1.0);
    
    uint3 packedColor = floor(color.xyz * 255.0);
    
    uint tileWall = TileWallPalette[packedColor];
    uint paint = PaintPalette[packedColor];
    
    uint tile = tileWall >> 16;
    uint wall = tileWall & 0xffff;
    
    float4 tileWallColor = 0;
    
    if (wall == 0xffff)
    {
        tileWallColor = GetTileColor(tile, paint);
    }
    else
    {
        tileWallColor = GetWallColor(wall, paint);
    }
    
#ifdef LAB
    color = float4(rgb2lab(color.rgb), color.a);
#endif
    
    float d = distance(tileWallColor.rgb, color.rgb);
    
    PaletteVisualizationTexture[id.xy] = float4(lerp(float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0), d * 2.0), 1.0);
}