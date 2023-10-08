$Config = Get-Content -Raw -Path Config.json | ConvertFrom-Json

if($Config.OS)
{
    # Operating System
    # https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem
    Write-Output "Retrieving OS Data"
    $OS = Get-WmiObject -class Win32_OperatingSystem
    $OS_Name = $OS.Caption.replace('Microsoft Windows','Win')
    $OS_BuildNumber = $OS.BuildNumber
    $DateNow = Get-Date
    $Sys_Uptime = ($DateNow - $OS.ConvertToDateTime($OS.LastBootUpTime));
    $totalRAM = [math]::Round($OS.TotalVisibleMemorySize/1MB, 0)
    $usedRAM = [math]::Round(($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory)/1MB, 0)
    $usedRAM_percentage = [math]::Round(($usedRAM/$totalRAM)*100, 0)
    $Organisation = $OS.Organization
}

if($Config.System)
{
    # Computer System
    # https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem
    Write-Output "Retrieving System Data"
    $CS = Get-WmiObject -class Win32_ComputerSystem
    $CS_IP = (Get-NetIPConfiguration |Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne "Disconnected"})[0].IPv4Address.IPAddress # Returns first response ip address routed to default gateway

    $CS_Name = $CS.Name
    $CS_Owner = $CS.PrimaryOwnerName
}

if($Config.CPU)
{
    # CPU
    # https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-processor
    Write-Output "Retrieving CPU Data"
    $CPU = Get-WmiObject -class Win32_Processor

    $CPU_Used = $CPU.LoadPercentage
    $CPU_Cores = $CPU.NumberOfCores
    $CPU_Threads = $CPU.NumberOfLogicalProcessors

    # Daily CPU Usage
    $cpuAvgFileName = "dailyCPUData.txt"
    $hoursTracked = 24
    $sum = 0

    if (Test-Path -Path $cpuAvgFileName) 
    {
        foreach ( $line in Get-Content .\$cpuAvgFileName )
        { 
            $sum = [int]$line + $sum
        }

        $averageDailyCPU = $sum / $hoursTracked
        Remove-Item $cpuAvgFileName
    } else 
    {
	    $averageDailyCPU = "ERROR-Could not open file"
    }

    
}

if($Config.Disk)
{
    # Disk
    # https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-LogicalDisk
    Write-Output "Retrieving Disk Data"
    $Disks = Get-PSDrive -PSProvider FileSystem
    $Disk_String = "{";
    $Counter = 1;
    ForEach($disk in $Disks)
    {
        $disktotal = $disk.Used + $disk.Free;
        if($disktotal)
        {
            $Disk_String = $Disk_String + '"Disk' + ($Counter-1).ToString() + '":{'
            $Disk_String = $Disk_String + '"Disk_Mount":"' + $disk.Name + '","Used_Percent":' + [math]::Round(($disk.Used/$disktotal)*100, 0).ToString() + ',"Capacity_GB":' + [math]::Round($disktotal/1GB,0).ToString() + '}';
            if($Counter -ne $Disks.Count)
            {
                $Disk_String = $Disk_String + ',';
            }
            $Counter = $Counter + 1;
        }
        
    }

    $Disk_String = $Disk_String + "}";
}

if($Config.GPU)
{
    # GPU
    # https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-VideoController
    Write-Output "Retrieving GPU Data"
    $GPU = Get-WmiObject -class Win32_VideoController
    $GPU_String = "{";
    $Counter = 1;
    ForEach($gpu in $GPU)
    {
        if ($Counter -gt 1)
        {
            $GPU_String = $GPU_String + ',';
        }
        $GPU_String = $GPU_String + '"GPU' + $Counter.ToString() + '":{'
        $GPU_String = $GPU_String + '"Name":"' + $gpu.Name + '", "RAM_GB":' + ([math]::Round($gpu.AdapterRam/1GB,0)).ToString() + '}';
        $Counter = $Counter + 1;
    
    }
    $GPU_String = $GPU_String + "}";
}

if($Config.Updates)
{
    # Updates
    # https://gist.github.com/Grimthorr/44727ea8cf5d3df11cf7
    Write-Output "Retrieving Updates Data"
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateupdateSearcher()
    $Updates = @($UpdateSearcher.Search("IsHidden=0 and IsInstalled=0").Updates)
    $Updates = $Updates.Count
    $Reboot = $false
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { $Reboot = $true}
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { $Reboot = $true }
    if(!$Updates){$Updates = 0}
}

if($Config.Logins)
{
    #Login Data
    $Logins = get-eventlog system -ComputerName $env:computername -Instanceid 7001 -source Microsoft-Windows-Winlogon -After (Get-Date).AddDays(-7);
}

$JSON_String = @{
    'System_Name' = $CS_Name;
    'System_IP' = $CS_IP;
    'System_Uptime' = $Sys_Uptime.Days;
    'System_Release' = $OS_Name + " " + $OS_BuildNumber;
    'CPU_Cores/Threads' = $CPU_Cores.ToString() + "/" + $CPU_Threads.ToString();
    'CPU_Usage' = $CPU_Used;
    'Average_Daily_CPU_Usage' = $averageDailyCPU;
    'Disk(s)' = $Disk_String;
    'Memory_Used_Gb' = $usedRAM;
    'Memory_Total_Gb' = $totalRAM;
    'Memory_Used_Percentage' = $usedRAM_percentage;
    'GPU(s)' = $GPU_String;
    'Updates' = $Updates;
    'Reboot' = $Reboot;
    'Organisation' = $Organisation;
    'Logins_7day' = $Logins.Count;
}

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

Write-Output "Generating JSON Data"
$output = New-Object -TypeName PSObject -Prop $JSON_String
$output = $output | ConvertTo-JSON

$DateTime = (Get-Date).ToUniversalTime()
$header_string = "Splunk " + $Config.SplunkToken;
$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("Authorization", $header_string)

$body = '{
        "host":"' + $env:computername + '",
        "sourcetype":"_json",
        "source":"PS Script",
        "index":"main",
        "event": '+ $output + '

        }'

$splunkserver = "https://splunk2121.sstars.ws:8088/services/collector/event"
$response = Invoke-RestMethod -Uri $splunkserver -Method Post -Headers $header -Body $body
Write-Output $response.text
