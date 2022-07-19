$logsFolder = "C:\Users\Anatoly.Cherenkov\Downloads\4171080\teamcity_server_logs_2022-07-18"
$vcsRootCount = 10709
$pollerThreadCount = 10

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

function Get-VcsName {
    param (
        [Parameter(Position = 0)]
        [string]
        $InputLogLine
    )

    if ($InputLogLine -notmatch 'Finish collecting changes successfully (for|from) VCS root "(?<content>.*?)" {instance id=')
    {
        $InputLogLine > C:\Temp\debug.log
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

class PollingAttempt
{
    [ValidateNotNullOrEmpty()][DateTime]$Time
    [ValidateNotNullOrEmpty()][string]$VcsName
    [ValidateNotNullOrEmpty()][TimeSpan]$Duration
    [ValidateNotNullOrEmpty()][string]$RawLogLine
    
    PollingAttempt($Time, $VcsName, $Duration, $RawLogLine) {
        $this.Time = $Time
        $this.VcsName = $VcsName
        $this.Duration = $Duration
        $this.RawLogLine = $RawLogLine
    }
}

# Calculate and show stats
$pollingAttempts = [System.Collections.ArrayList]::new() 

[TimeSpan]$totalTime = [TimeSpan]::FromMilliseconds(0)
[Int32]$successfulPolls = 0

foreach ($line in Get-Content $logsFolder/teamcity-vcs.log*) {
    $currentPollDuration = Get-PollingDuration $line
    
    if ($currentPollDuration.GetType().Name -eq "TimeSpan") {
        $totalTime = $totalTime.Add($currentPollDuration)
        $successfulPolls++

        $time = Get-PollingTime $line
        $vcsName = Get-VcsName $line
        $currentPollingAttempt = [PollingAttempt]::new(
            $time,
            $vcsName,
            $currentPollDuration,
            $line
        )
        $pollingAttempts += $currentPollingAttempt
    }
}
    
## Show general statistics

[TimeSpan]$avgPollTime = $totalTime / $successfulPolls
[TimeSpan]$suggestedPollingInterval = $avgPollTime * $vcsRootCount / $pollerThreadCount

"Total time spent polling: $totalTime"
"Sucessful polls: $successfulPolls"
"Average polling time: $avgPollTime"
"It will take $suggestedPollingInterval to poll $vcsRootCount VCS Roots in $pollerThreadCount pollerThreadCount$pollerThreadCount"

## Show longest polling attempts

$sortedPolls = $pollingAttempts | Sort-Object -Property Duration -Descending
foreach ($poll in $sortedPolls) {
    Write-Output $poll
}