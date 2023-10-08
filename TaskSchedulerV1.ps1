# Task Scheduler V1

$Location1 = "C:\Users\shake\OneDrive\Desktop\splunk-collector-for-windows-master\Script.ps1"
$Time = "12:47pm"
$Trigger= New-ScheduledTaskTrigger -Daily -At $Time
$Action= New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File $Location1" 
Register-ScheduledTask -TaskName "Splunk" -Trigger $Trigger -User $env:username -Action $Action


#Daily CPU
$Location1 = "C:\Users\shake\OneDrive\Desktop\splunk-collector-for-windows-master\DailyCPU.ps1"
$Time2 = "12:47pm"
$Trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At $Time2
$Trigger.Repetition = $(New-ScheduledTaskTrigger -Once -At $Time2 -RepetitionDuration "23:00" -RepetitionInterval "01:00").Repetition
$Action= New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File $Location1" 
Register-ScheduledTask -TaskName "Splunk-Daily-CPU" -Trigger $Trigger -User $env:username -Action $Action