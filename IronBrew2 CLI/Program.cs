using System;
using System.IO;
using IronBrew2;
using IronBrew2.Obfuscator;

namespace IronBrew2_CLI
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.WriteLine("Usage: IronBrew2 <input.lua> <output.lua>");
                Console.WriteLine("Example: IronBrew2 script.lua obfuscated.lua");
                return;
            }

            string inputPath = args[0];
            string outputPath = args[1];

            // Validasi input
            if (!File.Exists(inputPath))
            {
                Console.WriteLine($"ERR: Input file not found: {inputPath}");
                return;
            }

            // Setup temp directory
            string tempDir = "temp";
            if (Directory.Exists(tempDir))
                Directory.Delete(tempDir, true);
            Directory.CreateDirectory(tempDir);

            Console.WriteLine($"[*] Input: {inputPath}");
            Console.WriteLine($"[*] Output: {outputPath}");
            Console.WriteLine("[*] Obfuscating...");

            // Obfuscate
            if (!IB2.Obfuscate(tempDir, inputPath, new ObfuscationSettings(), out string err))
            {
                Console.WriteLine("ERR: " + err);
                return;
            }

            // Move output ke lokasi yang diminta
            string tempOutput = Path.Combine(tempDir, "out.lua");
            
            if (File.Exists(outputPath))
                File.Delete(outputPath);
            
            File.Move(tempOutput, outputPath);
            
            // Cleanup temp
            Directory.Delete(tempDir, true);

            Console.WriteLine("Done!");
            Console.WriteLine($"Output saved to: {outputPath}");
        }
    }
}
