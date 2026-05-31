$jobsDir = ".\jobs"

while ($true)
{
    $jobs = Get-ChildItem $jobsDir -Directory

    Write-Host "-----" (Get-Date)

    foreach ($job in $jobs)
    {
        Write-Host "FOUND:" $job.Name
    }

    Start-Sleep -Seconds 1
}