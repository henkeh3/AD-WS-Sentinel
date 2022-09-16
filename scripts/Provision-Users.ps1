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

try
{
    # Create User OU 
    New-ADOrganizationalUnit -Name "Corp"
    New-ADOrganizationalUnit -Name "Users" -Path "OU=Corp,DC=labdomain,DC=com"


    # Get names
    $Names = Invoke-RestMethod -Uri "https://api.namnapi.se/v2/names.json?limit=500" -Method Get
}
catch
{
    Write-output "$_.exception.message"
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
    }
    catch
    {
        Write-output "$_.exception.message"
    }

}

