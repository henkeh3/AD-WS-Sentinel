<# 
.NOTES
===========================================================================
Created on:   August 2022
Created by:   Henrik N
Organization: Atea
Filename:     createDataFactoryResources.ps1
===========================================================================
.DESCRIPTION
Creates 500 users in active directory

#>

$logfile = "C:\Temp\logs\Provision-Users-$(get-date -f "yyyy-MM-dd_HH.mm").csv"

###############################################################################
# Function Write-ToLog
###############################################################################
function Write-ToLog
{
    param ([Parameter(Mandatory = $true)]
    [string]$logstring,
    [switch]$Info,
    [switch]$Warning,
    [switch]$Error,
    [Parameter(Mandatory = $true)]
    [string]$logfilepath
    )
    $currentDate = (Get-Date -UFormat "%Y-%m-%d")
    $currentTime = (Get-Date -UFormat "%T")
    if (-not (Test-Path ($logfilepath | split-path))) { new-item -ItemType Directory -Path ($logfilepath | split-path) | Out-Null }
    if (-not (Test-Path $logfilepath)) { 
            new-item -ItemType File -Path $logfilepath | Out-Null 
            Add-Content $logfilepath "Errorlevel; Date; Time; Logstring "   
                }
    if ($info.IsPresent)
    {
        Add-Content $logfilepath "Info; $currentDate; $currentTime; $logstring" -Encoding UTF8
        Write-Host "Info: $currentDate $currentTime | $logstring" -ForegroundColor Green
    }
    if ($warning.IsPresent)
    {
        Add-Content $logfilepath "Warning; $currentDate; $currentTime; $logstring" -Encoding UTF8
        Write-Host "Warning: $currentDate $currentTime | $logstring " -ForegroundColor Yellow
    }
    if ($error.IsPresent)
    {
        Add-Content $logfilepath "Error; $currentDate; $currentTime; $logstring" -Encoding UTF8
        Write-Host "Error: $currentDate $currentTime | $logstring " -ForegroundColor Red
    }
} #End function Write-ToLog
function Remove-Diacritics
{ 
    param
    (
        [ValidateNotNullOrEmpty()]
        [Alias('Text')]
        [System.String]$String,
        [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    )
    
    BEGIN
    {
        $Normalized = $String.Normalize($NormalizationForm)
        $NewString = New-Object -TypeName System.Text.StringBuilder
        
    }
    PROCESS
    {
        $normalized.ToCharArray() | ForEach-Object -Process {
            if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($psitem) -ne [Globalization.UnicodeCategory]::NonSpacingMark)
            {
                [void]$NewString.Append($psitem)
            }
        }
    }
    END
    {
        return $($NewString -as [string])
    }
}

Write-ToLog -Info -logstring "Scriptexecution started" -logfilepath $logfile
Write-ToLog -Info -logstring "Script executed as user $($env:USERNAME)" -logfilepath $logfile

try
{
    # Create User OU 
    New-ADOrganizationalUnit -Name "Corp"
    New-ADOrganizationalUnit -Name "Users" -Path "OU=Corp,DC=labdomain,DC=com"
    
    Write-ToLog -Info -logstring "Created OU OU=Users=OU=Corp,DC=labdomain,DC=com" -logfilepath $logfile

    # Get names
    $Names = Invoke-RestMethod -Uri "https://api.namnapi.se/v2/names.json?limit=2000" -Method Get
}
catch
{
    Write-ToLog -Warning -logstring "$_.exception.message" -logfilepath $logfile
}

# Citys
$Citys = @("Östersund","Åre","Luleå","Piteå","Skellefteå","Stockholm","Göteborg","Malmö","Örebro","Skinnskatteberg","Linköping","Enköping","Lund")

foreach ($Name in $Names.names)
{
    
    $city = $(get-random $Citys)

    $userParams = @{
        Givenname = $Name.firstname
        Surname = $Name.surname
        Name = "$($Name.firstname) $($Name.surname), $($city)"
        DisplayName = "$($Name.firstname) $($Name.surname), $($city)"
        City = $city
        Samaccountname = "$($Name.firstname.Substring(0,2).tolower())$($Name.surname.Substring(0,2).tolower())$(get-random -Minimum 0001 -Maximum 9999)"
        AccountPassword = $("aa1234567!!" | ConvertTo-SecureString -AsPlainText -Force)
        ChangePasswordAtLogon = $false
        Enabled = $true
        Path = "OU=Users,OU=Corp,DC=labdomain,DC=com"
        UserPrincipalName = Remove-Diacritics "$($Name.firstname.ToLower()).$($Name.surname.ToLower())@labdomain.com"
        Description = "vanlig användare i $($city)"
        

    }

    try
    {
        New-Aduser @userParams -ErrorAction SilentlyContinue 
        Write-ToLog -Info -logstring "Created User $($userParams.displayname)" -logfilepath $logfile
    }
    catch
    {
        Write-ToLog -Warning -logstring "$_.exception.message" -logfilepath $logfile
    }

}

