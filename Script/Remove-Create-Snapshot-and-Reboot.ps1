<#
.Synopsis
   - Remove Snapshot if exists
   - Validate if server has snapshot. If not, take it. If has 1 or more (you choose) it don't generate another
   - Reboot Server in a predetermined period

.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.AUTHOR
    Juliano Alves de Brito Ribeiro (jaribeiro@uoldiveo.com or julianoalvesbr@live.com)
.VERSION
    0.2
.ENVIRONMENT
    ***Development
    Test
    Production
    
#>

function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
}

#FUNCTION PING TO TEST CONNECTIVITY
function Ping
([string]$hostname, [int]$timeout = 100) 
{
    $ping = new-object System.Net.NetworkInformation.Ping #creates a ping object
    
    try { $result = $ping.send($hostname, $timeout).Status.ToString() }
    catch { $result = "Failure" }
    return $result
}

#FUNCTION CONNECT TO VCENTER
function Connect-ToVcenterServer
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('Manual','Automatic')]
        $methodToConnect = 'Automatic',

        # Param2 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateSet('vCenter1','vCenter2')]
        [string]$vCenterToConnect, 
        
        [string]$suffix = '.yourdomain.private',

        [string]$port = 443
    )

    #VALIDATE MODULE
    $moduleExists = Get-Module -Name Vmware.VimAutomation.Core

    if ($moduleExists){
    
        Write-Output "The Module Vmware.VimAutomation.Core is already loaded"
    
    }#if validate module
    else{
    
        Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
    }#else validate module

       

    if ($methodToConnect -eq 'Automatic'){
                
        $Script:workingServer = $vCenterToConnect + $suffix
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        Connect-VIServer -Server $Script:WorkingServer -Port $Port -WarningAction Continue -ErrorAction Continue
           
    
    }#end of If Method to Connect
    else{
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        #CREATE VCENTER LIST
        $vcServers = @();
        
        $vcServers = ("vCenter1.yourdomain.private","vCenter2.yourdomain.private")

        $workingLocationNum = ""
        
        $tmpWorkingLocationNum = ""
        
        $Script:WorkingServer = ""
        
        $i = 0

        #MENU SELECT VCENTER
        foreach ($vcServer in $vcServers){
	   
                $vcServerValue = $vcServer
	    
                Write-Output "            [$i].- $vcServerValue ";	
	            $i++	
                }#end foreach	
                Write-Output "            [$i].- Exit this script ";

                while(!(isNumeric($tmpWorkingLocationNum)) ){
	                $tmpWorkingLocationNum = Read-Host "Type Vcenter Number that you want to connect"
                }#end of while

                    $workingLocationNum = ($tmpWorkingLocationNum / 1)

                if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))  ){
	                $Script:WorkingServer = $vcServers[$WorkingLocationNum]
                }
                else{
            
                    Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
                    Exit;
                }#end of else

        #Connect to Vcenter
        Connect-VIServer -Server $Script:WorkingServer -Port $port -WarningAction Continue -ErrorAction Continue
  
    
    }#end of Else Method to Connect

}#End of Function Connect to Vcenter

#FUNCTION PAUSE
function Pause-PSScript
{

   Read-Host 'Press [ENTER] to Continue' | Out-Null

}

#FUNCTION CREATE SNAPSHOT
function Create-MultipleVMSnapshot
{
    [CmdletBinding()]
    Param
    (
        #Vmware VMs List        
        [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
        [alias("VMs","VMNames")]
        [System.String[]]$VirtualMachineList,          


        # SnapshotName
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Specifies a name for the new snapshot.",
                   Position=1)]
        [string]$SnapshotName,

        #snapshot Description
        [Parameter(Mandatory=$true,
                   HelpMessage="Provide a description of the new snapshot.")]
        [string]$SnapshotDescription,
        
        #snapshot Memory
        [Parameter(Mandatory=$false,
                   HelpMessage="If the value is true and if the virtual machine is powered on, the virtual machine's memory state is preserved with the memory")]
        $SnapshotMemory = $true,

        #snapshot Quiesce Memory
        [Parameter(Mandatory=$false,
                   HelpMessage="If the value is true and the virtual machine is powered on, VMware Tools are used to quiesce the file system of the
                                virtual machine. This assures that a disk snapshot represents a consistent state of the guest file systems. If the
                                virtual machine is powered off or VMware Tools are not available, the Quiesce parameter is ignored.")]
        $SnapshotQuiesceMem = $false,

        #snapshot Confirm
        [Parameter(Mandatory=$false,
                   HelpMessage="If the value is true, indicates that the cmdlet asks for confirmation before running. If the value is false, the
                                cmdlet runs without asking for user confirmation.")]
        $SnapshotConfirm = $false,

   
        [Parameter(Mandatory=$false,
        HelpMessage="Indicates that the command returns immediately without waiting for the task to complete.")]
        $runAsync = '-runAsync',

        [Parameter(Mandatory=$false,
        HelpMessage="Indicates the number of snapshots to consider.")]
        [int]$numberOfSnaps = 1

    )

    #VALIDATE MODULE
    $moduleExists = Get-Module -Name Vmware.VimAutomation.Core

    if ($moduleExists){
    
        Write-Output "The Module Vmware.VimAutomation.Core is already loaded"
    
    }#if validate module
    else{
    
        Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
    }#else validate module
    

    $NumberofVms = $VirtualMachineList.Count

    Write-Output "Where found $NumberofVMs VMs. I will try to generate snapshot now"

  
    foreach ($vmName in $VirtualMachineList){
    
        
        $Error.Clear()

        $tmpVM = Get-VM -Name $vmName -ErrorAction Continue
        
        if ($Error[0]){
        
            Write-Output "The VM $vmName was not found..."
        
            Write-Output "I will try the next one =)"

            Start-Sleep -Seconds 2
                
        }#end of IF Error 0
        else{
        
            $snapshotExists = $tmpVM | Get-Snapshot

            $counterSnapshots = $snapshotExists.Count

            #VALIDATE IF EXISTS SNAPSHOT
            if ($counterSnapshots -ge $numberOfSnaps){
            
                Write-Output "The VM $vmName has $counterSnapshots and I will not create a new snapshot"
            
            
            }#END OF IF VALIDATE SNAPSHOT
            else{
                
                #CREATE SNAPSHOT
                New-Snapshot -VM $tmpVM -Name $SnapshotName -Description $SnapshotDescription -Memory:$SnapshotMemory -Quiesce:$SnapshotQuiesceMem -Confirm:$SnapshotConfirm -ErrorAction Continue -Verbose
            
                
            }#END OF ELSE VALIDATE SNAPSHOT
        
        
        
        }#end of Else Error 0
   
    }#end of Main Foreach

}#End of Function Create-VMSnapshot

#Function Remove Snapshot
function Remove-VMVmwareSnapshot
{
    [CmdletBinding()]
    Param
    (
        #Vmware VMs List        
        [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [alias("VMs","VMNames")]
        [System.String[]]$VirtualMachineList, 

        [Parameter(Mandatory=$false,
        HelpMessage="Indicates that the command returns immediately without waiting for the task to complete.")]
        $runAsync = '-runAsync',

        [Parameter(Mandatory=$false,
        HelpMessage="Indicates that you want to remove the children of the specified snapshots as well.")]
        [string]$removeChildren = '-RemoveChildren'

   )

    #VALIDATE MODULE
    $moduleExists = Get-Module -Name Vmware.VimAutomation.Core

    if ($moduleExists){
    
        Write-Output "The Module Vmware.VimAutomation.Core is already loaded"
    
    }#if validate module
    else{
    
        Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
    }#else validate module

    $dataAtual = (Get-Date -Format "ddMMyyyy-HHmmss")

    #data de corte - só remove acima de tantas horas
    [int]$HourToConsider = -72

    $trimDate = (Get-Date).AddHours($HourToConsider)
    
    #This String has a objective to when the script encounters this string, it not remove snapshot. 
    [string]$stringDNR = 'DNR5'

    foreach ($vmName in $VirtualMachineList){
    
        $snapshotList = Get-VM -Name $vmName | Get-Snapshot | Where-Object -FilterScript {$_.Created -lt "$trimdate" -and $_.Description -notlike "*$stringDNR*"}
    
        if ($snapshotList){
        
            Write-Host "I found one or more snapshots in VM: $vmName. Time to remove"

            foreach ($snap in $snapshotList){
    
                $snapName = $snap.Name
     
                $vmName = $snap.VM

                Write-Output "Now I will remove the $snapName of the VM $vmName ..." 
       
                $snap | Select-Object -Property Name,Description,Created,SizeGB,VM 

                Remove-Snapshot -Snapshot $snap -RunAsync -RemoveChildren -Confirm:$false -Verbose

            }#end forEach Snapshot

            Start-Sleep -Seconds 150 -Verbose

            #CONSOLIDATION NEEDED
            $vm = get-vm -Name $vmName

            $consolidationNeeded = $vm.ExtensionData.Runtime.ConsolidationNeeded

            if ($consolidationNeeded -like "false"){ 
        
                Write-Output "The VM $vmName does not need consolidation disk"   

             }#end of IF Consolidation Needed
            else{
         
                Write-Output "The VM $vmName needs consolidation disk"  

                $vm.ExtensionData.ConsolidateVMDisks()
         
             }#end of Else Consolidation Needed
        
        
        }#END OF IF VALIDATE SNAPSHOT
        else{
        
            Write-Output "In $dataAtual there are no snapshots to remove according to parameters. 5 days and DNR5 string in VM: $vmName"
        
        
        }#END OF ELSE VALIDATE SNAPSHOT
            
    }#END OF FOREACH VM

}#End of Function Remove Snapshot


function Scheduled-RemoteRestart
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
        [System.String[]]$VirtualMachineList,

        [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=1)]
        [System.String]$vcServer,


        [Parameter(Mandatory=$false,
        Position=2)]
        [System.String]$initialTime = '0001',

        [Parameter(Mandatory=$false,
        Position=3)]
        [System.String]$finalTime = '0245'

        
    )

#VALIDATE MODULE
$moduleExists = Get-Module -Name Vmware.VimAutomation.Core

if ($moduleExists){
    
        Write-Output "The Module Vmware.VimAutomation.Core is already loaded"
    
}#if validate module
else{
    
        Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
}#else validate module

$vmSizeArray = $VirtualMachineList.Count

switch ($vmSizeArray)
{
    1 {
        $rebootListHour = '0005'
       }#end of 1
    2 {
    
        $rebootListHour = '0005','0035'
        
        }#end of 2
    3 {
    
        $rebootListHour = '0005','0035','0105'
        
        }#end of 3
    4 {
    
        $rebootListHour = '0015','0045','0115','0145'
    
    }#end of 4
    5 {
    
        $rebootListHour = '0005','0035','0105','0135','0205'
    
    }#end of 5
    6 {
        
        $rebootListHour = '0005','0035','0105','0135','0205','0235'
    
    }#end of 6
    7 {
    
        $rebootListHour = '0005','0035','0105','0135','0205','0235','0305'
    
    }#end of 7
    8 {
    
        $rebootListHour = '0005','0035','0105','0135','0205','0235','0305','0335'
    
    }#end of 8
    9 {
    
        Write-Host "I can't deal with this number of VMs. I will exit"

        Exit
    
    }#end of 9
}#end of switch size array

$CompareTime = (Get-Date -Format HHmm).ToString()

if (($compareTime -ge $initialTime) -and ($compareTime -le $finalTime)){

    Write-Host "Ok. We are inside the schedule. InitialTime: $initialTime. Final Time: $finalTime We can continue" -ForegroundColor White -BackgroundColor DarkBlue

    $counterHour = 0

    $rebootCounter = 1

    $vmCounter = 0

#REBOOT FOUR MACHINES
    do
    {
        $tmpVm = ""

        $tmpVMName = ""

        $tmpVMName = $VirtualMachineList[$vmCounter] 
        
        $Error.Clear()

        $tmpVM = Get-VM -Name $tmpVMName -ErrorAction Continue
        
        if ($Error[0]){
        
            Write-Output "The VM $tmpVMName was not found..."
        
            Write-Output "I will try the next one =)"
                                       
        }#end of IF Error 0
        else{
        
            $tmpDate = (get-date -Format HHmm).ToString()

            $tmpReboot = $rebootListHour[$counterHour]

            $internalCounter = $counterHour + 1  
                        
            
            if ($tmpDate -gt $tmpReboot){
    
                Write-Output "You are running too late. Now is $tmpDate Hour and Reboot $InternalCounter was to be at $tmpReboot. I will try next reboot"
        
                $counterHour++

                $rebootCounter++

                $vmCounter++
        
            }#end of IF
            elseif($tmpDate -eq $tmpReboot){

                Write-Output "You are running ok. Now is $tmpDate and reboot number $internalCounter is now at $tmpReboot "
                                
                #RESTART VM
                Restart-VMGuest -Server $vcServer -VM $tmpVM -Confirm:$false -Verbose

                $counterHour++

                $rebootCounter++

                $vmCounter++

                #WAIT 4 MINUTES TO VALIDATE RDP CONNECTION
                Start-Sleep -Seconds 240

                $validateConnection = (Test-NetConnection -ComputerName $tmpVMName -Port 3389).TcpTestSucceeded

                if ($validateConnection -eq $true){

                    Write-Host "The VM: $tmpVMName is OK" -ForegroundColor White -BackgroundColor DarkBlue

                }#END OF IF VALIDATE CONNECTION
                else{

                    Write-Host "The VM: $tmpVMName is NOK" -ForegroundColor White -BackgroundColor Red

                    #SEND MAIL TO WARNING THAT VM IS NOT OK
                    $fromAddress = "powershellfrom@yourdomain.private"
                    $toAddress = "ti@yourdomain.private","virt@yourdomain.private"
                    $Subject = "[SERVER-WARNING] Validate Boot - The VM: $tmpVMName is Not OK. Please Verify"
                    $smtpserver = "smtp.yourdomain.private"

                    Send-MailMessage -SmtpServer $smtpserver -From $fromaddress -To $toaddress -Subject $Subject -Body "PLEASE VERIFY VM: $tmpVMName ! I CAN'T CONNECT WITH RDP PORT 3389. PROBABLY VM IS DOWN" -Priority High -Encoding UTF8

                }#END OF ELSE VALIDATE CONNECTION

                

            }#end of ElseIF
        else{
    
            Write-Host "Is not time to reboot the VM: $tmpVMName. I Will try in 10 seconds" -ForegroundColor Cyan -BackgroundColor DarkMagenta
    
            Start-Sleep -Seconds 10 -Verbose

        }#end of Else
        
    }#end of Else Error 0

}
    until ($rebootCounter -gt $vmSizeArray)#end of Do Until 



}#end of IF Validate Inside Range
else{

    Write-Output "Not OK. You are running this script outside the schedule, I will exit of the Script"
    
    Exit

}#end of ELSE Validate Inside Range
    

}#End of Function Scheduled-RemoteRestart

Clear-Host

#MAIN SCRIPT
$vmList = @()

[string]$dayOkOne = 'Wednesday'
[string]$dayOkTwo = 'Sunday'

#String Teste
#[string]$dayOkOne = 'Friday' 

[string]$ActionMethod = 'Automatic' 


if ($ActionMethod -eq 'Automatic'){

    
    $dayToRun = (Get-date).DayOfWeek.ToString()
     
    
    if (($dayToRun -eq $dayOkOne) -or ($dayToRun -eq $dayOkTwo)){
    
        Write-Output "Let's Run the script. Today is $dayToRun"
	
	#Initialize Array with List of VMs
	$vmList = @()
	
        $vmList = (Get-Content -Path "$env:SystemDrive\Temp\vmList.txt")
    
        Connect-ToVcenterServer -methodToConnect Automatic -vCenterToConnect vCServer1.yourdomain.private -port 443

        Remove-VMVmwareSnapshot -VitualMachineList $vmList

        Create-MultipleVMSnapshot -VirtualMachineList $vmList -SnapshotName "Rotina de Reboot" -SnapshotDescription "Reboot Routine. Wednesdays and Sundays. Talk with TI Team"
    
        Scheduled-RemoteRestart -VirtualMachineList $vmList -vcServer $Script:workingServer -Verbose
        
        
    
    }#END OF DAY TO RUN
    else{
    
        Write-Output "Today is $dayToRun. Not a day to run this script"

        Exit

    }#END OF ELSE DAY TO RUN
    
    

}#END OF IF AUTOMATIC METHOD
else{


Do {
    Write-Output "
----------MENU VM SNAPSHOT----------

You are connected to Vcenter: $vCenterToConnect

1 = Take Snapshot of a Single VM
2 = Take Snapshot of Two or More VMs
3 = Take Snapshot of a List of VMs (from file)
4 = Exit

--------------------------"

$choice1 = Read-host -prompt "Select a number & press enter"
} until ($choice1 -eq "1" -or $choice1 -eq "2" -or $choice1 -eq "3" -or $choice1 -eq "4")

Switch ($choice1) {
"1" {

    Write-Output "You choose take snapshot of a single VM"

    Write-Output "Select the Options"

    $VMName = Read-Host "Enter the VM Name"

    $Error.Clear()

    $tmpData = Get-VM -Name $VMName -ErrorAction Continue
if ($Error[0])
    {
    Write-Output "The VM $VMName does not exist..."
    Write-Output "I will exit of this script...bye bye =)"
    Start-Sleep -Seconds 3
    Exit}

    $SnapshotName = Read-Host "Write the Snapshot Name"

    $SnapshotDescription = Read-Host "Write the Description for this Snapshot"

    


    }#end of first choice
"2" {

    Write-Output "Under Construction"

}#end of second choice
"3" {

    Write-Output "Under Construction"

}#end of third choice
"4" {

    Write-Output " "
    
    Write-Output "Finishing the Script..."
    
    Exit

}#end of fourth choice
}#end of switch choice

}#END OF ELSE AUTOMATIC METHOD
