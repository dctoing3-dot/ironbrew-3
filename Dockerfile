# Gunakan Ubuntu 20.04 
FROM ubuntu:20.04

# Set non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies dasar
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    ca-certificates \
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

# Install Lua 5.1
RUN apt-get update && apt-get install -y \
    lua5.1 \
    lua5.1-dev \
    liblua5.1-0-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy semua file dari repository
COPY . .

# Build IronBrew2 project (path yang benar!)
RUN cd /app/IronBrew2 && dotnet restore && dotnet build -c Release

# Buat package.json untuk Discord bot
RUN echo '{\
  "name": "ironbrew3-discord-bot",\
  "version": "1.0.0",\
  "main": "index.js",\
  "dependencies": {\
    "discord.js": "^14.14.1",\
    "dotenv": "^16.3.1"\
  }\
}' > /app/package.json

# Install npm packages
RUN npm install

# Buat Discord bot (index.js) dengan path yang BENAR
RUN echo 'const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, AttachmentBuilder } = require("discord.js");\n\
const { exec } = require("child_process");\n\
const fs = require("fs");\n\
const path = require("path");\n\
const http = require("http");\n\
\n\
const client = new Client({\n\
    intents: [\n\
        GatewayIntentBits.Guilds,\n\
        GatewayIntentBits.GuildMessages,\n\
        GatewayIntentBits.MessageContent\n\
    ]\n\
});\n\
\n\
client.once("ready", async () => {\n\
    console.log(`Bot is online as ${client.user.tag}`);\n\
    \n\
    const commands = [\n\
        new SlashCommandBuilder()\n\
            .setName("obfuscate")\n\
            .setDescription("Obfuscate Lua script")\n\
            .addAttachmentOption(opt => opt.setName("file").setDescription("Lua file").setRequired(true)),\n\
        new SlashCommandBuilder()\n\
            .setName("ping")\n\
            .setDescription("Check bot latency")\n\
    ];\n\
    \n\
    const rest = new REST({ version: "10" }).setToken(process.env.TOKEN);\n\
    try {\n\
        await rest.put(Routes.applicationCommands(client.user.id), { body: commands });\n\
        console.log("Slash commands registered!");\n\
    } catch (error) {\n\
        console.error("Error registering commands:", error);\n\
    }\n\
});\n\
\n\
client.on("interactionCreate", async interaction => {\n\
    if (!interaction.isChatInputCommand()) return;\n\
    \n\
    if (interaction.commandName === "ping") {\n\
        await interaction.reply(`Pong! ${client.ws.ping}ms`);\n\
    }\n\
    \n\
    if (interaction.commandName === "obfuscate") {\n\
        await interaction.deferReply();\n\
        const attachment = interaction.options.getAttachment("file");\n\
        \n\
        if (!attachment.name.endsWith(".lua")) {\n\
            return interaction.editReply("Please upload a .lua file!");\n\
        }\n\
        \n\
        try {\n\
            const response = await fetch(attachment.url);\n\
            const luaCode = await response.text();\n\
            const inputPath = `/tmp/input_${Date.now()}.lua`;\n\
            const outputPath = `/tmp/output_${Date.now()}.lua`;\n\
            \n\
            fs.writeFileSync(inputPath, luaCode);\n\
            \n\
            exec(`cd /app/IronBrew2 && dotnet run --no-build -c Release -- "${inputPath}" "${outputPath}"`,\n\
                { cwd: "/app/IronBrew2", timeout: 120000 },\n\
                async (error, stdout, stderr) => {\n\
                    console.log("STDOUT:", stdout);\n\
                    console.log("STDERR:", stderr);\n\
                    \n\
                    if (fs.existsSync(outputPath)) {\n\
                        const file = new AttachmentBuilder(outputPath, { name: "obfuscated.lua" });\n\
                        await interaction.editReply({ content: "Obfuscation complete!", files: [file] });\n\
                        fs.unlinkSync(inputPath);\n\
                        fs.unlinkSync(outputPath);\n\
                    } else {\n\
                        const errMsg = (stderr || stdout || "Unknown error").slice(-1500);\n\
                        await interaction.editReply("Error:\\n```\\n" + errMsg + "\\n```");\n\
                        if (fs.existsSync(inputPath)) fs.unlinkSync(inputPath);\n\
                    }\n\
                }\n\
            );\n\
        } catch (error) {\n\
            await interaction.editReply(`Error: ${error.message}`);\n\
        }\n\
    }\n\
});\n\
\n\
const server = http.createServer((req, res) => {\n\
    res.writeHead(200, { "Content-Type": "text/plain" });\n\
    res.end("OK");\n\
});\n\
server.listen(process.env.PORT || 8080, () => {\n\
    console.log(`Health server on port ${process.env.PORT || 8080}`);\n\
});\n\
\n\
client.login(process.env.TOKEN);' > /app/index.js

# Buat startup script
RUN echo '#!/bin/bash\n\
echo "=== Ironbrew 3 Discord Bot ==="\n\
echo "Starting at: $(date)"\n\
\n\
if [ -z "$TOKEN" ]; then\n\
    echo "ERROR: TOKEN not set!"\n\
    echo "Set TOKEN in Render Environment Variables"\n\
    exit 1\n\
fi\n\
\n\
echo "Starting bot..."\n\
cd /app\n\
node index.js' > /app/start.sh && chmod +x /app/start.sh

EXPOSE 8080

# Start command
CMD ["/app/start.sh"]
