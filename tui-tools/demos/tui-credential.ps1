# requires -version 7.3

Param([string]$Username)

$dlls = "$PSScriptRoot\assemblies\NStack.dll", "$PSScriptRoot\assemblies\Terminal.Gui.dll"
ForEach ($item in $dlls) {
    Try {
        Add-Type -Path $item -ErrorAction Stop
    }
    Catch [System.IO.FileLoadException] {
        #write-host "already loaded" -ForegroundColor yellow
    }
    Catch {
        Throw $_
    }
}

[Terminal.Gui.Application]::Init()
[Terminal.Gui.Application]::QuitKey = 27
$Script:New = $False

$win = [Terminal.Gui.Window] @{
    Title  = 'Get-TuiCredential'
    Width  = 45
    Height = 9
    X      = [Terminal.Gui.Pos]::Center()
    Y      = [Terminal.Gui.Pos]::Center()
}

$lblUsername = [Terminal.Gui.Label] @{
    Text = 'UserName'
    X    = 1
    Y    = 1
}
$win.Add($lblUsername)

$txtUserName = [Terminal.Gui.TextField]@{
    Width    = 30
    X        = 10
    Y        = 1
    TabIndex = 0
    Text     = $Username
}
$win.Add($txtUserName)

$lblPass = [Terminal.Gui.Label] @{
    Text = 'Password'
    X    = 1
    Y    = 3
}
$win.Add($lblPass)

$txtPass = [Terminal.Gui.TextField]@{
    Width    = 30
    X        = 10
    Y        = 3
    TabIndex = 1
    Secret   = $True
}
$win.Add($txtPass)

$btnNew = [Terminal.Gui.Button]@{
    Text     = '_New'
    X        = 7
    Y        = 5
    TabIndex = 2
}

$btnNew.add_Clicked({
        $script:New = $True
        [Terminal.Gui.Application]::RequestStop()
    })
$win.Add($btnNew)

$btnCancel = [Terminal.Gui.Button]@{
    Text     = '_Cancel'
    X        = $btnNew.X + 9
    Y        = 5
    TabIndex = 3
}

$btnCancel.add_Clicked({
        $Script:New = $False
        [Terminal.Gui.Application]::RequestStop()
    })
$win.Add($btnCancel)

$btnShow = [Terminal.Gui.Button]@{
    Text     = '_Show'
    X        = $btnCancel.X + 12
    Y        = 5
    TabIndex = 4
}

$btnShow.add_Clicked({
        if ($txtPass.Secret) {
            $txtPass.Secret = $False
            $btnShow.Text = '_Hide'
        }
        else {
            $txtPass.Secret = $True
            $btnShow.Text = '_Show'
        }
    })
$win.Add($btnShow)

[Terminal.Gui.Application]::Top.Add($win)
[Terminal.Gui.Application]::Run()
[Terminal.Gui.Application]::ShutDown()

If ($Script:New) {
    $SecureString = ConvertTo-SecureString -String $txtPass.Text.ToString() -AsPlainText -Force
    Try {
        [PSCredential]::New($txtUserName.Text.ToString(), $SecureString)
    }
    Catch {
        Throw 'Failed to create a credential. Did you specify a username AND password?'
    }
}

