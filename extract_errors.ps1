param (
    [string]$InputFileName = "trace_website.log"
)

# Extract the TYPE from the input file name
$Type = $InputFileName -replace '.*_(.*)\..*', '$1'

# Define the output file name
$OutputFileName = "extract_errors_$Type.txt"

# Read the log file line by line
Get-Content $InputFileName | ForEach-Object {
    # Check if the line starts with the specified pattern
    if ($_ -match "^\(D\) accreditation: \[link_to_artifact_style\]: \(ERROR\) Evidence file not found (.*)$") {
        # Extract the portion contained in parentheses
        $errormatches = [regex]::Match($_, "\(D\) accreditation: \[link_to_artifact_style\]: \(ERROR\) Evidence file not found \((.*)\)$")
        if ($errormatches.Success) {
            # Output the extracted portion
            $errormatches.Groups[1].Value
        }
    }
} | Out-File $OutputFileName

Write-Output "Parsing complete. Extracted portions saved to $OutputFileName"
