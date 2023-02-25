#include "ColorConversion.hlsl"

Buffer<float4> TileColors : register(t0);
Buffer<float4> WallColors : register(t1);
Buffer<float4> PaintColors : register(t2);

RWTexture2D<unorm float4> PaletteVisualizationTexture : register(u0);
RWTexture3D<uint> TileWallPalette : register(u1);
RWTexture3D<uint> PaintPalette : register(u2);

float4 GetTileColor(uint type, uint paint)
{
    float4 originalTileColor = TileColors[type];
    float3 paintColor = PaintColors[paint].rgb;
    
    float3 tileColor = originalTileColor.rgb;
    float3 tileColorCopy = tileColor;
    
    if (tileColorCopy.b > tileColorCopy.r)
    {
        tileColorCopy.r = tileColorCopy.b;
    }

    if (tileColorCopy.g > tileColorCopy.r)
    {
        float temp = tileColorCopy.r;
        tileColorCopy.r = tileColorCopy.g;
        tileColorCopy.g = temp;
    }
    
    switch (paint)
    {
        case 0:
        case 31:
            break;
        case 29:
            tileColor = paintColor * tileColorCopy.g * 0.3;
            break;
        case 30:
            tileColor = 1.0 - tileColor;
            break;
        default:
            tileColor = paintColor * tileColorCopy.r;
            break;
    }
    
#ifdef LAB
    return float4(rgb2lab(tileColor), originalTileColor.a);
#else
    return float4(tileColor, originalTileColor.a);
#endif
}

float4 GetWallColor(uint type, uint paint)
{
    float4 originalWallColor = WallColors[type];
    float3 paintColor = PaintColors[paint].rgb;
    
    float3 wallColor = originalWallColor.rgb;
    float3 wallColorCopy = wallColor;
    
    if (wallColorCopy.b > wallColorCopy.r)
    {
        wallColorCopy.r = wallColorCopy.b;
    }

    if (wallColorCopy.g > wallColorCopy.r)
    {
        float temp = wallColorCopy.r;
        wallColorCopy.r = wallColorCopy.g;
        wallColorCopy.g = temp;
    }
    
    switch (paint)
    {
        case 0:
        case 31:
            break;
        case 29:
            wallColor = paintColor * wallColorCopy.g * 0.3;
            break;
        case 30:
            wallColor = (1.0 - wallColor) / 2.0;
            break;
        default:
            wallColor = paintColor * wallColorCopy.r;
            break;
    }
    
#ifdef LAB
    return float4(rgb2lab(wallColor), originalWallColor.a);
#else
    return float4(wallColor, originalWallColor.a);
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