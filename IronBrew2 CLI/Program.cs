using System;
using System.IO;
using System.Text;
using IronBrew2;
using IronBrew2.Obfuscator;

namespace IronBrew2_CLI
{
    class Program
    {
        static void Main(string[] args)
        {
            // Validasi arguments
            if (args.Length < 1)
            {
                Console.WriteLine("Usage: IronBrew2 <input.lua> [output.lua]");
                Console.WriteLine("Example: IronBrew2 script.lua");
                Console.WriteLine("Example: IronBrew2 script.lua obfuscated.lua");
                return;
            }

            string inputPath = args[0];
            string outputPath = args.Length >= 2 ? args[1] : "out.lua";

            // Validasi input file
            if (!File.Exists(inputPath))
            {
                Console.WriteLine($"ERROR: Input file not found: {inputPath}");
                Environment.Exit(1);
                return;
            }

            // Setup temp directory
            string tempDir = "temp";
            if (Directory.Exists(tempDir))
            {
                try
                {
                    Directory.Delete(tempDir, true);
                }
                catch
                {
                    // Ignore cleanup errors
                }
            }
            Directory.CreateDirectory(tempDir);

            try
            {
                Console.WriteLine($"[*] Input: {inputPath}");
                Console.WriteLine($"[*] Output: {outputPath}");
                Console.WriteLine("[*] Starting obfuscation...");

                // Jalankan IB2.Obfuscate
                if (!IB2.Obfuscate(tempDir, inputPath, new ObfuscationSettings(), out string err))
                {
                    Console.WriteLine($"ERROR: Obfuscation failed!");
                    Console.WriteLine($"Details: {err}");
                    
                    // Cleanup
                    if (Directory.Exists(tempDir))
                        Directory.Delete(tempDir, true);
                    
                    Environment.Exit(1);
                    return;
                }

                // Output dari IB2.Obfuscate ada di {tempDir}/out.lua
                string tempOutput = Path.Combine(tempDir, "out.lua");

                if (!File.Exists(tempOutput))
                {
                    Console.WriteLine("ERROR: Output file was not generated!");
                    
                    // Cleanup
                    if (Directory.Exists(tempDir))
                        Directory.Delete(tempDir, true);
                    
                    Environment.Exit(1);
                    return;
                }

                // Hapus output lama jika ada
                if (File.Exists(outputPath))
                    File.Delete(outputPath);

                // Copy/Move output ke lokasi yang diminta
                File.Copy(tempOutput, outputPath, true);

                // Cleanup temp directory
                try
                {
                    Directory.Delete(tempDir, true);
                }
                catch
                {
                    // Ignore cleanup errors
                }

                // Info hasil
                var inputInfo = new FileInfo(inputPath);
                var outputInfo = new FileInfo(outputPath);

                Console.WriteLine("[+] Obfuscation complete!");
                Console.WriteLine($"[+] Input size: {inputInfo.Length} bytes");
                Console.WriteLine($"[+] Output size: {outputInfo.Length} bytes");
                Console.WriteLine($"[+] Saved to: {outputPath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ERROR: {ex.Message}");
                Console.WriteLine(ex.StackTrace);

                // Cleanup
                try
                {
                    if (Directory.Exists(tempDir))
                        Directory.Delete(tempDir, true);
                }
                catch
                {
                    // Ignore
                }

                Environment.Exit(1);
            }
        }
    }
}
