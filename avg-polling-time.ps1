$logsFolder = "C:\Users\Anatoly.Cherenkov\Downloads\4171080\teamcity_server_logs_2022-07-18"
$vcsRootCount = 10709
$pollerThreadCount = 10

# Calculate average VCS polling time

function Get-PollingTime {
    param (
        [Parameter(Position=0)]
        [string]
        $InputLogLine
    )

    if ($InputLogLine -notmatch ", total time: (?<content>.*), persisting time: ")
    {
        return "Log line doesn't contain polling time"
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

# Calculate and show stats
[TimeSpan]$totalTime = [TimeSpan]::FromMilliseconds(0)
[Int32]$successfulPolls = 0
foreach ($line in Get-Content $logsFolder/teamcity-vcs.log*) {
    $lineParseResult = Get-PollingTime $line
    
    if ($lineParseResult.GetType().Name -eq "TimeSpan") {
        $totalTime = $totalTime.Add($lineParseResult)
        $successfulPolls++
    }
}
[TimeSpan]$avgPollTime = $totalTime / $successfulPolls
[TimeSpan]$suggestedPollingInterval = $avgPollTime * $vcsRootCount / $pollerThreadCount

"Total time spent polling: $totalTime"
"Sucessful polls: $successfulPolls"
"Average polling time: $avgPollTime"
"It will take $suggestedPollingInterval to poll $vcsRootCount VCS Roots in $pollerThreadCount pollerThreadCount$pollerThreadCount"