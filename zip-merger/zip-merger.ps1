# Ask for maximum ZIP size to check
$maxSizeInput = Read-Host "Enter maximum size for individual ZIP files (in MB)"
if (-not [int]::TryParse($maxSizeInput, [ref]$null)) {
    Write-Host "Invalid input. Please enter a number."
    exit
}
$maxSizeInMB = [int]$maxSizeInput

# Ensure backup and temp directories exist
New-Item -ItemType Directory -Force -Path "./bak" | Out-Null
New-Item -ItemType Directory -Force -Path "./temp" | Out-Null

# Get all zip files under specified size and sort them by size (smallest first)
$zips = Get-ChildItem -Filter "*.zip" | 
    Where-Object { $_.Length -lt ($maxSizeInMB * 1MB) } |
    Sort-Object Length

if ($zips.Count -eq 0) {
    Write-Host "No ZIP files under $maxSizeInMB MB found."
    exit
}

# Function to create groups of zips that don't exceed 500MB total
function Group-ZipsBySize {
    param (
        [System.IO.FileInfo[]]$files
    )
    
    $groups = @()
    $currentGroup = @()
    $currentSize = 0
    
    foreach ($file in $files) {
        if (($currentSize + $file.Length) -lt (500MB)) {
            $currentGroup += $file
            $currentSize += $file.Length
        } else {
            if ($currentGroup.Count -gt 1) {  # Only add groups with more than one file
                $groups += ,@($currentGroup)
            }
            $currentGroup = @($file)
            $currentSize = $file.Length
        }
    }
    
    # Add the last group only if it has more than one file
    if ($currentGroup.Count -gt 1) {
        $groups += ,@($currentGroup)
    }
    
    return $groups
}

# Group the zip files
$groups = Group-ZipsBySize -files $zips

if ($groups.Count -eq 0) {
    Write-Host "No groups could be formed with more than one file within the size limit."
    exit
}

# Display groups and wait for confirmation
Write-Host "`nZIP File Groups:`n"
for ($i = 0; $i -lt $groups.Count; $i++) {
    Write-Host "Group $($i + 1):"
    $totalSize = 0
    foreach ($file in $groups[$i]) {
        $sizeInMB = [math]::Round($file.Length / 1MB, 2)
        Write-Host "  $($file.Name) ($sizeInMB MB)"
        $totalSize += $file.Length
    }
    $totalSizeInMB = [math]::Round($totalSize / 1MB, 2)
    Write-Host "  Total Group Size: $totalSizeInMB MB`n"
}

$confirmation = Read-Host "Press 'Y' to continue with backup and merge operations"
if ($confirmation -ne 'Y') {
    Write-Host "Operation cancelled."
    exit
}

# Backup original files
foreach ($zip in $zips) {
    $backupPath = Join-Path "./bak" "$($zip.BaseName).zip.bak"
    Copy-Item $zip.FullName -Destination $backupPath
}

# Function to merge ZIP files while maintaining DEFLATE compression
function Merge-ZipFiles {
    param (
        [System.IO.FileInfo[]]$sourceFiles,
        [string]$outputPath
    )
    
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    $tempFile = Join-Path "./temp" "merged.zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory("./temp/empty", $tempFile)
    
    $archive = [System.IO.Compression.ZipFile]::Open($tempFile, 'Update')
    
    try {
        foreach ($sourceFile in $sourceFiles) {
            $sourceArchive = [System.IO.Compression.ZipFile]::OpenRead($sourceFile.FullName)
            
            try {
                foreach ($entry in $sourceArchive.Entries) {
                    $sourceStream = $entry.Open()
                    $newEntry = $archive.CreateEntry($entry.FullName, [System.IO.Compression.CompressionLevel]::Optimal)
                    $destStream = $newEntry.Open()
                    
                    try {
                        $sourceStream.CopyTo($destStream)
                    }
                    finally {
                        $destStream.Dispose()
                        $sourceStream.Dispose()
                    }
                }
            }
            finally {
                $sourceArchive.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
    
    Move-Item -Path $tempFile -Destination $outputPath -Force
}

# Create empty directory for temporary operations
New-Item -ItemType Directory -Force -Path "./temp/empty" | Out-Null

# Get current timestamp for unique filenames
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Process each group
$filesToRemove = @()
for ($i = 0; $i -lt $groups.Count; $i++) {
    $outputFile = "merged_group_$($i + 1)_$timestamp.zip"
    Write-Host "Merging group $($i + 1) into $outputFile..."
    
    Merge-ZipFiles -sourceFiles $groups[$i] -outputPath $outputFile
    
    # Add source files to removal list
    $filesToRemove += $groups[$i]
}

# Remove original files after successful merge
foreach ($file in $filesToRemove) {
    Remove-Item -Path $file.FullName -Force
}

# Cleanup
Remove-Item -Path "./temp" -Recurse -Force

Write-Host "`nOperation completed successfully!"
