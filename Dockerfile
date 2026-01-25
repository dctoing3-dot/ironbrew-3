FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget curl gnupg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install .NET Core 3.1
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-3.1 dotnet-runtime-3.1 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Lua 5.1 (termasuk luac untuk compile)
RUN apt-get update && apt-get install -y \
    lua5.1 lua5.1-dev liblua5.1-0-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Build IronBrew2
RUN cd /app/IronBrew2 && dotnet restore && dotnet build -c Release

# Buat CLI wrapper
RUN dotnet new console -n CLI -o /app/CLI --framework netcoreapp3.1
RUN cd /app/CLI && dotnet add reference ../IronBrew2/IronBrew2.csproj

# Buat Program.cs untuk CLI - COMPILE LUA DULU
RUN cat > /app/CLI/Program.cs << 'EOF'
using System;
using System.IO;
using System.Diagnostics;
using IronBrew2;
using IronBrew2.Obfuscator;

namespace CLI
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.WriteLine("Usage: CLI <input.lua> <output.lua>");
                Environment.Exit(1);
            }

            try
            {
                string inputPath = args[0];
                string outputPath = args[1];
                string bytecodeFile = inputPath + ".luac";

                Console.WriteLine("Reading: " + inputPath);
                
                // Step 1: Compile Lua source to bytecode using luac
                Console.WriteLine("Compiling Lua to bytecode...");
                var luacProcess = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "luac5.1",
                        Arguments = $"-o \"{bytecodeFile}\" \"{inputPath}\"",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };
                
                luacProcess.Start();
                string luacError = luacProcess.StandardError.ReadToEnd();
                luacProcess.WaitForExit();
                
                if (luacProcess.ExitCode != 0)
                {
                    Console.WriteLine("Lua compilation failed: " + luacError);
                    Environment.Exit(1);
                }
                
                Console.WriteLine("Bytecode compiled successfully!");

                // Step 2: Read bytecode and obfuscate
                Console.WriteLine("Obfuscating with IronBrew2...");
                string bytecodeContent = File.ReadAllText(bytecodeFile);
                
                var settings = new ObfuscationSettings();
                bool success = IB2.Obfuscate(bytecodeFile, bytecodeContent, settings, out string result);

                // Cleanup temp bytecode file
                if (File.Exists(bytecodeFile))
                    File.Delete(bytecodeFile);

                if (!success)
                {
                    Console.WriteLine("Obfuscation failed: " + result);
                    Environment.Exit(1);
                }

                // IB2.Obfuscate writes to outputPath directly
                Console.WriteLine("Done! Output: " + outputPath);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error: " + ex.Message);
                Console.WriteLine(ex.StackTrace);
                Environment.Exit(1);
            }
        }
    }
}
EOF

# Build CLI
RUN cd /app/CLI && dotnet build -c Release

# Buat package.json
RUN cat > /app/package.json << 'EOF'
{
  "name": "ironbrew3-discord-bot",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "discord.js": "^14.14.1",
    "dotenv": "^16.3.1"
  }
}
EOF

# Install npm packages
RUN npm install

# Buat Discord bot
RUN cat > /app/index.js << 'EOF'
const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, AttachmentBuilder } = require("discord.js");
const { exec } = require("child_process");
const fs = require("fs");
const http = require("http");

const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent
    ]
});

client.once("ready", async () => {
    console.log(`Bot is online as ${client.user.tag}`);
    
    const commands = [
        new SlashCommandBuilder()
            .setName("obfuscate")
            .setDescription("Obfuscate Lua script with IronBrew2")
            .addAttachmentOption(opt => opt.setName("file").setDescription("Lua file").setRequired(true)),
        new SlashCommandBuilder()
            .setName("ping")
            .setDescription("Check bot latency")
    ];
    
    const rest = new REST({ version: "10" }).setToken(process.env.TOKEN);
    try {
        await rest.put(Routes.applicationCommands(client.user.id), { body: commands });
        console.log("Slash commands registered!");
    } catch (error) {
        console.error("Error registering commands:", error);
    }
});

client.on("interactionCreate", async interaction => {
    if (!interaction.isChatInputCommand()) return;
    
    if (interaction.commandName === "ping") {
        await interaction.reply(`Pong! ${client.ws.ping}ms`);
    }
    
    if (interaction.commandName === "obfuscate") {
        await interaction.deferReply();
        const attachment = interaction.options.getAttachment("file");
        
        if (!attachment.name.endsWith(".lua")) {
            return interaction.editReply("Please upload a .lua file!");
        }
        
        try {
            const response = await fetch(attachment.url);
            const luaCode = await response.text();
            const inputPath = `/tmp/input_${Date.now()}.lua`;
            const outputPath = `/tmp/output_${Date.now()}.lua`;
            
            fs.writeFileSync(inputPath, luaCode);
            
            exec(`dotnet /app/CLI/bin/Release/netcoreapp3.1/CLI.dll "${inputPath}" "${outputPath}"`,
                { timeout: 120000 },
                async (error, stdout, stderr) => {
                    console.log("STDOUT:", stdout);
                    console.log("STDERR:", stderr);
                    
                    if (fs.existsSync(outputPath)) {
                        const file = new AttachmentBuilder(outputPath, { name: "obfuscated.lua" });
                        await interaction.editReply({ 
                            content: "Obfuscation complete!", 
                            files: [file] 
                        });
                        fs.unlinkSync(inputPath);
                        fs.unlinkSync(outputPath);
                    } else {
                        const errMsg = (stderr || stdout || error?.message || "Unknown error").slice(-1500);
                        await interaction.editReply("Error:\n```\n" + errMsg + "\n```");
                        if (fs.existsSync(inputPath)) fs.unlinkSync(inputPath);
                    }
                }
            );
        } catch (error) {
            await interaction.editReply(`Error: ${error.message}`);
        }
    }
});

const server = http.createServer((req, res) => {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("OK");
});
server.listen(process.env.PORT || 8080, () => {
    console.log(`Health server on port ${process.env.PORT || 8080}`);
});

client.login(process.env.TOKEN);
EOF

# Startup script
RUN cat > /app/start.sh << 'EOF'
#!/bin/bash
echo "=== IronBrew 3 Discord Bot ==="
echo "Starting at: $(date)"

if [ -z "$TOKEN" ]; then
    echo "ERROR: TOKEN not set!"
    exit 1
fi

echo "Starting bot..."
cd /app
node index.js
EOF

RUN chmod +x /app/start.sh

EXPOSE 8080

CMD ["/app/start.sh"]
