# Calculate average VCS polling time

$logsFolder = "C:\Users\Anatoly.Cherenkov\Downloads\4028621"
$vcsRoots = 1463
$threads = 10

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
        $units = ($element -split '\d')[-1]
        if ($units -eq "h")
        {
            $h = ($element -split '\D')[0]
            $timespan = $timespan.Add([TimeSpan]::FromHours($h))
        }
        elseif ($units -eq "m")
        {
            $m = ($element -split '\D')[0]
            $timespan = $timespan.Add([TimeSpan]::FromMinutes($m))
        }
        elseif ($units -eq "s")
        {
            $s = ($element -split '\D')[0]
            $timespan = $timespan.Add([TimeSpan]::FromSeconds($s))
        }
        elseif ($units -eq "ms")
        {
            $ms = ($element -split '\D')[0]
            $timespan = $timespan.Add([TimeSpan]::FromMilliseconds($ms))
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
[TimeSpan]$suggestedPollingInterval = $avgPollTime * $vcsRoots / $threads

"Total time spent polling: $totalTime"
"Sucessful polls: $successfulPolls"
"Average polling time: $avgPollTime"
"It will take $suggestedPollingInterval to poll $vcsRoots VCS Roots in $threads threads"
