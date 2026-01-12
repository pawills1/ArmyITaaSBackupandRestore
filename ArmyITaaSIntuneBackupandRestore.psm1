# Get the path to the Public folder
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'public'

# Dot-source each .ps1 file in the Public folder
if (Test-Path -Path $publicPath) {
    $publicFiles = Get-ChildItem -Path $publicPath -Filter '*.ps1' -File
    foreach ($file in $publicFiles) {
        try {
            . $file.FullName
        }
        catch {
            Write-Warning "Failed to import function $($file.Name): $_"
        }
    }
}
