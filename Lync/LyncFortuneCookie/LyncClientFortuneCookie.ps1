﻿<# 
.SYNOPSIS
Use the Lync SDK to replace the currently assigned Lync personal note with a random quote from iQuote or a local file.

.DESCRIPTION
Use the Lync SDK to replace the currently assigned Lync personal note with a random quote from iQuote or a local file. The currently assigned quote is displayed
and you are given the option to keep it, replace it, or cancel operations. If you opt not to keep the quote a new random quote will be presented
for consideration.

.PARAMETER QuoteSource
Source of your quotes, either the iQuote website or a local file.

.PARAMETER QuoteCategories
If using iQuote then what category quotes are you wishing to use?

.PARAMETER QuoteFile
If using a local file for your quote source then which file will you be using?

.PARAMETER MaximumAttempts
Number of attempts to check that lync is running.

.PARAMETER WaitBetweenAttempts
Wait time, in seconds, between checking for the lync process.

.PARAMETER StartupWait
Wait time, in seconds, before running the script

.PARAMETER Silent
If true then no pop-ups will be used when displaying status or choosing quote.

.PARAMETER CreateScheduledTask
Create a scheduled task for this script with the current parameters.

.EXAMPLE
.\LyncClientFortuneCookie.ps1 -Silent -CreateScheduledTask

Description
-----------
Run the script to create a scheduled task that runs itself without user input (by default at 9am every monday)

.EXAMPLE
.\LyncClientFortuneCookie.ps1 -CreateScheduledTask -QuoteCategories 'fortune','codehappy'

Description
-----------
Run the script to create a scheduled task that runs itself without user input (by default at 9am every monday). 
When the task runs the iQuote site is queried for a random quote from either fortune or codehappy categories.
The a pop-up is used to prompt the end user if they want to change their Lync note to the quote or not.

.EXAMPLE
.\LyncClientFortuneCookie.ps1 -CreateScheduledTask -QuoteSource 'File' -QuoteFile 'example-quotes.txt'

Description
-----------
Run the script to create a scheduled task that runs itself. When the scheduled task triggers and the lync client is logged into a the example-quotes.txt file
will be polled for a random quote and the current user will be prompted if they want to replace their current status note in Lync or not.

.EXAMPLE
.\LyncClientFortuneCookie.ps1 -CreateScheduledTask -QuoteSource 'File' -QuoteFile 'example-quotes.txt' -Silent

Description
-----------
Same as the prior example except it is assumed that all the quotes in example-quotes.txt are acceptable and the random quote is simply assigned in Lync silently.

.NOTES
Author: Zachary Loeber
Version History:
    1.0 - 02/12/2014
        - Initial Release

.LINK
www.the-little-things.net

.LINK
https://github.com/zloeber/Powershell/Lync
#> 

param(
    [parameter(HelpMessage='Source of your quotes, either the iQuote website or a local file.')]
    [ValidateSet('iQuote','File')]
    [string]$QuoteSource = 'File',
    [Parameter(HelpMessage='If using iQuote then what category quotes are you wishing to use?')]
    [string[]]$QuoteCategories = @(),
    [Parameter(HelpMessage='If using a local file for your quote source then which file will you be using?')]
    [ValidateScript({
        Test-Path $_
    })]
    [string]$QuoteFile = 'example-quotes.txt',
    [Parameter(HelpMessage='Number of attempts to check that lync is running.')]
    [int]$MaximumAttempts = 5,
    [Parameter(HelpMessage='Wait time, in seconds, between checking for the lync process.')]
    [int]$WaitBetweenAttempts = 20,
    [Parameter(HelpMessage='Wait time, in seconds, before running the script.')]
    [int]$StartupWait = 5,
    [Parameter(HelpMessage='If true then no pop-ups will be used when displaying status or choosing quote.')]
    [switch]$Silent,
    [Parameter(HelpMessage='Create a scheduled task for this script with the current parameters.')]
    [switch]$CreateScheduledTask
)

#Region Global Configuration

#EndRegion Global Configuration
function Get-ScriptName { 
    if($hostinvocation -ne $null) {
        $hostinvocation.MyCommand.path
    }
    else {
        $script:MyInvocation.MyCommand.Path
    }
}

function New-Popup {
    param (
        [Parameter(Position=0,Mandatory=$True,HelpMessage="Enter a message for the popup")]
        [ValidateNotNullorEmpty()]
        [string]$Message,
        [Parameter(Position=1,Mandatory=$True,HelpMessage="Enter a title for the popup")]
        [ValidateNotNullorEmpty()]
        [string]$Title,
        [Parameter(Position=2,HelpMessage="How many seconds to display? Use 0 require a button click.")]
        [ValidateScript({$_ -ge 0})]
        [int]$Time=0,
        [Parameter(Position=3,HelpMessage="Enter a button group")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("OK","OKCancel","AbortRetryIgnore","YesNo","YesNoCancel","RetryCancel")]
        [string]$Buttons="OK",
        [Parameter(Position=4,HelpMessage="Enter an icon set")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("Stop","Question","Exclamation","Information" )]
        [string]$Icon="Information"
    )

    #convert buttons to their integer equivalents
    switch ($Buttons) {
        "OK"               {$ButtonValue = 0}
        "OKCancel"         {$ButtonValue = 1}
        "AbortRetryIgnore" {$ButtonValue = 2}
        "YesNo"            {$ButtonValue = 4}
        "YesNoCancel"      {$ButtonValue = 3}
        "RetryCancel"      {$ButtonValue = 5}
    }

    #set an integer value for Icon type
    switch ($Icon) {
        "Stop"        {$iconValue = 16}
        "Question"    {$iconValue = 32}
        "Exclamation" {$iconValue = 48}
        "Information" {$iconValue = 64}
    }

    #create the COM Object
    Try {
        $wshell = New-Object -ComObject Wscript.Shell -ErrorAction Stop
        #Button and icon type values are added together to create an integer value
        $wshell.Popup($Message,$Time,$Title,$ButtonValue+$iconValue)
    }
    Catch {
        Write-Warning "Failed to create Wscript.Shell COM object"
        Write-Warning $_.exception.message
    }
}

function New-ScheduledPowershellTask {
    <#
    .SYNOPSIS
    Create a scheduled task.
    .DESCRIPTION
    Create a scheduled task.
    .PARAMETER TaskName
    Name of the task to create in task scheduler
    .PARAMETER 

    .LINK
    http://www.the-little-things.net
    .LINK
    https://github.com/zloeber/Powershell/
    .NOTES
    Last edit   :   
    Version     :   
    Author      :   Zachary Loeber

    .EXAMPLE


    Description
    -----------
    TBD
    #>
    [CmdLetBinding()]
    param(
        [Parameter(Position=0, HelpMessage='Task name. If not set a random GUID will be used for the task name.')]
        [string]$TaskName,
        [Parameter(Position=1, HelpMessage='Task folder (in task manager).')]
        [string]$TaskFolder = '\',
        [Parameter(Position=2, HelpMessage='Task description.')]
        [string]$TaskDescription,
        [Parameter(Position=3, HelpMessage='Task frequency (2 = daily, 3 = weekly).')]
        [int]$TaskFrequency = 2,
        [Parameter(Position=4, HelpMessage='Task days to run if freqency is set to weekly.')]
        [int]$TaskDaysOfWeek = 0,
        [Parameter(Position=5, HelpMessage='User to run the task as. If not set then it will run as the current logged in user.')]
        [string]$TaskUser,
        [Parameter(Position=6, HelpMessage='Password of user running the task.')]
        [string]$TaskPassword,
        [Parameter(Position=7, HelpMessage='User to run the task as.')]
        [string]$TaskLoginType,
        [Parameter(Position=8, HelpMessage='Task script.')]
        [string]$TaskScript,
        [Parameter(Position=8, HelpMessage='Path to run the scheduled task within.')]
        [string]$TaskRunPath,
        [Parameter(Position=9, HelpMessage='Powershell arguments.')]
        [string]$PowershellArgs = '-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted',
        [Parameter(Position=10, HelpMessage='Task Script Arguments.')]
        [string]$TaskScriptArgs,
        [Parameter(Position=11, HelpMessage='Task Start Time (defaults to 3AM tonight).')]
        [datetime]$TaskStartTime = $(Get-Date "$(((Get-Date).AddDays(1)).ToShortDateString()) 3:00 AM")
    )
    begin {
        # The Task Action command
        $TaskCommand = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"

        # The Task Action command argument
        $TaskArg = "$PowershellArgs `"& `'$TaskScript`' $TaskScriptArgs`""
        
        switch ($TaskLoginType) {
            'TASK_LOGON_NONE' { $_TaskLoginType = 0 }
            'TASK_LOGON_PASSWORD' { $_TaskLoginType = 1 }
            'TASK_LOGON_INTERACTIVE_TOKEN' { $_TaskLoginType = 3 }
            default { $_TaskLoginType = 5 }
        }
 
    }
    process {}
    end {
        try {
            # attach the Task Scheduler com object
            $service = new-object -ComObject('Schedule.Service')
            # connect to the local machine. 
            # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx
            $service.Connect()
            $rootFolder = $service.GetFolder($TaskFolder)
             
            $TaskDefinition = $service.NewTask(0) 
            $TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
            $TaskDefinition.Settings.Enabled = $true
            $TaskDefinition.Settings.AllowDemandStart = $true
             
            $triggers = $TaskDefinition.Triggers
            #http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
            $trigger = $triggers.Create($TaskFrequency)
            $trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
            $trigger.Enabled = $true
            if ($TaskFrequency -eq 3) {
                $trigger.DaysOfWeek = [Int16]$TaskDaysOfWeek
            }
             
            # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
            $Action = $TaskDefinition.Actions.Create(0)
            $action.Path = "$TaskCommand"
            $action.Arguments = "$TaskArg"
            if ($TaskRunPath) {
                $Action.WorkingDirectory = $TaskRunPath
            }

            #http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
            $rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,$TaskUser,$TaskPassword,$_TaskLoginType) | Out-Null
        }
        catch {
            throw
        }
    }
}

function Load-LyncSDK {
    [CmdLetBinding()]
    param(
        [Parameter(Position=0, HelpMessage='Full SDK location (ie C:\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll). If not defined then typical locations will be attempted.')]
        [string]$SDKLocation
    )
    $LyncSDKLoaded = $false
    if (-not (Get-Module -Name Microsoft.Lync.Model)) {
        if (($SDKLocation -eq $null) -or ($SDKLocation -eq '')) {
            try { # Try loading the 32 bit version first
                Import-Module -Name (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
                $LyncSDKLoaded = $true
            }
            catch {}
            try { # Otherwise try the 64 bit version
                Import-Module -Name (Join-Path -Path ${env:ProgramFiles} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
                $LyncSDKLoaded = $true
            }
            catch {}
        }
        else {
            try {
                Import-Module -Name $SDKLocation -ErrorAction Stop
                $LyncSDKLoaded = $true
            }
            catch {}
        }
    }
    else {
        $LyncSDKLoaded = $true
    }
    return $LyncSDKLoaded
}

function Publish-LyncContactInformation {
    <#
    .SYNOPSIS
    Publish-LyncContactInformation is a PowerShell function to configure a set of settings in the Microsoft Lync client.
    .DESCRIPTION
    The purpose of Publish-LyncContactInformation is to demonstrate how PowerShell can be used to interact with the Lync SDK.
    Tested with Lync 2013 only.
    Prerequisites: Lync 2013 SDK - http://www.microsoft.com/en-us/download/details.aspx?id=36824
    .EXAMPLE
    Publish-LyncContactInformation -Availability Available
    .EXAMPLE
    Publish-LyncContactInformation -Availability Away
    .EXAMPLE
    Publish-LyncContactInformation -Availability "Off Work" -ActivityId off-work
    .EXAMPLE
    Publish-LyncContactInformation -PersonalNote test
    .EXAMPLE
    Publish-LyncContactInformation -Availability Available -PersonalNote ("Quote of the day: " + (Get-QOTD))
    .EXAMPLE
    Publish-LyncContactInformation -Location Work
    .NOTES
    For more information, see the related blog post at blog.powershell.no
    .FUNCTIONALITY
    Provides a function to configure Availability, ActivityId and PersonalNote for the Microsoft Lync client.
    #>

    param(
    [ValidateSet("Appear Offline","Available","Away","Busy","Do Not Disturb","Be Right Back","Off Work")]
    [string]$Availability,
    [string]$ActivityId,
    [string]$PersonalNote,
    [string]$Location
    )

    $LyncSDKLoaded = Load-LyncSDK
    if (-not $LyncSDKLoaded) {
        Write-Error "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
        break
    }

    $Client = [Microsoft.Lync.Model.LyncClient]::GetClient()

    if ($Client.State -eq "SignedIn") {
        $Self = $Client.Self
        $ContactInfo = New-Object 'System.Collections.Generic.Dictionary[Microsoft.Lync.Model.PublishableContactInformationType, object]'
        switch ($Availability) {
            "Available" {$AvailabilityId = 3000}
            "Appear Offline" {$AvailabilityId = 18000}
            "Away" {$AvailabilityId = 15000}
            "Busy" {$AvailabilityId = 6000}
            "Do Not Disturb" {$AvailabilityId = 9000}
            "Be Right Back" {$AvailabilityId = 12000}
            "Off Work" {$AvailabilityId = 15500}
        }

        if ($Availability) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::Availability, $AvailabilityId)
        }

        if ($ActivityId) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::ActivityId, $ActivityId)
        }

        if ($PersonalNote) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::PersonalNote, $PersonalNote)
        }

        if ($Location) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::LocationName, $Location)
        }

        if ($ContactInfo.Count -gt 0) {
            $Publish = $Self.BeginPublishContactInformation($ContactInfo, $null, $null)
            $self.EndPublishContactInformation($Publish)
        } 
        else {
            Write-Warning "No options supplied, no action was performed"
        }
    }
    else {
        Write-Warning "Lync is not running or signed in, no action was performed"
    }
}

function Get-LyncPersonalContactInfo {
    <#
    .EXAMPLE
    Get-LyncPersonalContactInfo 'PersonalNote'
    .EXAMPLE
    Get-LyncPersonalContactInfo
    #>
    param(
        [string[]]$TypeNames
    )

    $LyncSDKLoaded = Load-LyncSDK
    if (-not $LyncSDKLoaded) {
        Write-Error "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
        break
    }

    $validtypes = @()
    [System.Enum]::GetNames('Microsoft.Lync.Model.ContactInformationType') | Foreach {$validtypes += $_}
    if ($TypeNames.Count -eq 0) {$TypeNames += $validtypes}
    if ((Compare-Object -ReferenceObject $validtypes -DifferenceObject $TypeNames).SideIndicator -contains '=>') {
        Write-Error 'Invalid contact information type requested!'
        break
    }
    else {
        $client = [Microsoft.Lync.Model.LyncClient]::GetClient()
        if ($client.State -eq "SignedIn") {
            $contact = $client.Self.Contact
            $retvals = @{}
            foreach ($typename in $TypeNames) {
                try {
                    $contact.GetContactInformation([Microsoft.Lync.Model.ContactInformationType]::$typename) | Out-Null
                    if ($TypeNames.Count -gt 1) {
                        $retvals.$typename = $contact.GetContactInformation([Microsoft.Lync.Model.ContactInformationType]::$typename)
                    }
                    else {
                        return $contact.GetContactInformation([Microsoft.Lync.Model.ContactInformationType]::$typename)
                    }
                }
                catch {}
            }
            New-Object psobject -Property $retvals
        }
        else {
            Write-Warning "Lync is not running or signed in, no action was performed"
        }
    }
}

function Get-iQuote {
    <#
    #Valid Sources
    #From geek: esr humorix_misc humorix_stories joel_on_software macintosh math mav_flame osp_rules paul_graham prog_style subversion
    #From general: 1811_dictionary_of_the_vulgar_tongue codehappy fortune liberty literature misc murphy oneliners riddles rkba shlomif shlomif_fav stephen_wright
    #From pop: calvin forrestgump friends futurama holygrail powerpuff simon_garfunkel simpsons_cbg simpsons_chalkboard simpsons_homer simpsons_ralph south_park starwars xfiles
    #From religious: bible contentions osho
    #From scifi: cryptonomicon discworld dune hitchhiker
    
    # Example
    Get-iQuote -max_lines 2 -source @('esr','math')
    #>

    param (
        [Parameter(Position=0,HelpMessage='return format of quote')]
        [ValidateSet('text','html','json')]
        [string]$format = 'text',
        [Parameter(Position=1,HelpMessage='Maximum number of lines to return')]
        [int]$max_lines,
        [Parameter(Position=2,HelpMessage='Minimum number of lines to return')]
        [int]$min_lines,
        [Parameter(Position=3,HelpMessage='Maximum number of characters to return')]
        [int]$max_characters,
        [Parameter(Position=4,HelpMessage='Minimum number of characters to return')]
        [int]$min_characters,
        [Parameter(Position=5,HelpMessage='One or more quote categories to query.')]
        [ValidateScript({
            $validsources = @('esr','humorix_misc','humorix_stories','joel_on_software','macintosh','math','mav_flame','osp_rules','paul_graham','prog_style','subversion','1811_dictionary_of_the_vulgar_tongue','codehappy','fortune','liberty','literature','misc','murphy','oneliners','riddles','rkba','shlomif','shlomif_fav','stephen_wright','calvin','forrestgump','friends','futurama','holygrail','powerpuff','simon_garfunkel','simpsons_cbg','simpsons_chalkboard','simpsons_homer','simpsons_ralph','south_park','starwars','xfiles','bible','contentions','osho','cryptonomicon','discworld','dune','hitchhiker')
            if ((Compare-Object -ReferenceObject $validsources -DifferenceObject $_).SideIndicator -contains '=>') {
                $false
            }
            else {
                $true
            }
        })]
        [string[]]$source = @('esr','humorix_misc','humorix_stories','joel_on_software','macintosh','math','mav_flame','osp_rules','paul_graham','prog_style','subversion','1811_dictionary_of_the_vulgar_tongue','codehappy','fortune','liberty','literature','misc','murphy','oneliners','riddles','rkba','shlomif','shlomif_fav','stephen_wright','calvin','forrestgump','friends','futurama','holygrail','powerpuff','simon_garfunkel','simpsons_cbg','simpsons_chalkboard','simpsons_homer','simpsons_ralph','south_park','starwars','xfiles','bible','contentions','osho','cryptonomicon','discworld','dune','hitchhiker')
    )
    $req_uri = 'http://www.iheartquotes.com/api/v1/random?format=' + $format 
    $PSBoundParameters.Keys | Foreach {
        if ($_ -ne 'format') {
            $paramval = 
            $req_uri += '&' + $_ + '=' + ($PSBoundParameters[$_] -join '+')
        }
    }

    $sources = ($source | % { [regex]::escape($_) } ) -join '|'
    $sourceregex = '(?m)^([^\[]*)(?:\[(' + $sources + ')\].+)$'
    
    $quote = (Invoke-WebRequest -Uri $req_uri).content

    ((([regex]::Match($quote,$sourceregex)).Groups)[1]).Value -replace '&quot;','"'
}

if ($CreateScheduledTask) {
    $ScriptName = Get-ScriptName
    $ScriptPath = Split-Path $ScriptName -Parent
    $TaskScriptArgs = ''
    $PSBoundParameters.Keys | Foreach {
        if ($_ -ne 'CreateScheduledTask') {
            if ($_ -eq 'QuoteFile') {
                $TaskScriptArgs += ' -' + $_ + ':' + "'" + $QuoteFile +"'"
            }
            elseif ($_ -eq 'QuoteCategories') {
                if ($QuoteCategories.Count -eq 1) {
                    $qcategories = "'" + $QuoteCategories + "'"
                }
                else {
                    $qcategories = "@('" + ($QuoteCategories -join "','") + "')"
                }
                $TaskScriptArgs += ' -' + $_ + ':' + $qcategories
            }
            elseif ($_ -eq 'Silent') {
                if ($Silent) {
                    $TaskScriptArgs += ' -Silent'
                }
            }
            else {
                $TaskScriptArgs += ' -' + $_ + ':' + $PSBoundParameters[$_]
            }
        }
    }
    # Get us to next Monday
    $currDate = Get-Date
    while ($currDate.DayOfWeek -ne 'Monday') {
        $currDate = $currDate.AddDays(1)
    }
    New-ScheduledPowershellTask -TaskName 'Lync Fortune Cookie Updater' `
                                -TaskDescription 'Lync Fortune Cookie Updater' `
                                -TaskScript $ScriptName `
                                -TaskScriptArgs $TaskScriptArgs `
                                -TaskFrequency 3 `
                                -TaskDaysOfWeek 2 `
                                -TaskStartTime $(Get-Date "$(($currdate).ToShortDateString()) 9:00 AM") `
                                -TaskLoginType 'TASK_LOGON_INTERACTIVE_TOKEN' `
                                -TaskRunPath $ScriptPath
                                
    Write-Output "Assuming there were no errors, the scheduled task has been created on the localhost as `'Lync Fortune Cookie Updater`'"
    Write-Output "  You still need to go into scheduled tasks and modify the task to run at a frequency to suit your needs. The default "
    Write-Output "  frequency is every Monday morning at 9:00 AM."
    break
}

# Validate that the Lync SDK is available
$LyncSDKLoaded = $true
$LyncSDKLoaded = Load-LyncSDK
if (-not $LyncSDKLoaded) {
    if (-not $Silent) {
        New-Popup -Buttons 'OK' -Message "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824" -Title 'No Mojo :('
    }

    break
}

# Wait for a bit before attempting to run the script
Sleep -Seconds $StartupWait

$LyncRunning = $false
$AttemptCount = 0
do {
    $AttemptCount++
    try {
        # Is lync.exe actually running?
        Get-Process -Name Lync -ErrorAction Stop | Out-Null

        # Yes? Ok, lets get the the running client information
        $LyncClient = [Microsoft.Lync.Model.LyncClient]::GetClient()
        $LyncRunning = $true
    }
    catch {
        # No? Then wait a while and try again
        Sleep -Seconds $WaitBetweenAttempts
    }
} until (($LyncRunning) -or ($AttemptCount -eq $MaximumAttempts))

$LyncReady = $false
if ($LyncRunning) {
    # There is a miniscule chance the app opened, we got the client info, the the user closed the app
    if (($LyncClient.State -ne 'Invalid')) {
        $AttemptCount = 0
        do {
            $AttemptCount++
            Sleep -Seconds $WaitBetweenAttempts
        } until (($LyncClient.State -eq 'SignedIn') -or ($AttemptCount -eq $MaximumAttempts))
        if ($LyncClient.State -eq 'SignedIn') {
            $LyncReady = $true
        }
    }
}

if ($LyncReady) {
    $CurrentQuote = Get-LyncPersonalContactInfo 'PersonalNote'
    if (($CurrentQuote -eq '') -or ($CurrentQuote -eq $null)) {
        $CurrentQuote = '** None Set - You are kinda boring :( **'
    }
    switch ($QuoteSource) {
        'iQuote' {
            do {
                if ($QuoteCategories.Count -eq 0) {
                    $quote = Get-iQuote
                }
                else {
                    $quote = Get-iQuote -source $QuoteCategories
                }
                if (-not $Silent) {
                    $Response = New-Popup -Buttons 'YesNoCancel' -Icon 'Question' -Message "Replace your current quote:`n`r`n`r$($CurrentQuote)`n`r`n`rWith this quote?`n`r`n`r$quote`n`r`n`rPress 'Cancel' to do nothing`n`rPress 'No' to get another quote`n`rPress 'Yes' to accept this quote as your personal note" -Title 'Replace?'
                    if ($Response -eq '6') {
                        Publish-LyncContactInformation -PersonalNote $quote
                    }
                    else {
                        # Be nice and try not to spam the site
                        Sleep -Seconds 3
                    }
                }
                else {
                    Publish-LyncContactInformation -PersonalNote $quote
                }
            } while ($Response -eq '7')
        }
        'File' {
            $quotedata = Get-Content $QuoteFile
            do {
                $randomquoteline = Get-Random -Minimum 0 -Maximum ($quotedata.Count + 1)
                $quote = $quotedata[$randomquoteline]
                if (-not $Silent) {
                    $Response = New-Popup -Buttons 'YesNoCancel' -Icon 'Question' -Message "Replace your current quote:`n`r`n`r$($CurrentQuote)`n`r`n`rWith this quote?`n`r`n`r$quote`n`r`n`rPress 'Cancel' to do nothing`n`rPress 'No' to get another quote`n`rPress 'Yes' to accept this quote as your personal note" -Title 'Replace?'
                    if ($Response -eq '6') {
                        Publish-LyncContactInformation -PersonalNote $quote
                    }
                }
                else {
                    Publish-LyncContactInformation -PersonalNote $quote
                }
            } while ($Response -eq '7')
        }
    }
}
