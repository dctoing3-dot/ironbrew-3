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

// Slash commands
const commands = [
    new SlashCommandBuilder()
        .setName('obfuscate')
        .setDescription('Obfuscate Lua script using Ironbrew 3')
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

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;

    if (interaction.commandName === 'obfuscate') {
        await interaction.deferReply();

        const attachment = interaction.options.getAttachment('file');
        
        if (!attachment.name.endsWith('.lua')) {
            return interaction.editReply('❌ Please upload a .lua file!');
        }

        try {
            // Download file
            const response = await fetch(attachment.url);
            const luaCode = await response.text();
            
            // Save to temp file
            const inputPath = path.join('/tmp', `input_${Date.now()}.lua`);
            const outputPath = path.join('/tmp', `output_${Date.now()}.lua`);
            
            fs.writeFileSync(inputPath, luaCode);

            // Run Ironbrew 3
            exec(`dotnet run --project /app -- "${inputPath}" "${outputPath}"`, 
                { cwd: '/app', timeout: 60000 },
                async (error, stdout, stderr) => {
                    if (error) {
                        console.error('Obfuscation error:', error);
                        return interaction.editReply(`❌ Error: ${stderr || error.message}`);
                    }

                    if (fs.existsSync(outputPath)) {
                        const file = new AttachmentBuilder(outputPath, { name: 'obfuscated.lua' });
                        await interaction.editReply({
                            content: '✅ Obfuscation complete!',
                            files: [file]
                        });
                        
                        // Cleanup
                        fs.unlinkSync(inputPath);
                        fs.unlinkSync(outputPath);
                    } else {
                        await interaction.editReply('❌ Obfuscation failed. No output file generated.');
                    }
                }
            );
        } catch (error) {
            console.error('Error:', error);
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
