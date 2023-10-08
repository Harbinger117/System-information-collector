# CPU
# https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-processor

$CPU = Get-WmiObject -class Win32_Processor
$CPU_Used = $CPU.LoadPercentage
$CPU_Cores = $CPU.NumberOfCores
$CPU_Threads = $CPU.NumberOfLogicalProcessors

Add-Content -Path dailyCPUData.txt -Value "$CPU_Used"