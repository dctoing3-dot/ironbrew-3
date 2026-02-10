const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, AttachmentBuilder } = require('discord.js');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent
    ]
});

// Config
const MAX_FILE_SIZE = 1024 * 1024; // 1MB
const IRONBREW_PATH = '/app/IronBrew2';

// Slash commands
const commands = [
    new SlashCommandBuilder()
        .setName('obfuscate')
        .setDescription('Obfuscate Lua script using IronBrew2')
        .addAttachmentOption(option =>
            option.setName('file')
                .setDescription('Lua file to obfuscate')
                .setRequired(true))
];

// Register commands
const rest = new REST({ version: '10' }).setToken(process.env.TOKEN);

client.once('ready', async () => {
    console.log(`✅ Bot is online as ${client.user.tag}`);
    
    try {
        console.log('Registering slash commands...');
        await rest.put(
            Routes.applicationCommands(client.user.id),
            { body: commands }
        );
        console.log('✅ Slash commands registered!');
    } catch (error) {
        console.error('Error registering commands:', error);
    }
});

// Helper function untuk cleanup
function cleanup(...files) {
    files.forEach(file => {
        try {
            if (fs.existsSync(file)) {
                fs.unlinkSync(file);
            }
        } catch (e) {
            console.error(`Failed to cleanup ${file}:`, e);
        }
    });
}

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;

    if (interaction.commandName === 'obfuscate') {
        await interaction.deferReply();

        const attachment = interaction.options.getAttachment('file');
        
        // Validasi file extension
        if (!attachment.name.endsWith('.lua')) {
            return interaction.editReply('❌ Please upload a `.lua` file!');
        }

        // Validasi file size
        if (attachment.size > MAX_FILE_SIZE) {
            return interaction.editReply('❌ File too large! Maximum size is 1MB.');
        }

        const timestamp = Date.now();
        const inputPath = `/tmp/input_${timestamp}.lua`;
        const outputPath = `/tmp/output_${timestamp}.lua`;

        try {
            // Download file
            const response = await fetch(attachment.url);
            
            if (!response.ok) {
                return interaction.editReply('❌ Failed to download file.');
            }
            
            const luaCode = await response.text();
            
            // Validasi basic
            if (!luaCode.trim()) {
                return interaction.editReply('❌ File is empty!');
            }
            
            // Save to temp file
            fs.writeFileSync(inputPath, luaCode);

            // Run IronBrew2
            const command = `dotnet run --project "${IRONBREW_PATH}" -- "${inputPath}" "${outputPath}"`;
            
            exec(command, { 
                cwd: IRONBREW_PATH,
                timeout: 120000 
            }, async (error, stdout, stderr) => {
                console.log("=== IronBrew2 Output ===");
                console.log("STDOUT:", stdout);
                if (stderr) console.log("STDERR:", stderr);
                
                try {
                    if (error) {
                        console.error('Obfuscation error:', error);
                        cleanup(inputPath, outputPath);
                        return interaction.editReply(`❌ Obfuscation failed!\n\`\`\`\n${stderr || error.message}\n\`\`\``);
                    }

                    if (fs.existsSync(outputPath)) {
                        const outputStats = fs.statSync(outputPath);
                        
                        if (outputStats.size === 0) {
                            cleanup(inputPath, outputPath);
                            return interaction.editReply('❌ Obfuscation failed. Output file is empty.');
                        }

                        const file = new AttachmentBuilder(outputPath, { 
                            name: `obfuscated_${attachment.name}` 
                        });
                        
                        await interaction.editReply({
                            content: `✅ **Obfuscation complete!**\n📁 Original: \`${attachment.name}\` (${attachment.size} bytes)\n📦 Output: \`obfuscated_${attachment.name}\` (${outputStats.size} bytes)`,
                            files: [file]
                        });
                        
                        cleanup(inputPath, outputPath);
                    } else {
                        cleanup(inputPath, outputPath);
                        await interaction.editReply(`❌ Obfuscation failed.\n\`\`\`\n${stdout}\n\`\`\``);
                    }
                } catch (replyError) {
                    console.error('Reply error:', replyError);
                    cleanup(inputPath, outputPath);
                }
            });
        } catch (error) {
            console.error('Error:', error);
            cleanup(inputPath, outputPath);
            await interaction.editReply(`❌ Error: ${error.message}`);
        }
    }
});

// Health check server untuk Render
const http = require('http');
const server = http.createServer((req, res) => {
    if (req.url === '/health' || req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('OK');
    }
});

server.listen(process.env.PORT || 8080, () => {
    console.log(`Health check server running on port ${process.env.PORT || 8080}`);
});

// Login bot
client.login(process.env.TOKEN);
