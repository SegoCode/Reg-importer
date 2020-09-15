# FUNCTIONS SECTION

function DrawMenu {
    param ($menuItems, $menuPosition, $Multiselect, $selection)
    Clear-Host
    $l = $menuItems.length

    Write-Host @"

    /////////////////////////////////////////////////////////////////////////////////
    //                                                                             //
    //                          R E G    I M P O R T E R                           //
    //                                                                             //
    //                                                                             //
    //                                                                             //
    //                         [ ]   - Reg value not apply                         //
    //                         [X]   - Reg value apply                             //
    //                         [NF]  - Reg value not found                         //
    //                                                                             //
    //                                                                             //
    /////////////////////////////////////////////////////////////////////////////////
    
"@

    for ($i = 0; $i -le $l; $i++) {
        if ($menuItems[$i] -ne $null) {
            $item = $menuItems[$i]
            if ($i -eq $menuPosition) {
                Write-Host "  > $($item)" -ForegroundColor Green
            }
            else {
                Write-Host "    $($item)"
            }
        }
    }
}

function Toggle-Selection {
    param ($pos, [array]$selection)
    if ($selection -contains $pos) { 
        $result = $selection | where { $_ -ne $pos }
    }else {
        $selection += $pos
        $result = $selection
    }
    $result
}

function Menu {
    param ([array]$menuItems, [switch]$ReturnIndex = $false, [switch]$Multiselect)
    $vkeycode = 0
    $pos = 0
    $selection = @()
    $cur_pos = [System.Console]::CursorTop
    [console]::CursorVisible = $false #prevents cursor flickering
    if ($menuItems.Length -gt 0) {
        DrawMenu $menuItems $pos $Multiselect $selection
        While ($vkeycode -ne 13 -and $vkeycode -ne 27) {
            $press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            if ($vkeycode -eq 38 -or $press.Character -eq 'k') { $pos-- }
            if ($vkeycode -eq 40 -or $press.Character -eq 'j') { $pos++ }
            if ($press.Character -eq ' ') { $selection = Toggle-Selection $pos $selection }
            if ($pos -lt 0) { $pos = 0 }
            if ($vkeycode -eq 27) { $pos = $null }
            if ($pos -ge $menuItems.length) { $pos = $menuItems.length - 1 }
            if ($vkeycode -ne 27) {
                [System.Console]::SetCursorPosition(0, $cur_pos)
                DrawMenu $menuItems $pos $Multiselect $selection
            }
        }
    }else {
        $pos = $null
    }
    [console]::CursorVisible = $true

    if ($ReturnIndex -eq $false -and $pos -ne $null) {
        if ($Multiselect) {
            return $menuItems[$selection]
        }
        else {
            return $menuItems[$pos]
        }
    }else {
        if ($Multiselect) {
            return $selection
        }else {
            return $pos
        }
    }
}


function Create-Menu-json {
    param ($jsonConfig)
    $selection = @('[?]  - Apply all')
    $jsonConfig | Select-Object -Property description, path, name, type, value | ForEach-Object {
        if ((Get-Item $_.path -EA Ignore).Property -contains $_.name) {
            $keyData = Get-ItemProperty -Path $_.path -Name $_.name
            if ($keyData.($_.name) -eq $_.value) {
                $selection += "[X]  - " + $_.description 
            }else {
                $selection += "[ ]  - " + $_.description 
            }
        } else {
            $selection += "[NF] - " + $_.description 
        }
    }

    return menu -ReturnIndex $selection
}

# END FUNCTIONS SECTION

# INIT

$host.ui.RawUI.WindowTitle = 'github.com/SegoCode'
[console]::WindowWidth = 90;
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$jsonLocation = $scriptDir + "\profile.json" 
$bakFolder = $scriptDir + "\reg_bak"

if (!(Test-Path $jsonLocation -PathType Leaf)) {
    Clear-Host
    Write-Host " "
    Write-Host "    [!]  - Not found profile.json in the root directory "
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Exit
}

if (!(test-path $bakFolder)) {
    New-Item -ItemType Directory -Force -Path $bakFolder
}


$jsonConfig = Get-Content -Raw -Path $jsonLocation | ConvertFrom-Json

# LOOP MENU

While ($TRUE) {
    $selectionValue = Create-Menu-json $jsonConfig

    if ( $selectionValue -eq 0) {
        Write-Host " "
        Write-Host "    [?]  - For safety reasons, NF paths dont be created continue? [Y/N] > " �NoNewline
        $option = Read-Host
        if ($option -eq 'Y') {
            $jsonConfig | Select-Object -Property description, path, name, type, value | ForEach-Object {
                Set-ItemProperty -Path $_.path -Name $_.name -Type $_.type -Value $_.value
                Write-Host $_.path $_.name $_.type $_.value
            }
        }
   
    } else {

        $keyData = $jsonConfig.GetValue($selectionValue - 1)

        if (Test-Path $keyData.path) {
            if (((Get-ItemProperty -Path $keyData.path).($keyData.name)) -ne $keyData.value) {
                $backLocation = $bakFolder + "\" + $keyData.description + "_bak.reg" 
                reg export $keyData.path.Replace(':', '') $backLocation /y
                Set-ItemProperty -Path $keyData.path -Name $keyData.name -Type $keyData.type -Value $keyData.value
            }
        } else {
            Write-Host " "
            Write-Host "    [?]  - Not found path in registry, create the path and key? [Y/N] > " �NoNewline
            $option = Read-Host
            if ($option -eq 'Y') {
                New-Item -Path $keyData.path -Force
                New-ItemProperty -Path $keyData.path -Name $keyData.name -Value $keyData.value
            }

        }
    }
}

# EOF