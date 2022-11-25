function Get-BuildLogDelays {
    $workingDir = "$env:HOMEPATH/Downloads/4478856"
    $outputFileName = "$workingDir/output.log"
    $logFilePaths = @(
        "$workingDir/msbuild/msbuild.log"
        "$workingDir/dotnet/dotnet.log"
    )

    $minDelaySec = 2
    $DebugPreference = "Continue" # "SilentlyContinue|Continue"

    if (Test-Path $outputFileName) {
        Remove-Item $outputFileName
    }

    foreach ($logFile in $logFilePaths)  {
        "`n`n" + "Analyzing log file " + $logFile.Split("/")[-1] + "`n" >> $outputFileName
        Write-Debug "Analyzing file $logFile..."

        $logFileContent = Get-Content $logFile
        $logLineCount = $logFileContent.Length
        $fileProgressPercentage = 0;

        $delayCount = 0
        [TimeSpan]$cummulativeDelay = [TimeSpan]::FromMilliseconds(0)

        $currentLineIndex = 0
        $nextLineIndex = 1
        while ($currentLineIndex -lt $logLineCount - 1) {
            if ((($currentLineIndex + 1) % [Math]::Round($logLineCount / 10)) -eq 0) {
                $fileProgressPercentage += 10;
                Write-Debug "File is ${fileProgressPercentage}% processed."
            }

            $currentLine = $logFileContent[$currentLineIndex]
            $nextLine = $logFileContent[$nextLineIndex]
            
            try {
                [DateTime]$currentLineTime = Get-LineTime $currentLine
            }
            catch {
                Write-Debug "Could not `$currentLineTime. Reason: '$_'"
                $currentLineIndex++
                $nextLineIndex++
                continue
            }

            try {
                [DateTime]$nextLineTime = Get-LineTime $nextLine
            }
            catch {
                $nextLineIndex++
                continue
            }

            $timeDiff = Get-TimeDifference $currentLineTime $nextLineTime
            $delaySec = $timeDiff.TotalSeconds
            if ($delaySec -ge $minDelaySec) { 
                $delayCount++
                $cummulativeDelay += $timeDiff

                $currentLine >> $outputFileName
                ">>> Delay $delaySec s <<<" >> $outputFileName
                $nextLine >> $outputFileName
                "" >> $outputFileName
            }

            $currentLineIndex++
            $nextLineIndex++
        }

        "`n" + "Done analyzing log file " + $logFile.Split("/")[-1] >> $outputFileName
        "Total delays of $minDelaySec s or more: $delayCount" >> $outputFileName
        "Cummulative delay: $cummulativeDelay" + "`n" >> $outputFileName
    }
}

function Get-LineTime {
    param (
        [Parameter(Position = 0)]
        [string]
        $logLine
    )

    $timeStampPattern = "^\[(?<content>.*?)\].:" # non-greedy match whatever is inside the []  at the start of the line
    if ($logLine -notmatch $timeStampPattern ) {
        Write-Debug "Couldn't find a timestamp in log line: $logLine"
        throw "Log line doesn't contain a timestamp"
    }

    $timestampString = $matches['content']
    [DateTime]$timestamp = [Datetime]::ParseExact($timestampString, "HH:mm:ss", $null)
    return $timestamp
}

function Get-TimeDifference {
    param (
        [Parameter(Position = 0)]
        [DateTime]
        $currentLineTime,
        [Parameter(Position = 1)]
        [DateTime]
        $nextLineTime
    )

    [TimeSpan]$timespan = $nextLineTime - $currentLineTime
    if ($timespan.TotalMilliseconds -lt 0) {
        $timespan = $timespan.Negate()
    }
    return $timespan
}

Get-BuildLogDelays