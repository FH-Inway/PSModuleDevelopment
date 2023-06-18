param
(
    [string]
    $DependencyPath = (Resolve-Path "$PSScriptRoot\requiredModules.psd1").Path,

    [string]
    $OutputPath = (Resolve-Path "$PSScriptRoot\..\output").Path
)

$psdependConfig = Import-PowerShellDataFile -Path $DependencyPath
$modPath = Resolve-Path -Path $psdependConfig.PSDependOptions.Target
$modOld = $env:PSModulePath
$pathSeparator = [System.IO.Path]::PathSeparator
$env:PSModulePath = "$modPath$pathSeparator$modOld"
$rsops = Get-DatumRsopCache

foreach ($policy in (Get-ChildItem -Path (Join-Path -Path $OutputPath -ChildPath Policies) -Recurse -Filter *.xml))
{
    $searcher = [adsisearcher]::new()
    $searcher.Filter = "(&(objectClass=groupPolicyContainer)(displayName=$($policy.BaseName)))"
    $policyFound = $searcher.FindOne()

    if (-not $policyFound)
    {
        $null = New-GPO -Name $policy.BaseName -Comment "Auto-updated applocker policy" -Domain $policy.Directory.Name
    }

    $rsop = $rsops | Where-Object { $_.Name -eq $policy.BaseName }
    foreach ($link in $rsop.Links)
    {
        Set-GPLink -Name $rsop.PolicyName -Target $link.OrgUnitDn -LinkEnabled $link.Enabled -Enforced $link.Enforced -Order $link.Order -Domain $policy.Directory.Name -Confirm:0
    }

    $policyFound = $searcher.FindOne()

    Set-AppLockerPolicy -XmlPolicy $policy.FullName -Ldap $policyFound.Path
}

$env:PSModulePath = $modOld
