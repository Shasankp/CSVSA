                                <################################################################################>
                                <##                                                                             ##>
                                <##                       Clustered Shared Volume State Analyer                 ##>
                                <##                             written by:                                     ##>
                                <##                            * Shasankp                                       ##>
                                <##                                                                             ##>
                                <##                                                                             ##>
                                <##                                                                             ##>
                                <##                                                                             ##>
                                <##                                                                             ##>
                                <################################################################################>


Param(
    # Path where the SDP is located TODO Add script validation using Test-PAth with Type Container
    [Parameter(Mandatory = $false, Position = 1)]
    [String] $SDPPath ,
    
    # Begin date
    [Parameter(Mandatory = $false)]
    [DateTime] $StartDate,

    # End date
    [Parameter(Mandatory = $false)]
    [DateTime] $EndDate,

    # Detail Level
    [Parameter(Mandatory = $false)]
    [ValidateSet("Basic", "Advanced")]
    [String] $DetailLevel
)


function cmdlinemessgas($msg)
{
Write-host -ForegroundColor Yellow $msg
Write-Host "Usage:"
Write-Host ""
Write-Host "    CSVSABeta1.0 SourcePath"

Write-Host "        srcpath  = path to the SDP"
Write-Host "        Example  CSVSABeta1.0 c:\Sdp "


}


if(($SDPPath -eq ""))
{
    $mymsg = "Source path cannot be empty"
    cmdlinemessgas($mymsg)
    exit
}

#Error Checking for Cmd line param
if(!(Test-Path $SDPPath -IsValid))
{
    $Mymsg = "Source file path not Specified or file not found"
    cmdlinemessgas($mymsg)
    exit
}



if(($SDPPath -eq "/?"))
{
    $mymsg = "Listing help"
    cmdlinemessgas($mymsg)
    exit
}


#region: customization section of script, logging configuration
if ($LogFilePath) { $ScriptMode = $true}
$HostMode = $true
$ErrorThrown = $null
$ScriptBeginTimeStamp = Get-Date
$ErrorActionPreference = "Stop"
$LogLevel = 0
$VerMa = "1"
$VerMi = "00"
#endregion: customization section of script, logging configuration

#region: Logging Functions 
function WriteLine ([string]$line, [string]$ForegroundColor, [switch]$NoNewLine) {
    # SYNOPSIS:  writes the actual output - used by other functions
    if ($Script:ScriptMode) {
        if ($NoNewLine) {
            $Script:Trace += "$line"
        }
        else {
            $Script:Trace += "$line`r`n"
        }
        Set-Content -Path $script:LogPath -Value $Script:Trace
    }
    if ($Script:HostMode) {
        $Params = @{
            NoNewLine       = $NoNewLine -eq $true
            ForegroundColor = if ($ForegroundColor) {$ForegroundColor} else {"White"}
        }
        Write-Host $line @Params
    }
}
    
function WriteInfo([string]$message, [switch]$WaitForResult, [string[]]$AdditionalStringArray, [string]$AdditionalMultilineString) {
    # SYNOPSIS:  handles informational logs
    if ($WaitForResult) {
        WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message" -NoNewline
    }
    else {
        WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message"  
    }
    if ($AdditionalStringArray) {
        foreach ($String in $AdditionalStringArray) {
            WriteLine "                    $("`t" * $script:LogLevel)`t$String"     
        }       
    }
    if ($AdditionalMultilineString) {
        foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})) {
            WriteLine "                    $("`t" * $script:LogLevel)`t$String"     
        }
       
    }
}

function WriteResult([string]$message, [switch]$Pass, [switch]$Success) {
    # SYNOPSIS:  writes results - should be used after -WaitForResult in WriteInfo
    if ($Pass) {
        WriteLine " - Pass" -ForegroundColor Cyan
        if ($message) {
            WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$message" -ForegroundColor Cyan
        }
    }
    if ($Success) {
        WriteLine " - Success" -ForegroundColor Green
        if ($message) {
            WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$message" -ForegroundColor Green
        }
    } 
}

function WriteInfoHighlighted([string]$message, [string[]]$AdditionalStringArray, [string]$AdditionalMultilineString) {
    # SYNOPSIS:  write highlighted info ## currently not used
    WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message"  -ForegroundColor Cyan
    if ($AdditionalStringArray) {
        foreach ($String in $AdditionalStringArray) {
            WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Cyan
        }
    }
    if ($AdditionalMultilineString) {
        foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})) {
            WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Cyan
        }
    }
}

function WriteWarning([string]$message, [string[]]$AdditionalStringArray, [string]$AdditionalMultilineString) { 
    # SYNOPSIS:  write warning logs ## currently not used
    WriteLine "[$(Get-Date -Format hh:mm:ss)] WARNING: $("`t" * $script:LogLevel)$message"  -ForegroundColor Yellow
    if ($AdditionalStringArray) {
        foreach ($String in $AdditionalStringArray) {
            WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Yellow
        }
    }
    if ($AdditionalMultilineString) {
        foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})) {
            WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Yellow
        }
    }
}

function WriteError([string]$message) {
    # SYNOPSIS:  logs errors
    WriteLine ""
    WriteLine "[$(Get-Date -Format hh:mm:ss)] ERROR:   $("`t`t" * $script:LogLevel)$message" -ForegroundColor Red
        
}

function WriteErrorAndExit($message) {
    # SYNOPSIS:  logs errors and terminates script ## currently not used
    WriteLine "[$(Get-Date -Format hh:mm:ss)] ERROR:   $("`t" * $script:LogLevel)$message"  -ForegroundColor Red
    Write-Host "Press any key to continue ..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
    $HOST.UI.RawUI.Flushinputbuffer()
    Throw "Terminating Error"
}

#endregion: Logging Functions

#region: Script Functions
function Get-Folder($initialDirectory) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"

    if ($foldername.ShowDialog() -eq "OK") {
        $folder += $foldername.SelectedPath
    }
    return $folder
}
function ParameterPicker {
    # .SYNOPSYS Shows dialog to select detail level and date range
    # We are using this instead of Show-Command for hte date picker
    # Test this in PowerShell not in VSCode to see actual output

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Form = New-Object Windows.Forms.Form
    $Form.MaximizeBox = $false
    $Form.FormBorderStyle = "FixedDialog"
    
    $Form.Text = 'Parameters'
    $Form.Size = New-Object Drawing.Size @(245, 300)
    $Form.StartPosition = 'CenterScreen'
    
    $DetailLevelLabel = New-Object System.Windows.Forms.Label
    $DetailLevelLabel.Text = "Select Detail Level: "
    $DetailLevelLabel.Height = 15
    $DetailLevelLabel.Width = 120
    $DetailLevelLabel.Location = New-Object System.Drawing.Point(0, 0) 
    
    $Form.Controls.Add($DetailLevelLabel)

    $listBox = New-Object System.Windows.Forms.Listbox
    $listBox.Location = New-Object System.Drawing.Point(1, 15)
    $listBox.Size = New-Object System.Drawing.Size(226, 165)
    $listBox.SelectionMode = 'One'
    

    [void] $listBox.Items.Add('Basic')
    [void] $listBox.Items.Add('Advanced')
    $listBox.SelectedIndex = 1
    

    $listBox.Height = 35
    $Form.Controls.Add($listBox)
    

    $CalendarLabel = New-Object System.Windows.Forms.Label
    $CalendarLabel.Text = "Select Date Range: "
    $CalendarLabel.Height = 15
    $CalendarLabel.Width = 120
    $CalendarLabel.Location = New-Object System.Drawing.Point(0, 50) 
    $Form.Controls.Add($CalendarLabel)

    $Calendar = New-Object System.Windows.Forms.MonthCalendar
    $Calendar.Location = New-Object System.Drawing.Point(0, 65)
    $Calendar.ShowTodayCircle = $true
    $Calendar.MaxSelectionCount = 300
    $Form.Controls.Add($Calendar)
    
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(38, 235)
    $OKButton.Size = New-Object System.Drawing.Size(75, 23)
    $OKButton.Text = 'OK'
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Form.AcceptButton = $OKButton
    $Form.Controls.Add($OKButton)
    
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(113, 235)
    $CancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $CancelButton.Text = 'Cancel'
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $Form.CancelButton = $CancelButton
    $Form.Controls.Add($CancelButton)
    
    $Form.Topmost = $true
    
    
    [void] $Form.ShowDialog()

    if ($calendar.SelectionStart -eq $calendar.SelectionEnd) {
        $calendar.SelectionEnd = $calendar.SelectionEnd.AddDays(1)
    }
    
    return [PSCustomObject]@{
        DialogResult = $Form.DialogResult
        DetailLevel  = $listBox.SelectedItem
        StartDate    = $calendar.SelectionStart
        EndDate      = $calendar.SelectionEnd
    }
}
#endregion: Script Functions

try {
    #region: Validate date range and detail level
    WriteInfo -message "ENTER: Validate date range and detail level"
    $LogLevel++

    if (!($StartDate) -or !($EndDate) -or !($DetailLevel)) {
        writeinfo "Prompting for script parameters"
        $ScriptParameters = ParameterPicker
        if ($ScriptParameters.DialogResult -eq "OK") {
            $StartDate = $ScriptParameters.StartDate
            $EndDate = $ScriptParameters.EndDate
            $DetailLevel = $ScriptParameters.DetailLevel
            "$StartDate - $EndDate ($DetailLevel)"
        }
        else {
            #User Cancelled the dialog
            Writeinfo "Prompt cancelled"
            Throw "Not all parameters supplied"
        } 
    }    

    $LogLevel--
    WriteInfo -message "Exit:  Validate date range and detail level"
    #endregion: Validate date range and detail level

    #region: Collect EVTX files under SDP path
    WriteInfo -message "ENTER: Collect EVTX files under SDP path"
    $LogLevel++
        
    $EVTXFilter = "*System*.evtx", "*csvfs-op*.evtx"
    WriteInfo "Looking for child items under $SDPPath with recurse named:" -AdditionalStringArray $EVTXFilter
    $EVTXFiles = [array] (Get-ChildItem -include $EVTXFilter -recurse -Path $SDPPath)
    if ($EVTXFiles.Count -gt 0) { 
        WriteInfo "Found the following evtx files" -AdditionalStringArray ($EVTXFiles.Name | Sort-Object)
    }
    else {
        #No files found
        throw "Could not find any files matching criteria."
    }  
    $LogLevel--
    WriteInfo -message "Exit:  Collect EVTX files under SDP path"
    #endregion: Collect EVTX files under SDP path
    
    #Create main progress bar
    Write-Progress -Activity "Main Progress" -Id 0 -PercentComplete 0

    #region: Query events from evtx files
    WriteInfo -message "ENTER: Query events from evtx files"
    $LogLevel++
    
    # Depending on $DetailLevel, decide which event IDs to look for
    $EventIDs = 5120, 5121, 5141, 5142,1135
    if ($DetailLevel -eq "Advanced") {
        $EventIDs += 9296, 8960, 1135,9216,49152
    }
    WriteInfo "Will query the following event IDs: $EventIDs as detail level is $DetailLevel"

    $LoggedEvents = [System.Collections.ArrayList] @()
        
    # Create load evtx progress bae
    $LoadEvtxProgressBar = 0
    Write-Progress -Activity "Load evtx files" -Id 1 -ParentId 0 -PercentComplete 0

    foreach ($LogFile in $EVTXFiles) {
        $LoadEvtxProgressBar ++
        $LoadEvtxProgressPercentage = ($LoadEvtxProgressBar / $EVTXFiles.Count) * 100
        Write-Progress -Activity "Load evtx files" -Id 1 -Status "$LoadEvtxProgressBar/$($EVTXFiles.Count) - $($LogFile.Name)" -ParentId 0 -PercentComplete $LoadEvtxProgressPercentage
        Write-Progress -Activity "Main Progress" -Id 0 -PercentComplete ($LoadEvtxProgressPercentage / 2)

        # Although the Get-WinEvent can take a string of file names as input instead of the forloop here
        # during tests I found that this technique takes less time than asking it to do all files in one line.
        WriteInfo "Processing: $($LogFile.Name)"
        $LogLevel++
        try {                       
            $FilterHashTable = @{
                Path      = $LogFile.FullName
                id        = $EventIDs
                StartTime = $StartDate
                EndTime   = $EndDate 
            }                
            $GetWinEvent = Get-WinEvent -FilterHashtable $FilterHashTable -ErrorAction Stop
            WriteInfo "Found $($GetWinEvent.count) events"
            $LoggedEvents += $GetWinEvent
        }
        catch [Exception] {
            if ($_.Exception -match "No events were found that match the specified selection criteria") {
                Writeinfo "No events found."                             
            }
        }
        $LogLevel--            
    }
        
    Write-Progress -Activity "Load evtx files" -Id 1 -ParentId 0 -Completed
    Write-Progress -Activity "Main Progress" -Id 0 -PercentComplete 50
        
    $LogLevel--
    WriteInfo -message "Exit:  Query events from evtx files"
    #endregion: Query events from evtx files
    
    #region: Parse queried events
    WriteInfo -message "ENTER: Parse queried events"
    $LogLevel++
    
    # Create parse evtx progress bae
    $ParseEvtxProgressBar = 0
    Write-Progress -Activity "Parse evtx " -Id 2 -ParentId 0 -PercentComplete 0

    ForEach ($LoggedEvent in $LoggedEvents) {
        $ParseEvtxProgressBar ++
        $ParseEvtxProgressBarPercentage = ($ParseEvtxProgressBar / $LoggedEvents.Count) * 100
        Write-Progress -Activity "Parse evtx " -Status "$ParseEvtxProgressBar/$($LoggedEvents.Count)" -Id 2 -ParentId 0 -PercentComplete $ParseEvtxProgressBarPercentage
        Write-Progress -Activity "Main Progress" -Id 0 -PercentComplete (50 + $ParseEvtxProgressBarPercentage / 2)

        # Convert the event to XML      
        $EventXML = [xml]$LoggedEvent.ToXml()  
    
        For ($i = 0; $i -lt $EventXML.Event.EventData.Data.Count; $i++) {
            # Append these as object properties 
            
            # Write-Progress -Activity "Analyzing the logs... " -status "$i Events parsed..."  -percentComplete ( $i / $EventXML.Event.EventData.Data.Count * 100) 
                    
            if ($DetailLevel -eq "Advanced") {
                $Currentstate = $EventXML.Event.EventData.Data[$i]| Where-Object {$_.name -eq "CurrentState"}
                $NewState = $EventXML.Event.EventData.Data[$i]| Where-Object {$_.name -eq "NewState"}
                #$Currentstate
                $Curr = $Currentstate."#text"
                $NewS = $NewState."#text"

                switch ( $Curr ) {
                    0 { $EventXML.Event.EventData.Data[$i].'#text' = '0.CsvFsVolumeStateInit Failing all IO or Init State'    }
                    1 { $EventXML.Event.EventData.Data[$i].'#text' = '1.-->[X][CsvFsVolumeStatePaused] IO Paused. All IO drained. All down-level files are closed'    }
                    2 { $EventXML.Event.EventData.Data[$i].'#text' = '2.-->[X][CsvFsVolumeStateDraining] IO Paused. Volume is draining IO.'   }
                    3 { $EventXML.Event.EventData.Data[$i].'#text' = '3.CsvFsVolumeStateSetDownlevel IO Paused. All down-level files are reopened.' }
                    4 { $EventXML.Event.EventData.Data[$i].'#text' = '4.CsvFsVolumeStateActive IO are not blocked and could go direct or redirected IO path '  }
                    5 { $EventXML.Event.EventData.Data[$i].'#text' = '5.CsvFsVolumeStateDismounted Special Init state triggered by a user initiated dismount. '  }
                    6 { $EventXML.Event.EventData.Data[$i].'#text' = '6.CsvFsVolumeStateDismounted switching to block redirection. '  }
                    7 { $EventXML.Event.EventData.Data[$i].'#text' = '7.CsvFsVolumeStateDismounted surprise removal. '  }
                    8 { $EventXML.Event.EventData.Data[$i].'#text' = '8.CsvFsVolumeStateDismounted surprise removal. '  }
                    10 { $EventXML.Event.EventData.Data[$i].'#text' = '10.CsvFsVolumeStateDismounted Volume was added by PnP '  }
                    11 { $EventXML.Event.EventData.Data[$i].'#text' = '11.CsvFsVolumeStateDismounted Volume was removed by PnP. '  }
                    128 { $EventXML.Event.EventData.Data[$i].'#text' = '128.CsvFsVolumeStateDismounted > 128 are transient statest. '  }
            
    
                }
                switch ( $NewS ) {
                    0 { $EventXML.Event.EventData.Data[$i].'#text' = '0.CsvFsVolumeStateInit Failing all IO or Init State'    }
                    1 { $EventXML.Event.EventData.Data[$i].'#text' = '1.-->[X][CsvFsVolumeStatePaused] IO Paused. All IO drained. All down-level files are closed'    }
                    2 { $EventXML.Event.EventData.Data[$i].'#text' = '2.-->[X][CsvFsVolumeStateDraining] IO Paused. Volume is draining IO.'   }
                    3 { $EventXML.Event.EventData.Data[$i].'#text' = '3.CsvFsVolumeStateSetDownlevel IO Paused. All down-level files are reopened.' }
                    4 { $EventXML.Event.EventData.Data[$i].'#text' = '4.CsvFsVolumeStateActive IO are not blocked and could go direct or redirected IO path '  }
                    5 { $EventXML.Event.EventData.Data[$i].'#text' = '5.CsvFsVolumeStateDismounted Special Init state triggered by a user initiated dismount. '  }
                    6 { $EventXML.Event.EventData.Data[$i].'#text' = '6.CsvFsVolumeStateDismounted switching to block redirection. '  }
                    7 { $EventXML.Event.EventData.Data[$i].'#text' = '7.CsvFsVolumeStateDismounted surprise removal. '  }
                    8 { $EventXML.Event.EventData.Data[$i].'#text' = '8.CsvFsVolumeStateDismounted surprise removal. '  }
                    10 { $EventXML.Event.EventData.Data[$i].'#text' = '10.CsvFsVolumeStateDismounted Volume was added by PnP '  }
                    11 { $EventXML.Event.EventData.Data[$i].'#text' = '11.CsvFsVolumeStateDismounted Volume was removed by PnP. '  }
                    128 { $EventXML.Event.EventData.Data[$i].'#text' = '128.CsvFsVolumeStateDismounted > 128 are transient statest. '  }

                }
            }
                
            Add-Member -InputObject $LoggedEvent -MemberType NoteProperty -Force  -Name  $EventXML.Event.EventData.Data[$i].Name  -Value $EventXML.Event.EventData.Data[$i].'#text'        
        }          
    }
    Write-Progress -Activity "Parse evtx " -Id 2 -ParentId 0 -Completed
    Write-Progress -Activity "Main Progress" -Id 0 -Completed
    
    $LogLevel--
    WriteInfo -message "Exit:  Parse queried events"
    #endregion: Parse queried events
    if(Test-Path .\Commonerrors.csv)
    {
    $P = Import-Csv -Path .\Commonerrors.csv 
    $p| out-gridView -title " Help Text : Error Code translataion" 
    }
else {

    WriteError -message "WARNING: Continuing without help text Menu, Copy the Commonerrors.csv in the folder as the script"
    
}
    

    #region: Output parsed events as Grid View
    WriteInfo -message "ENTER: Output parsed events as Grid View"
    $LogLevel++
    
    $Props = "id", "TimeCreated", "MachineName", "ErrorCode" , "status" , "VolumeName", "CountersName", "ReasonCode", "VolumeID", "Source"
    if ($DetailLevel -eq "Advanced") {
        $Props += "DcmSequenceId" , "CurrentState", "NewState"
    }
    writeinfo "Opening Grid View, Press Ok to exit the Window"
    $Selection = $LoggedEvents | Select-Object -Property $Props |Sort-Object -property TimeCreated| Out-GridView -Title "CSVSA - Clustered Shared Volume State Analyzer by Shasankp@microsoft.com - Internal Use Only - $DetailLevel" -PassThru #|Export-Csv -Path .\ProcessLog.csv    
    


    $LogLevel--
    WriteInfo -message "Exit:  Output parsed events as Grid View"
    #endregion: Output parsed events as Grid View
    
   

    if ($Selection) {
        #region: Create HTML File from selection
        WriteInfo -message "ENTER: Create HTML File from selection"
        $LogLevel++
        
        $CSS = @"
            <Style>
            table {
            border: 1px solid #1C6EA4;
            background-color: #EEEEEE;
            width: 100%;
            text-align: left;
            border-collapse: collapse;
            }
            table td, table th {
            border: 1px solid #AAAAAA;
            padding: 3px 2px;
            }
            table tbody td {
            font-size: 13px;
            }
            table tr:nth-child(even) {
            background: #D0E4F5;
            }
            table thead {
            background: #1C6EA4;
            background: -moz-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
            background: -webkit-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
            background: linear-gradient(to bottom, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
            border-bottom: 2px solid #444444;
            }
            table thead th {
            font-size: 15px;
            font-weight: bold;
            color: #FFFFFF;
            border-left: 2px solid #D0E4F5;
            }
            table thead th:first-child {
            border-left: none;
            }
            
            table tfoot td {
            font-size: 14px;
            }
            table tfoot .links {
            text-align: right;
            }
            table tfoot .links a{
            display: inline-block;
            background: #1C6EA4;
            color: #FFFFFF;
            padding: 2px 8px;
            border-radius: 5px;
            }
            </style>    
"@
        $Selection | ConvertTo-Html -PreContent $CSS | Out-File $env:TEMP\UsersReport.html
        Invoke-Expression $env:TEMP\UsersReport.html            
        
        $LogLevel--
        WriteInfo -message "Exit:  Create HTML File from selection"
        #endregion: Create HTML File from selection
      
    }
}
Catch {
    WriteError -message "An Error occured"
    WriteError -message $error[0].Exception.Message
    $ErrorThrown = $true
}
Finally {
    $ScriptEndTimeStamp = Get-Date
    $LogLevel = 0
    WriteInfo -message "Script v$VerMa.$VerMi execution finished."
    Writeinfo -message "Duration: $(New-TimeSpan -Start $ScriptBeginTimeStamp -End $ScriptEndTimeStamp)"

    if ($ErrorThrown) {
        Throw $error[0].Exception.Message
        exit(-1)
    }
    else {
        exit(0)
    }    
}




