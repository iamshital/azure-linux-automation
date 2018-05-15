Param(

    #Do not use. Reserved for Jenkins use.   
    $BuildNumber=$env:BUILD_NUMBER,

    #Required
    [string] $TestLocation="westus",
    [string] $RGIdentifier = "TEST",
    [string] $TestPlatform = "Azure",
    [string] $ARMImageName = "Canonical UbuntuServer 16.04-LTS latest",

    #Optinal
    [string] $OsVHD, #... Required if -ARMImageName is not provided.
    [string] $TestCategory = "",
    [string] $TestArea,
    [string] $TestTag = "",
    [string] $TestNames="",
    [switch] $Verbose
)

#Import the Functinos from Library Files.
Get-ChildItem .\TestLibs\*.psm1 | ForEach-Object { Import-Module $_.FullName -Force}
LogVerbose "Set-Variable -Name WorkingDirectory -Value (Get-Location).Path  -Scope Global"

try 
{
    #region Validate Parameters
    LogVerbose "Set-Variable -Name WorkingDirectory -Value (Get-Location).Path  -Scope Global"
    $ParameterErrors = @()
    if ( !$TestPlatform )
    {
        $ParameterErrors += "-TestPlatform <Azure/AzureStack> is required."
    }
    if ( !$ARMImageName -and !$OsVHD )
    {
        $ParameterErrors += "-ARMImageName <'Publisher Offer Sku Version'>/ -OsVHD <'VHD_Name.vhd'> is required"
    }
    if ( !$TestLocation)
    {
        $ParameterErrors += "-TestLocation <Location> is required"
    }
    if ( !$RGIdentifier )
    {
        $ParameterErrors += "-RGIdentifier <PersonalIdentifier> is required. This string will added to Resources created by Automation."
    }
    if ( $ParameterErrors.Count -gt 0)
    {
        $ParameterErrors | ForEach-Object { LogError $_ }
        Throw "Paremeters are not valid."
    }
    else 
    {
        LogMsg "Input parameters are valid"
    }
    #endregion
    
    if ($TestPlatform -eq "Azure")
    {
        #TBD Verify if the current PS session is authenticated.
        #As of now, it expects that PS session is authenticated.
        #We'll change this behaviour in upcoming commits.
    }

    #region Static Global Variables
    Set-Variable -Name WorkingDirectory -Value (Get-Location).Path  -Scope Global
    LogVerbose "Set-Variable -Name WorkingDirectory -Value (Get-Location).Path  -Scope Global"
    Set-Variable -Name shortRandomNumber -Value $(Get-Random -Maximum 99999 -Minimum 11111) -Scope Global
    LogVerbose "Set-Variable -Name shortRandomNumber -Value $(Get-Random -Maximum 99999 -Minimum 11111) -Scope Global"
    Set-Variable -Name shortRandomWord -Value $(-join ((65..90) | Get-Random -Count 4 | ForEach-Object {[char]$_})) -Scope Global
    LogVerbose "Set-Variable -Name shortRandomWord -Value $(-join ((65..90) | Get-Random -Count 4 | ForEach-Object {[char]$_})) -Scope Global"
    #endregion

    #region Runtime Global Variables
    if ( $Verbose )
    {
        $VerboseCommand = "-Verbose"
        Set-Variable -Name VerboseCommand -Value "-Verbose" -Scope Global
    }
    else 
    {
        Set-Variable -Name VerboseCommand -Value "" -Scope Global
    }
    
    #endregion
    
    #region Local Variables
    $TestXMLs = Get-ChildItem -Path "$WorkingDirectory\XML\TestCases\*.xml"
    $SetupTypeXMLs = Get-ChildItem -Path "$WorkingDirectory\XML\VMConfigurations\*.xml"
    $allTests = @()
    $ARMImage = $ARMImageName.Split(" ")
    $xmlFile = "$WorkingDirectory\TestConfiguration.xml"
    if ( $TestCategory -eq "All")
    {
        $TestCategory = ""
    }
    if ( $TestArea -eq "All")
    {
        $TestArea = ""
    }
    if ( $TestNames -eq "All")
    {
        $TestNames = ""
    }
    if ( $TestTag -eq "All")
    {
        $TestTag = $null
    }
    #endregion

    #Validate all XML files in working directory.
    ValiateXMLs -ParentFolder $WorkingDirectory
    
    #region Collect Tests Data
    if ( $TestPlatform -and !$TestCategory -and !$TestArea -and !$TestNames -and !$TestTag)
    {
        foreach ( $file in $TestXMLs.FullName)
        {
            $currentTests = ([xml]( Get-Content -Path $file)).TestCases
            if ( $TestPlatform )
            {
                foreach ( $test in $currentTests.test )
                {
                    if ($TestPlatform -eq $test.Platform ) 
                    {
                        LogMsg "Collected $($test.TestName)"
                        $allTests += $test
                    }
                }
            }
        }         
    }
    elseif ( $TestPlatform -and $TestCategory -and (!$TestArea -or $TestArea -eq "default") -and !$TestNames -and !$TestTag)
    {
        foreach ( $file in $TestXMLs.FullName)
        {
            
            $currentTests = ([xml]( Get-Content -Path $file)).TestCases
            if ( $TestPlatform )
            {
                foreach ( $test in $currentTests.test )
                {
                    if ( ($TestPlatform -eq $test.Platform ) -and $($TestCategory -eq $test.Category) )
                    {
                        LogMsg "Collected $($test.TestName)"
                        $allTests += $test
                    }
                }
            }
        }         
    }
    elseif ( $TestPlatform -and $TestCategory -and ($TestArea -and $TestArea -ne "default") -and !$TestNames -and !$TestTag)
    {
        foreach ( $file in $TestXMLs.FullName)
        {
            
            $currentTests = ([xml]( Get-Content -Path $file)).TestCases
            if ( $TestPlatform )
            {
                foreach ( $test in $currentTests.test )
                {
                    if ( ($TestPlatform -eq $test.Platform ) -and $($TestCategory -eq $test.Category) -and $($TestArea -eq $test.Area) )
                    {
                        LogMsg "Collected $($test.TestName)"
                        $allTests += $test
                    }
                }
            }
        }         
    }
    elseif ( $TestPlatform -and $TestCategory  -and $TestNames -and !$TestTag)
    {
        foreach ( $file in $TestXMLs.FullName)
        {
            
            $currentTests = ([xml]( Get-Content -Path $file)).TestCases
            if ( $TestPlatform )
            {
                foreach ( $test in $currentTests.test )
                {
                    if ( ($TestPlatform -eq $test.Platform ) -and $($TestCategory -eq $test.Category) -and $($TestArea -eq $test.Area) -and ($TestNames.Split(",").Contains($test.TestName) ) )
                    {
                        LogMsg "Collected $($test.TestName)"
                        $allTests += $test
                    }
                }
            }
        }         
    }
    elseif ( $TestPlatform -and !$TestCategory -and !$TestArea -and $TestNames -and !$TestTag)
    {
        foreach ( $file in $TestXMLs.FullName)
        {
            
            $currentTests = ([xml]( Get-Content -Path $file)).TestCases
            if ( $TestPlatform )
            {
                foreach ( $test in $currentTests.test )
                {
                    if ( ($TestPlatform -eq $test.Platform ) -and ($TestNames.Split(",").Contains($test.TestName) ) )
                    {
                        LogMsg "Collected $($test.TestName)"
                        $allTests += $test
                    }
                }
            }
        }         
    }    
    elseif ( $TestPlatform -and !$TestCategory -and !$TestArea -and !$TestNames -and $TestTag)
    {
        foreach ( $file in $TestXMLs.FullName)
        {
            
            $currentTests = ([xml]( Get-Content -Path $file)).TestCases
            if ( $TestPlatform )
            {
                foreach ( $test in $currentTests.test )
                {
                    if ( ($TestPlatform -eq $test.Platform ) -and ( $test.Tags.Split(",").Contains($TestTag) ) )
                    {
                        LogMsg "Collected $($test.TestName)"
                        $allTests += $test
                    }
                }
            }
        }         
    }
    else 
    {
        Throw "Invalid Test Selection"
    }
    #endregion 

    #region Create Test XML
    $SetupTypes = $allTests.SetupType | Sort-Object | Get-Unique

    $tab = @()
    for ( $i = 0; $i -lt 30; $i++)
    {
        $currentTab = ""
        for ( $j = 0; $j -lt $i; $j++)
        {
            $currentTab +=  "`t"
        }
        $tab += $currentTab
    }


    $GlobalConfiguration = [xml](Get-content .\XML\GlobalConfigurations.xml)
    <##########################################################################
    We're following the Indentation of the XML file to make XML creation easier.
    ##########################################################################>
    $xmlContent =  ("$($tab[0])" + '<?xml version="1.0" encoding="utf-8"?>')
    $xmlContent += ("$($tab[0])" + "<config>`n") 
    $xmlContent += ("$($tab[0])" + "<CurrentTestPlatform>$TestPlatform</CurrentTestPlatform>`n") 
        $xmlContent += ("$($tab[1])" + "<Azure>`n") 

            #region Add Subscription Details
            $xmlContent += ("$($tab[2])" + "<General>`n")
            
            foreach ( $line in $GlobalConfiguration.Global.Azure.Subscription.InnerXml.Replace("><",">`n<").Split("`n"))
            {
                $xmlContent += ("$($tab[3])" + "$line`n")
            }
            $xmlContent += ("$($tab[2])" + "<Location>$TestLocation</Location>`n") 
            $xmlContent += ("$($tab[2])" + "</General>`n")
            #endregion

            #region Database details
            $xmlContent += ("$($tab[2])" + "<database>`n")
                foreach ( $line in $GlobalConfiguration.Global.Azure.ResultsDatabase.InnerXml.Replace("><",">`n<").Split("`n"))
                {
                    $xmlContent += ("$($tab[3])" + "$line`n")
                }
            $xmlContent += ("$($tab[2])" + "</database>`n")
            #endregion

            #region Deployment details
            $xmlContent += ("$($tab[2])" + "<Deployment>`n")
                $xmlContent += ("$($tab[3])" + "<Data>`n")
                    $xmlContent += ("$($tab[4])" + "<Distro>`n")
                        $xmlContent += ("$($tab[5])" + "<Name>$RGIdentifier</Name>`n")
                        $xmlContent += ("$($tab[5])" + "<ARMImage>`n")
                            $xmlContent += ("$($tab[6])" + "<Publisher>" + "$($ARMImage[0])" + "</Publisher>`n")
                            $xmlContent += ("$($tab[6])" + "<Offer>" + "$($ARMImage[1])" + "</Offer>`n")
                            $xmlContent += ("$($tab[6])" + "<Sku>" + "$($ARMImage[2])" + "</Sku>`n")
                            $xmlContent += ("$($tab[6])" + "<Version>" + "$($ARMImage[3])" + "</Version>`n")
                        $xmlContent += ("$($tab[5])" + "</ARMImage>`n")
                        $xmlContent += ("$($tab[5])" + "<OsVHD>" + "$OsVHD" + "</OsVHD>`n")
                    $xmlContent += ("$($tab[4])" + "</Distro>`n")
                    $xmlContent += ("$($tab[4])" + "<UserName>" + "$($GlobalConfiguration.Global.Azure.TestCredentials.LinuxUsername)" + "</UserName>`n")
                    $xmlContent += ("$($tab[4])" + "<Password>" + "$($GlobalConfiguration.Global.Azure.TestCredentials.LinuxPassword)" + "</Password>`n")
                $xmlContent += ("$($tab[3])" + "</Data>`n")
                
                foreach ( $file in $SetupTypeXMLs.FullName)
                {
                    foreach ( $SetupType in $SetupTypes )
                    {                    
                        $CurrentSetupType = ([xml]( Get-Content -Path $file)).TestSetup
                        if ( $CurrentSetupType.$SetupType -ne $null)
                        {
                            $SetupTypeElement = $CurrentSetupType.$SetupType
                            $xmlContent += ("$($tab[3])" + "<$SetupType>`n")
                                #$xmlContent += ("$($tab[4])" + "$($SetupTypeElement.InnerXml)`n")
                                foreach ( $line in $SetupTypeElement.InnerXml.Replace("><",">`n<").Split("`n"))
                                {
                                    $xmlContent += ("$($tab[4])" + "$line`n")
                                }
                                                
                            $xmlContent += ("$($tab[3])" + "</$SetupType>`n")
                        }
                    }                    
                }
            $xmlContent += ("$($tab[2])" + "</Deployment>`n")
            #endregion        
        $xmlContent += ("$($tab[1])" + "</Azure>`n")
        

        #region TestDefinition
        $xmlContent += ("$($tab[1])" + "<testsDefinition>`n")
        foreach ( $currentTest in $allTests)
        {
            $xmlContent += ("$($tab[2])" + "<test>`n")
            foreach ( $line in $currentTest.InnerXml.Replace("><",">`n<").Split("`n"))
            {
                $xmlContent += ("$($tab[3])" + "$line`n")
            } 
            $xmlContent += ("$($tab[2])" + "</test>`n")
        }
        $xmlContent += ("$($tab[1])" + "</testsDefinition>`n")
        #endregion

        #region TestCycle
        $xmlContent += ("$($tab[1])" + "<testCycles>`n")
            $xmlContent += ("$($tab[2])" + "<Cycle>`n")
                $xmlContent += ("$($tab[3])" + "<cycleName>TC-$shortRandomNumber</cycleName>`n")
                foreach ( $currentTest in $allTests)
                {
                    $line = $currentTest.TestName
                    $xmlContent += ("$($tab[3])" + "<test>`n")
                        $xmlContent += ("$($tab[4])" + "<Name>$line</Name>`n")
                    $xmlContent += ("$($tab[3])" + "</test>`n")
                }
            $xmlContent += ("$($tab[2])" + "</Cycle>`n")
        $xmlContent += ("$($tab[1])" + "</testCycles>`n")
        #endregion
    $xmlContent += ("$($tab[0])" + "</config>`n") 
    Set-Content -Value $xmlContent -Path $xmlFile -Force
    try 
    {
        $xmlConfig = [xml](Get-Content $xmlFile)
        $xmlConfig.Save("$xmlFile")
        LogMsg "Auto created $xmlFile validated successfully."   
    }
    catch 
    {
        Throw "Auto created $xmlFile is not valid."    
    }
    
    #endregion

    #region Download necessary tools.
    mkdir -Path .\tools -ErrorAction SilentlyContinue | Out-Null
    Import-Module BitsTransfer  
    if (!( Test-Path -Path .\tools\7za.exe ))
    {
        Write-Host "Downloading 7za.exe"
        $out = Start-BitsTransfer -Source "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/7za.exe" | Out-Null
    }
    if (!( Test-Path -Path .\tools\dos2unix.exe ))
    {
        Write-Host "Downloading dos2unix.exe"
        $out = Start-BitsTransfer -Source "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/dos2unix.exe" | Out-Null
    }
    if (!( Test-Path -Path .\tools\plink.exe ))
    {
        Write-Host "Downloading plink.exe"
        $out = Start-BitsTransfer -Source "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/plink.exe" | Out-Null
    }
    if (!( Test-Path -Path .\tools\pscp.exe ))
    {
        Write-Host "Downloading pscp.exe"
        $out = Start-BitsTransfer -Source "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/pscp.exe"  | Out-Null
    }
    Move-Item -Path "*.exe" -Destination .\tools -ErrorAction SilentlyContinue -Force
    #endregion

    LogMsg ".\AutomationManager.ps1 -xmlConfigFile '$xmlFile' -cycleName TC-$shortRandomNumber -RGIdentifier $RGIdentifier -runtests -UseAzureResourceManager"
    .\AutomationManager.ps1 -xmlConfigFile "$xmlFile" -cycleName "TC-$shortRandomNumber" -RGIdentifier $RGIdentifier -runtests -UseAzureResourceManager -
    
    #TBD Analyse the test result
    #TBD Archive the logs
    #TBD Email the reports

}
catch 
{
    $line = $_.InvocationInfo.ScriptLineNumber
    $script_name = ($_.InvocationInfo.ScriptName).Replace($PWD,".")
    $ErrorMessage =  $_.Exception.Message
    LogMsg "EXCEPTION : $ErrorMessage"
    LogMsg "Source : Line $line in script $script_name."
    $ExitCode = 1
}
finally 
{
    exit $ExitCode    
}