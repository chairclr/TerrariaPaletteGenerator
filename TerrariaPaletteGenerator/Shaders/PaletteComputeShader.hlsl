#include "ColorConversion.hlsl"

RWBuffer<float4> TileColors : register(u0);
RWBuffer<float4> WallColors : register(u1);
RWBuffer<float4> PaintColors : register(u2);

RWBuffer<uint> TilesForPixelArt : register(u3);
RWBuffer<uint> WallsForPixelArt : register(u4);

RWTexture3D<uint> TileWallPalette : register(u5);
RWTexture3D<uint> PaintPalette : register(u6);

cbuffer ComputeShaderBuffer : register(b0)
{
    int TilesForPixelArtLength;
    int WallsForPixelArtLength;
};

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