$Runspace = [runspacefactory]::CreateRunspace()
$Runspace.Open()
$PowerShell = [powershell]::Create()
$PowerShell.Runspace = $Runspace
$PowerShell.AddScript({
        $Task = Get-ScheduledTask -TaskName "Ethernet-AutoConfig" -ErrorAction SilentlyContinue
        if ($Task) { "Task Found: $($Task.State)" } else { "Task Not Found" }
    
        $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        "IsAdmin: $IsAdmin"
    })
$Results = $PowerShell.Invoke()
$Results
