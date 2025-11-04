<# 
.NOTES
===========================================================================
Created on:   August 2022
Created by:   Henrik N
Organization: Atea
Filename:     Provision-users.ps1
===========================================================================
.DESCRIPTION
Creates 2000 users in active directory

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
   $fqdn = (get-addomain).DistinguishedName

   [adsi]::Exists("LDAP://OU=Corp,$($fqdn)")
   
    # Create User OU 
    if (! ([adsi]::Exists("LDAP://OU=Corp,$($fqdn)")))
    {
        New-ADOrganizationalUnit -Name "Corp"
    }
    if (! ([adsi]::Exists("LDAP://OU=Users,OU=Corp,$($fqdn)")))
    {
        New-ADOrganizationalUnit -Name "Users" -Path "OU=Corp,$($fqdn)"
    }
    if (! ([adsi]::Exists("LDAP://OU=MemberServers,OU=Corp,$($fqdn)")))
    {
        New-ADOrganizationalUnit -Name "MemberServers" -Path "OU=Corp,$($fqdn)"
    }
    if (! ([adsi]::Exists("LDAP://OU=HiSecServers,OU=Corp,$($fqdn)")))
    {
        New-ADOrganizationalUnit -Name "HiSecServers" -Path "OU=Corp,$($fqdn)"
    }
    if (! ([adsi]::Exists("LDAP://OU=Workstations,OU=Corp,$($fqdn)")))
    {
        New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Corp,$($fqdn)"
    }
    
    Write-ToLog -Info -logstring "Created OU:s in OU=Corp,$($fqdn)" -logfilepath $logfile

    # Get names and remove duplicates and whitespaces
    $namearray = @()
    $Names = Invoke-RestMethod -Uri "https://api.namnapi.se/v2/names.json?limit=2500" -Method Get
    foreach ($name in $names.names)
    {
        $object = New-Object -TypeName psobject
        $object | Add-Member -MemberType NoteProperty -Name "FirstName" -Value "$($name.firstname.Replace(' ',''))"
        $object | Add-Member -MemberType NoteProperty -Name "SurName" -Value "$($name.surname.Replace(' ',''))"
        $object | Add-Member -MemberType NoteProperty -Name "BothNames" -Value "$($name.firstname.Replace(' ',''))$($name.surname.Replace(' ',''))"
        $namearray += $object

    }

    $uniqueNames = $namearray | Sort-Object bothnames -Unique | Select-Object -First 2000
}
catch
{
    Write-ToLog -Warning -logstring "$_.exception.message" -logfilepath $logfile
}

# Citys
$Citys = @("Edsbyn","Orrenjarka","Boden","Kiruna","Helsingborg","Stockholm","Hallstahammar","Lund","Nora","Skinnskatteberg","Mora","Sundsvall","Hudiksvall")

foreach ($Name in $uniqueNames)
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
        Path = "OU=Users,OU=Corp,$($fqdn)"
        UserPrincipalName = Remove-Diacritics "$($Name.firstname.ToLower()).$($Name.surname.ToLower())@labdomain.com"
        Description = "User located in office $($city)"
        

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

# Move servers and workstations to corresponding OU

try
{
    $computersToMove = get-adcomputer -filter * -SearchBase "CN=Computers,$($fqdn)" -Properties operatingsystem


    foreach ($computer in $computersToMove)
    {
        if ($computer.name -match "memberServer-01")
        {
            Move-ADObject -Identity $computer.DistinguishedName -TargetPath "OU=MemberServers,OU=Corp,$($fqdn)"
            Write-ToLog -Info -logstring "moved object $($computer.name) to OU=MemberServers,OU=Corp,$($fqdn)" -logfilepath $logfile
        }
        elseif ($computer.name -match "hisecServer-01")
        {
            Move-ADObject -Identity $computer.DistinguishedName -TargetPath "OU=HiSecServers,OU=Corp,$($fqdn)"
            Write-ToLog -Info -logstring "moved object $($computer.name) to OU=HiSecServers,OU=Corp,$($fqdn)" -logfilepath $logfile
        }
        elseif ($computer.name -match "win11-Client-01|win10-Client-01")
        {
            Move-ADObject -Identity $computer.DistinguishedName -TargetPath "OU=Workstations,OU=Corp,$($fqdn)"
            Write-ToLog -Info -logstring "moved object $($computer.name) to OU=Workstations,OU=Corp,$($fqdn)" -logfilepath $logfile
        }
        
    }
}
catch
{
    Write-ToLog -Warning -logstring "$_.exception.message" -logfilepath $logfile
}
