$jobsDir = ".\jobs"

while ($true)
{
    $jobs = Get-ChildItem $jobsDir -Directory

    foreach ($job in $jobs)
    {
        $doneFile =
            Join-Path $job.FullName "done.json"

        $startFile =
            Join-Path $job.FullName "start.json"

        # уже обработано
        if (Test-Path $doneFile)
        {
            continue
        }

        # нет команды на запуск
        if (-not (Test-Path $startFile))
        {
            continue
        }

        try
        {
            # txt файлы
            $txtFiles =
                Get-ChildItem "$($job.FullName)\*.txt" |
                Sort-Object Name

            # запуск разрешён, но txt нет
            if ($txtFiles.Count -eq 0)
            {
                Write-Host "NO TXT FILES:" $job.Name
                continue
            }

            Write-Host "PROCESSING:" $job.Name

            # озвучка
            foreach ($txt in $txtFiles)
            {
                $text =
                    Get-Content `
                    $txt.FullName `
                    -Raw `
                    -Encoding UTF8

                # защита от пустого текста
                if ([string]::IsNullOrWhiteSpace($text))
                {
                    continue
                }

                $mp3 =
                    Join-Path `
                    $job.FullName `
                    ($txt.BaseName + ".mp3")

                edge-tts `
                    --voice ru-RU-DmitryNeural `
                    --rate=-8% `
                    --pitch=-1Hz `
                    --volume=+0% `
                    --text "$text" `
                    --write-media "$mp3"
            }

            # список mp3
            $listFile =
                Join-Path $job.FullName "list.txt"

            Get-ChildItem "$($job.FullName)\????.mp3" |
            Sort-Object Name |
            ForEach-Object {
                "file '$($_.FullName)'"
            } |
            Out-File `
                $listFile `
                -Encoding ascii

            # итоговый файл
            $final =
                Join-Path $job.FullName "final.mp3"

            # склейка
            ffmpeg `
                -f concat `
                -safe 0 `
                -i $listFile `
                -c:a libmp3lame `
                -b:a 192k `
                -y $final

            # проверка успешности
            if (Test-Path $final)
            {
                # удаление промежуточных mp3
                Get-ChildItem "$($job.FullName)\????.mp3" |
                Remove-Item -Force

                # удаление txt
                Get-ChildItem "$($job.FullName)\*.txt" |
                Remove-Item -Force

                # удаление списка
                if (Test-Path $listFile)
                {
                    Remove-Item `
                        $listFile `
                        -Force
                }

                # длительность
                $duration =
                    ffprobe `
                        -v error `
                        -show_entries format=duration `
                        -of default=noprint_wrappers=1:nokey=1 `
                        $final

                $duration =
                    [math]::Round(
                        [double]$duration,
                        2
                    )

                # done.json
                @{
                    status = "done"
                    final = "/tts/jobs/$($job.Name)/final.mp3"
                    job = $job.Name
                    duration = $duration
                    completed = (Get-Date)
                } |
                ConvertTo-Json |
                Set-Content `
                    $doneFile `
                    -Encoding UTF8

                # удалить файл запуска
                if (Test-Path $startFile)
                {
                    Remove-Item `
                        $startFile `
                        -Force
                }

                Write-Host "DONE:" $job.Name
            }
            else
            {
                Write-Host "FFMPEG FAILED:" $job.Name
            }
        }
        catch
        {
            Write-Host "ERROR:"
            Write-Host $_
        }
    }

    Start-Sleep -Seconds 1
}