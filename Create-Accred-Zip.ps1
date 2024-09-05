param (
    [string]$SourcePath
)

# Extract the base name of the source path to use as the zip file name
$baseName = Split-Path -Path $SourcePath -Leaf
$zipFileName = "$baseName.zip"

Write-Host "Creating zip file $zipFileName from $SourcePath"

$compress = @{            
    Path = "$SourcePath\*"       
    CompressionLevel = "Fastest"
    DestinationPath = ".\$zipFileName"
}                        

Compress-Archive @compress -Force