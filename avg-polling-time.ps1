$logsFolder = "C:\Users\Anatoly.Cherenkov\Downloads\4198374\VCSNodeLogs"
$vcsRootCount = 3052
$pollerThreadCount = 50

# Global Variables
$pollingAttempts = [System.Collections.ArrayList]::new()
[TimeSpan]$totalTime = [TimeSpan]::FromMilliseconds(0)
[Int32]$global:finishedPollCount = 0
[Int32]$global:successfulPollCount = 0
[Int32]$global:errorPollCount = 0

function Get-PollingDuration {
    param (
        [Parameter(Position=0)]
        [string]
        $InputLogLine
    )

    if ($InputLogLine -notmatch ", total time: (?<content>.*), persisting time: ")
    {
        return "Log line doesn't contain polling duration"
    }

    $timeString = $matches['content']
    $timeStringArray = $timeString -split ","

    $timespan = [TimeSpan]::FromMilliseconds(0)

    foreach ($element in $timeStringArray)
    {
        $amount = ($element -split '\D')[0]
        $units = ($element -split '\d')[-1]

        if ($units -eq "h")
        {
            $timespan = $timespan.Add([TimeSpan]::FromHours($amount))
        }
        elseif ($units -eq "m")
        {
            $timespan = $timespan.Add([TimeSpan]::FromMinutes($amount))
        }
        elseif ($units -eq "s")
        {
            $timespan = $timespan.Add([TimeSpan]::FromSeconds($amount))
        }
        elseif ($units -eq "ms")
        {
            $timespan = $timespan.Add([TimeSpan]::FromMilliseconds($amount))
        }
        else
        {
            throw "Couldn't split element for number and string: $element"
        }
    }

    return $timeSpan
}

function Get-VcsRootName {
    param (
        [Parameter(Position = 0)]
        [string]
        $InputLogLine
    )

    if ($InputLogLine -notmatch 'Finish collecting changes (successfully|with errors) (for|from) VCS root "(?<content>.*?)" {instance id=')
    {
        throw "Log line doesn't contain a VCS name: $InputLogLine"
    }

    return $matches['content']
}

function Get-VcsRootId {
    param (
        [Parameter(Position = 0)]
        [string]
        $InputLogLine
    )

    if ($InputLogLine -notmatch 'Finish collecting changes (successfully|with errors) (for|from) VCS root .*? parent id=(?<content>.*?), description')
    {
        throw "Log line doesn't contain a VCS name: $InputLogLine"
    }

    return $matches['content']
}

function Get-PollingTime {
    param (
        [Parameter(Position = 0)]
        [string]
        $InputLogLine
    )

    if ($InputLogLine -notmatch "\[(?<content>.*)\]   INFO \[")
    {
        return "Log line doesn't contain polling time"
    }

    $timeString = $matches['content']
    [DateTime]$timestamp = [Datetime]::ParseExact($timeString, 'yyyy-MM-dd HH:mm:ss,fff', $null)
    return $timestamp
}

function Get-PollingStatus {
    param (
        [Parameter(Position = 0)]
        [string]
        $InputLogLine
    )

    if ($InputLogLine -notmatch 'Finish collecting changes (?<content>.*?) (for|from) VCS root')
    {
        throw "Log line doesn't contain a 'successfully' or 'with errors' status: $InputLogLine"
    }
    
    $statusString = $Matches['content']
    if ($statusString -eq "successfully") {
        return [PollingStatus].GetEnumValues()[0]
    } else {
        return [PollingStatus].GetEnumValues()[1]
    }
}

enum PollingStatus {
    successful = 0
    withErrors = 1
}

class PollingAttempt
{
    [ValidateNotNullOrEmpty()][DateTime]$Time
    [ValidateNotNullOrEmpty()][PollingStatus]$Status
    [ValidateNotNullOrEmpty()][string]$VcsRootName
    [ValidateNotNullOrEmpty()][string]$VcsRootId
    [ValidateNotNullOrEmpty()][TimeSpan]$Duration
    [ValidateNotNullOrEmpty()][string]$RawLogLine
    
    PollingAttempt($Time, $Status, $VcsRootName, $VcsRootId, $Duration, $RawLogLine) {
        $this.Time = $Time
        $this.Status = $Status
        $this.VcsRootName = $VcsRootName
        $this.VcsRootId = $VcsRootId
        $this.Duration = $Duration
        $this.RawLogLine = $RawLogLine
    }
}

function Update-PollingCounts {
    param (
        [Parameter(Position = 0)]
        [PollingStatus]
        $Status
    )
    
    $argumentType = $Status.GetType().Name
    if ($argumentType -ne "PollingStatus") {
        throw "Type of arguemnt '$Status' is not a [PollingStatus]. Argument type is '$argumentType'"
    }

    $global:finishedPollCount++
    if ($Status -eq [PollingStatus].GetEnumValues()[0]) {
        $global:successfulPollCount++
    } elseif ($Status -eq [PollingStatus].GetEnumValues()[1]) {
        $global:errorPollCount++
    } else {
        throw "Unknown status '$Status'. Expected 'successful' or 'withErrors'"
    }
}

# Calculate and show stats
foreach ($line in Get-Content $logsFolder/teamcity-vcs.log*) {
    $currentPollDuration = Get-PollingDuration $line
    
    if ($currentPollDuration.GetType().Name -eq "TimeSpan") {
        $totalTime = $totalTime.Add($currentPollDuration)
        $status = Get-PollingStatus $line
        Update-PollingCounts $status
        $time = Get-PollingTime $line
        $vcsRootName = Get-VcsRootName $line
        $vcsRootId = Get-VcsRootId $line
        $currentPollingAttempt = [PollingAttempt]::new(
            $time,
            $status,
            $vcsRootName, 
            $vcsRootId,
            $currentPollDuration,
            $line
        )
        $pollingAttempts += $currentPollingAttempt
    }
}
    
## Show general statistics
[TimeSpan]$avgPollTime = $totalTime / $finishedPollCount
[TimeSpan]$suggestedPollingInterval = $avgPollTime * $vcsRootCount / $pollerThreadCount

"Total time spent in finished polls: $totalTime"
"Finished polls: $global:finishedPollCount ($global:successfulPollCount successful / $global:errorPollCount with errors)"
"Average polling time: $avgPollTime"
"It will take $suggestedPollingInterval to poll $vcsRootCount VCS Roots in $pollerThreadCount threads"

## Show longest polling attempts
$sortedPolls = $pollingAttempts | Sort-Object -Property Duration -Descending
Write-Output $sortedPolls