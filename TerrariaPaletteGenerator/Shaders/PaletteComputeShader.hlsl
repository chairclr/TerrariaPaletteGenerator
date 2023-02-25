#include "ColorConversion.hlsl"

Buffer<float4> TileColors : register(t0);
Buffer<float4> WallColors : register(t1);
Buffer<float4> PaintColors : register(t2);

Buffer<uint> TilesForPixelArt : register(t3);
Buffer<uint> WallsForPixelArt : register(t4);

RWTexture3D<uint> TileWallPalette : register(u0);
RWTexture3D<uint> PaintPalette : register(u1);

cbuffer ComputeShaderBuffer : register(b0)
{
    int TilesForPixelArtLength;
    int WallsForPixelArtLength;
};

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

void GetInfoFromColor(float4 color, out uint tileType, out uint wallType, out uint paintType)
{
    uint minTile = -1;
    uint minWall = -1;
    uint minPaint = 0;
    
    float minDist = 1.#INF;

    for (int i = 0; i < TilesForPixelArtLength; i++)
    {
        uint tileType = TilesForPixelArt[i];

        for (int j = 0; j < 13; j++)
        {
            float4 tileColor = GetTileColor(tileType, j);
            
            if (tileColor.a == 0.0)
                continue;

            float d = distance(tileColor.xyz, color.xyz);

            if (d < minDist)
            {
                minDist = d;
                minTile = tileType;
                minPaint = j;
            }
        }

        for (int k = 25; k < 31; k++)
        {
            float4 tileColor = GetTileColor(tileType, k);
            
            if (tileColor.a == 0.0)
                continue;

            float d = distance(tileColor.xyz, color.xyz);

            if (d < minDist)
            {
                minDist = d;
                minTile = tileType;
                minPaint = k;
            }
        }
    }
    
    for (int l = 0; l < WallsForPixelArtLength; l++)
    {
        uint wallType = WallsForPixelArt[l];

        for (int j = 0; j < 13; j++)
        {
            float4 wallColor = GetWallColor(wallType, j);
            
            if (wallColor.a == 0.0)
                continue;

            float d = distance(wallColor.xyz, color.xyz);

            if (d < minDist)
            {
                minDist = d;
                minTile = -1;
                minWall = wallType;
                minPaint = j;
            }
        }

        for (int k = 25; k < 31; k++)
        {
            float4 wallColor = GetWallColor(wallType, k);
            
            if (wallColor.a == 0.0)
                continue;

            float d = distance(wallColor.xyz, color.xyz);

            if (d < minDist)
            {
                minDist = d;
                minTile = -1;
                minWall = wallType;
                minPaint = k;
            }
        }
    }
    
    tileType = minTile;
    wallType = minWall;
    paintType = minPaint;
}

[numthreads(10, 10, 10)]
void CSMain(uint3 id : SV_DispatchThreadID)
{
    float4 color = float4(float3(id) / 255.0, 1.0);
    
    uint tileType = 0;
    uint wallType = 0;
    uint paintType = 0;
    
#ifdef LAB
    color = float4(rgb2lab(color.xyz), 1.0);
#endif
    
    GetInfoFromColor(color, tileType, wallType, paintType);
    
    TileWallPalette[id] = (tileType << 16) | (wallType & 0xffff);
    PaintPalette[id] = paintType;
}