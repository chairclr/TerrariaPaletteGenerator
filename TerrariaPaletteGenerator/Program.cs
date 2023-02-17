namespace TerrariaPaletteGenerator;

internal class Program
{
    static void Main(string[] args)
    {
        using GeneratorPlane game = new GeneratorPlane("Terraria Palette Generator");

        game.Run();
    }
}
