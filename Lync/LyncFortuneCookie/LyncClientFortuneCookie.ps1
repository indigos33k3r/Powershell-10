<#
.SYNOPSIS
Use the Lync SDK to replace the currently assigned Lync personal note with a random quote from iQuote
.DESCRIPTION
Use the Lync SDK to replace the currently assigned Lync personal note with a random quote from iQuote. The currently assigned quote is displayed
and you are given the option to keep it, replace it, or cancel operations. If you opt not to keep the quote a new random quote will be presented
for consideration.
.LINK
http://the-little-things.net/
.LINK
https://github.com/zloeber/Powershell/Lync
.NOTES
Author:  Zachary Loeber
Version History: 
    02/08/2015
    - Initial release (iQuote source only)
#>

#Region Configuration
$QuoteSource = 'iQuote'     #Valid values are iQuote or file
$QuoteCategories = @('esr','humorix_misc','humorix_stories','joel_on_software','macintosh','math','mav_flame','osp_rules','paul_graham','prog_style','subversion','1811_dictionary_of_the_vulgar_tongue','codehappy','fortune','liberty','literature','misc','murphy','oneliners','riddles','rkba','shlomif','shlomif_fav','stephen_wright','calvin','forrestgump','friends','futurama','holygrail','powerpuff','simon_garfunkel','simpsons_cbg','simpsons_chalkboard','simpsons_homer','simpsons_ralph','south_park','starwars','xfiles','bible','contentions','osho','cryptonomicon','discworld','dune','hitchhiker')
$QuoteFile = 'example-quotes.txt'   #Only applicable when QuoteSource is set to 'file'
$MaximumAttempts = 5    # Number of attempts to check that lync is running
$WaitBetweenAttempts = 1 # Wait time, in seconds, between checking for the lync process
$StartupWait = 3 # Wait time, in seconds, before running the script
$Silent = $true # If true then no pop-ups will be used when displaying status or choosing quote.
#EndRegion

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

    $LyncSDKLoaded = $true
    if (-not (Get-Module -Name Microsoft.Lync.Model)) {
        $LyncSDKLoaded = $false
        try { # Try loading the 32 bit version first
            Import-Module -Name (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
            $LyncSDKLoaded = $true
        }
        catch {}
        try { # Otherwise try the 64 bit version
            Import-Module -Name (Join-Path -Path ${env:ProgramFiles} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
            $LyncSDKLoaded = $true
        }
        catch {
            New-Popup -Buttons 'OK' -Message 'Lync 2013 SDK unavailable. Please download and install from http://www.microsoft.com/en-us/download/details.aspx?id=36824' -Title 'Whoops!'
            #Write-Warning "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
            break
        }
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

    if (-not (Get-Module -Name Microsoft.Lync.Model)) {
        $LyncSDKLoaded = $false
        try { # Try loading the 32 bit version first
            Import-Module -Name (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
        }
        catch {}
        try { # Otherwise try the 64 bit version
            Import-Module -Name (Join-Path -Path ${env:ProgramFiles} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
        }
        catch {
            #New-Popup -Buttons 'OK' -Message 'Lync 2013 SDK unavailable. Please download and install from http://www.microsoft.com/en-us/download/details.aspx?id=36824' -Title 'Whoops!'
            Write-Warning "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
            throw
        }
    }
    $validtypes = @()
    [System.Enum]::GetNames('Microsoft.Lync.Model.ContactInformationType') | Foreach {$validtypes += $_}
    if ($TypeNames.Count -eq 0) {$TypeNames += $validtypes}
    if ((Compare-Object -ReferenceObject $validtypes -DifferenceObject $TypeNames).SideIndicator -contains '=>') {
        Write-Error 'Invalid contact information type requested!'
        throw
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

# Validate that the Lync SDK is available
$LyncSDKLoaded = $true
if (-not (Get-Module -Name Microsoft.Lync.Model)) {
    $LyncSDKLoaded = $false
    try { # Try loading the 32 bit version first
        Import-Module -Name (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
        $LyncSDKLoaded = $true
    }
    catch {}
    try { # Otherwise try the 64 bit version
        Import-Module -Name (Join-Path -Path ${env:ProgramFiles} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
        $LyncSDKLoaded = $true
    }
    catch {
        if ($Silent) {
            Write-Warning "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
        }
        else {
            New-Popup -Buttons 'OK' -Message 'Lync 2013 SDK unavailable. Please download and install from http://www.microsoft.com/en-us/download/details.aspx?id=36824' -Title 'Whoops!'
        }
        break
    }
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
    switch ($QuoteSource) {
        'iQuote' {
            do {
                $quote = Get-iQuote -source $QuoteCategories
                $Response = New-Popup -Buttons 'YesNoCancel' -Icon 'Question' -Message "Replace your current quote:`n`r`n`r$($CurrentQuote)`n`r`n`rWith this quote?`n`r`n`r$quote`n`r`n`rPress 'Cancel' to do nothing or 'No' to get another quote" -Title 'Replace?'
                if ($Response -eq '6') {
                    Publish-LyncContactInformation -PersonalNote $quote
                }
                else {
                    # Be nice and try not to spam the site
                    Sleep -Seconds 3
                }
            } while ($Response -eq '7')
        }
        'File' {
            # Coming soon!
        }
    }
}