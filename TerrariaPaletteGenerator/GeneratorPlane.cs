using System.Diagnostics;
using System.Numerics;
using System.Runtime.InteropServices;
using ImGuiNET;
using plane;
using plane.Graphics;
using plane.Graphics.Buffers;
using plane.Graphics.Shaders;
using Silk.NET.Core.Native;
using Silk.NET.Direct3D11;
using Silk.NET.DXGI;
using Plane = plane.Plane;

namespace TerrariaPaletteGenerator;

public class GeneratorPlane : Plane
{
    public ComputeShader? PaletteComputeShader;

    public UnorderedAccessBuffer<Vector4>? TileColorBuffer;

    public UnorderedAccessBuffer<Vector4>? WallColorBuffer;

    public UnorderedAccessBuffer<Vector4>? PaintColorBuffer;

    public UnorderedAccessBuffer<int>? TilesForPixelArtBuffer;

    public UnorderedAccessBuffer<int>? WallsForPixelArtBuffer;

    public ComPtr<ID3D11Texture3D> TileWallPaletteTexture = default;
    public ComPtr<ID3D11Texture3D> TileWallPaletteStagingTexture = default;
    public ComPtr<ID3D11UnorderedAccessView> TileWallPaletteUAV = default;

    public ComPtr<ID3D11Texture3D> PaintPaletteTexture = default;
    public ComPtr<ID3D11Texture3D> PaintPaletteStagingTexture = default;
    public ComPtr<ID3D11UnorderedAccessView> PaintPaletteUAV = default;

    public ConstantBuffer<GeneratorComputeShaderBuffer>? GeneratorConstantBuffer;

    private double GenerateTime = 0;

    public GeneratorPlane(string windowName)
        : base(windowName)
    {

    }

    public unsafe override void Load()
    {
        string path = Path.GetDirectoryName(typeof(GeneratorPlane).Assembly.Location)!;

        PaletteComputeShader = ShaderCompiler.CompileFromFile<ComputeShader>(Renderer!, Path.Combine(path, "Shaders", "PaletteComputeShader.hlsl"), "CSMain", ShaderModel.ComputeShader5_0);

        GeneratorConstantBuffer = new ConstantBuffer<GeneratorComputeShaderBuffer>(Renderer!);

        using FileStream tileColorFileStream = new FileStream(Path.Combine(path, "Data", "tileColorInfo.bin"), FileMode.Open);
        using BinaryReader tileColorReader = new BinaryReader(tileColorFileStream);

        Vector4[] tileColors = new Vector4[tileColorReader.ReadInt32()];
        tileColorReader.Read(MemoryMarshal.AsBytes(tileColors.AsSpan()));

        Vector4[] wallColors = new Vector4[tileColorReader.ReadInt32()];
        tileColorReader.Read(MemoryMarshal.AsBytes(wallColors.AsSpan()));

        Vector4[] paintColors = new Vector4[tileColorReader.ReadInt32()];
        tileColorReader.Read(MemoryMarshal.AsBytes(paintColors.AsSpan()));

        using FileStream validTileFileStream = new FileStream(Path.Combine(path, "Data", "validTileWallInfo.bin"), FileMode.Open);
        using BinaryReader validTileReader = new BinaryReader(validTileFileStream);

        int[] tilesForPixelArt = new int[validTileReader.ReadInt32()];
        validTileReader.Read(MemoryMarshal.AsBytes(tilesForPixelArt.AsSpan()));

        int[] wallsForPixelArt = new int[validTileReader.ReadInt32()];
        validTileReader.Read(MemoryMarshal.AsBytes(wallsForPixelArt.AsSpan()));

        GeneratorConstantBuffer.Data.TilesForPixelArtLength = tilesForPixelArt.Length;
        GeneratorConstantBuffer.Data.WallsForPixelArtLength = wallsForPixelArt.Length;

        GeneratorConstantBuffer.WriteData();

        TileColorBuffer = new UnorderedAccessBuffer<Vector4>(Renderer!, tileColors, Format.FormatR32G32B32A32Float);
        WallColorBuffer = new UnorderedAccessBuffer<Vector4>(Renderer!, wallColors, Format.FormatR32G32B32A32Float);
        PaintColorBuffer = new UnorderedAccessBuffer<Vector4>(Renderer!, paintColors, Format.FormatR32G32B32A32Float);

        TilesForPixelArtBuffer = new UnorderedAccessBuffer<int>(Renderer!, tilesForPixelArt, Format.FormatR32Uint);
        WallsForPixelArtBuffer = new UnorderedAccessBuffer<int>(Renderer!, wallsForPixelArt, Format.FormatR32Uint);

        {
            Texture3DDesc tileWallPaletteTextureDesc = new Texture3DDesc()
            {
                BindFlags = (uint)BindFlag.UnorderedAccess,
                Format = Format.FormatR32Uint,
                Usage = Usage.Default,
                MipLevels = 1,
                Width = 256,
                Height = 256,
                Depth = 256
            };

            SilkMarshal.ThrowHResult(Renderer!.Device.CreateTexture3D(tileWallPaletteTextureDesc, (SubresourceData*)null, ref TileWallPaletteTexture));

            Texture3DDesc tileWallPaletteStagingTextureDesc = new Texture3DDesc()
            {
                BindFlags = (uint)BindFlag.None,
                Format = Format.FormatR32Uint,
                Usage = Usage.Staging,
                CPUAccessFlags = (uint)CpuAccessFlag.Read,
                MipLevels = 1,
                Width = 256,
                Height = 256,
                Depth = 256
            };

            SilkMarshal.ThrowHResult(Renderer.Device.CreateTexture3D(tileWallPaletteStagingTextureDesc, (SubresourceData*)null, ref TileWallPaletteStagingTexture));

            UnorderedAccessViewDesc tileWallPaletteUAVDesc = new UnorderedAccessViewDesc()
            {
                Format = Format.FormatR32Uint,
                ViewDimension = UavDimension.Texture3D
            };

            unchecked
            {
                tileWallPaletteUAVDesc.Texture3D.WSize = (uint)-1;
            }

            SilkMarshal.ThrowHResult(Renderer!.Device.CreateUnorderedAccessView(TileWallPaletteTexture, tileWallPaletteUAVDesc, ref TileWallPaletteUAV));
        }

        {
            Texture3DDesc paintPaletteTextureDesc = new Texture3DDesc()
            {
                BindFlags = (uint)BindFlag.UnorderedAccess,
                Format = Format.FormatR8Uint,
                Usage = Usage.Default,
                MipLevels = 1,
                Width = 256,
                Height = 256,
                Depth = 256
            };

            SilkMarshal.ThrowHResult(Renderer.Device.CreateTexture3D(paintPaletteTextureDesc, (SubresourceData*)null, ref PaintPaletteTexture));

            Texture3DDesc paintPaletteStagingTextureDesc = new Texture3DDesc()
            {
                BindFlags = (uint)BindFlag.None,
                Format = Format.FormatR8Uint,
                Usage = Usage.Staging,
                CPUAccessFlags = (uint)CpuAccessFlag.Read,
                MipLevels = 1,
                Width = 256,
                Height = 256,
                Depth = 256
            };

            SilkMarshal.ThrowHResult(Renderer.Device.CreateTexture3D(paintPaletteStagingTextureDesc, (SubresourceData*)null, ref PaintPaletteStagingTexture));

            UnorderedAccessViewDesc paintPaletteUAVDesc = new UnorderedAccessViewDesc()
            {
                Format = Format.FormatR8Uint,
                ViewDimension = UavDimension.Texture3D
            };

            unchecked
            {
                paintPaletteUAVDesc.Texture3D.WSize = (uint)-1;
            }

            SilkMarshal.ThrowHResult(Renderer!.Device.CreateUnorderedAccessView(PaintPaletteTexture, paintPaletteUAVDesc, ref PaintPaletteUAV));
        }
    }

    public override void Render()
    {

    }

    public override void RenderImGui()
    {
        ImGui.Begin("Generator");

        if (ImGui.Button("Generate"))
        {
            Stopwatch stopwatch = new Stopwatch();
            stopwatch.Restart();
            PaletteComputeShader!.Bind(Renderer!);

            unsafe
            {
                TileColorBuffer!.Bind(0);
                WallColorBuffer!.Bind(1);
                PaintColorBuffer!.Bind(2);

                TilesForPixelArtBuffer!.Bind(3);
                WallsForPixelArtBuffer!.Bind(4);

                Renderer!.Context.CSSetUnorderedAccessViews(5, 1, ref TileWallPaletteUAV, (uint*)null);
                Renderer!.Context.CSSetUnorderedAccessViews(6, 1, ref PaintPaletteUAV, (uint*)null);
            }

            GeneratorConstantBuffer!.Bind(0, BindTo.ComputeShader);

            Renderer!.Context.Dispatch(16, 16, 64);

            Renderer!.Context.CopyResource(TileWallPaletteStagingTexture, TileWallPaletteTexture);
            Renderer!.Context.CopyResource(PaintPaletteStagingTexture, PaintPaletteTexture);

            using FileStream fs = new FileStream(Path.Combine(Path.GetDirectoryName(typeof(GeneratorPlane).Assembly.Location)!, "Data", "palette.bin"), FileMode.OpenOrCreate);
            using BinaryWriter writer = new BinaryWriter(fs);

            unsafe
            {
                MappedSubresource tileWallPaletteMappedSubresource = new MappedSubresource();
                SilkMarshal.ThrowHResult(Renderer.Context.Map(TileWallPaletteStagingTexture, 0, Map.Read, 0, ref tileWallPaletteMappedSubresource));

                Span<uint> data = new Span<uint>(tileWallPaletteMappedSubresource.PData, 256 * 256 * 256);
                writer.Write(MemoryMarshal.AsBytes(data));

                Renderer.Context.Unmap(TileWallPaletteStagingTexture, 0);
            }

            unsafe
            {
                MappedSubresource paintPaletteMappedSubresource = new MappedSubresource();
                SilkMarshal.ThrowHResult(Renderer.Context.Map(PaintPaletteStagingTexture, 0, Map.Read, 0, ref paintPaletteMappedSubresource));

                Span<byte> data = new Span<byte>(paintPaletteMappedSubresource.PData, 256 * 256 * 256);
                writer.Write(data);

                Renderer.Context.Unmap(PaintPaletteStagingTexture, 0);
            }

            stopwatch.Stop();
            GenerateTime = stopwatch.Elapsed.TotalSeconds;
        }

        ImGui.Text($"{GenerateTime}");

        ImGui.End();
    }
}

[StructAlign16]
public partial struct GeneratorComputeShaderBuffer
{
    public int TilesForPixelArtLength;
    public int WallsForPixelArtLength;

    public GeneratorComputeShaderBuffer()
    {
        TilesForPixelArtLength = 0;
        WallsForPixelArtLength = 0;
    }
}