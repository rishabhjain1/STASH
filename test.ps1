cls
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$folderLocation = [System.IO.Path]::Combine($scriptPath, "PowerShellMultiThreading_SimpleExample")    
if (Test-Path $folderLocation)
{
    Remove-Item $folderLocation -Recurse -Force
}
New-Item -Path $folderLocation -ItemType directory -Force > $null

# This script block will download a file from the web and create a local version
$ScriptBlock = {
   Param (
      [string]$fileName,
      [string]$url
   )   
   $contents = Invoke-WebRequest $url -UseBasicParsing
   Set-Content $fileName $myString     # use a common variable
   Add-Content $fileName $contents     # add the text download from the www
}

####################### Run the process sequentially ############################

Write-Host "First lets create the 50 text files by running the process sequentially"
$startTime = Get-Date

$myString = "this is not session state"
1..50 | % {
    $fileName = "test$_.txt"
    $fileName = [System.IO.Path]::Combine($folderLocation, $fileName)
    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $fileName, 
	"http://www.textfiles.com/100/adventur.txt"
}

$endTime = Get-Date
$totalSeconds = "{0:N4}" -f ($endTime-$startTime).TotalSeconds
Write-Host "All files created in $totalSeconds seconds"

####################### Run the process in parallel ############################
Write-Host ""
$numThreads = 5
Write-Host "Now lets try creating 50 files by running up $numThreads background threads"

Remove-Item $folderLocation -Recurse -Force
New-Item -Path $folderLocation -ItemType directory -Force > $null

# Create session state
$myString = "this is session state!"
$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$sessionstate.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "myString" ,$myString, "example string"))
   
# Create runspace pool consisting of $numThreads runspaces
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, 50, $sessionState, $Host)
$RunspacePool.Open()

$startTime = Get-Date
$Jobs = @()
1..50 | % {
    $fileName = "test$_.txt"
    $fileName = [System.IO.Path]::Combine($folderLocation, $fileName)
    $Job = [powershell]::Create().AddScript($ScriptBlock).AddParameter("fileName", 
    $fileName).AddParameter("url", "http://www.textfiles.com/100/adventur.txt")
    $Job.RunspacePool = $RunspacePool
    $Jobs += New-Object PSObject -Property @{
      RunNum = $_
      Job = $Job
      Result = $Job.BeginInvoke()
   }
}
 
Write-Host "Waiting.." -NoNewline
Do {
   Write-Host "." -NoNewline
   Start-Sleep -Seconds 1
} While ( $Jobs.Result.IsCompleted -contains $false) #Jobs.Result is a collection

$endTime = Get-Date
$totalSeconds = "{0:N4}" -f ($endTime-$startTime).TotalSeconds
Write-Host "All files created in $totalSeconds seconds"