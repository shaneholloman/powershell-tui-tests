#requires -version 7.3

<#
Create a Terminal.GUI form that displays service information for
a specified computer.
#>
Using namespace Terminal.Gui

#region helper functions
#load external helper function
. $PSScriptRoot\ConvertTo-DataTable

#these functions could be imported from external files

Function resetForm {
    $txtComputer.Text = ''
    $TableView.Table = $null
    $txtUser.Text= ''
    $txtPass.Text = ''
    $radioGroup.SelectedItem = 0
    $txtComputer.SetFocus()
    $StatusBar.Items[0].Title = Get-Date -Format g
    $StatusBar.Items[3].Title = 'Ready'
    [Application]::Refresh()
}
function GetServiceInfo {
    Param(
        $computerName = $txtComputer.Text.ToString().ToUpper()
    )

    $splat = @{
        ClassName   = 'win32_service'
        ErrorAction = 'Stop'
    }

    #check for alternate credentials
    If ((-Not [string]::IsNullOrEmpty($txtUser.text.toString()) -AND (-Not [string]::IsNullOrEmpty($txtPass.text.toString())))) {
        $user = $txtUser.Text.ToString()
        $pass = $txtPass.Text.ToString() | ConvertTo-SecureString -AsPlainText -Force
        $cred = [PSCredential]::New($user, $pass)
        Try {
            $cs = New-CimSession -ComputerName $Computername -Credential $cred -ErrorAction Stop
            $splat['CimSession'] = $cs
        }
        Catch {
            [MessageBox]::ErrorQuery('Error!', "Failed to create a session to $Computername. $($_.Exception.Message)", 0, @('OK'))
            $StatusBar.Items[0].Title = Get-Date -Format g
            $StatusBar.Items[3].Title = 'Ready'
            $txtComputer.SetFocus()
            [Application]::Refresh()
            return
        }
    }
    elseif ((-Not [string]::IsNullOrEmpty($txtUser.text.toString()) -AND ([string]::IsNullOrEmpty($txtPass.text.toString())))) {
        [MessageBox]::Query('Alert!', 'Did you forget to enter a password for your alternate credential?')
    }
    else {
        $splat['Computername'] = $Computername
    }

    Switch ($radioGroup.SelectedItem) {
        1 { $splat['filter'] = "State='Running'" }
        2 { $splat['filter'] = "State='Stopped'" }
    }
    # Query services using Get-CimInstance
    Try {
        $script:services = Get-CimInstance @splat |
        Group-Object -Property Name -AsHashTable -AsString
        $TableView.Table = $script:services.GetEnumerator() |
        ForEach-Object { $_.value |
            Select-Object Name, State, StartMode, DelayedAutoStart, StartName
        } | Sort-Object -Property Name | ConvertTo-DataTable

        $StatusBar.Items[0].Title = "Updated: $(Get-Date -Format g)"
        $StatusBar.Items[3].Title = $script:services[$TableView.Table.Rows[$TableView.SelectedRow].Name].DisplayName
        $TableView.SetFocus()
    }
    Catch {
        [MessageBox]::ErrorQuery('Error!', "Failed to query services on $($txtComputer.text.ToString()). $($_.Exception.Message)", 0, @('OK'))
        $StatusBar.Items[0].Title = Get-Date -Format g
        $StatusBar.Items[3].Title = 'Ready'
    }
    Finally {
        $txtComputer.SetFocus()
        [Application]::Refresh()
    }

}

Function ExportJson {
    if ($script:services) {
        $ReportDate = Get-Date
        $SaveDialog = [SaveDialog]::New()
        [Application]::Run($SaveDialog)
        if ((-Not $SaveDialog.Canceled) -AND ($SaveDialog.FilePath.ToString() -match 'json$')) {

            $StatusBar.Items[3].Title = "Exported to $($saveDialog.FilePath.ToString())"

            $script:services.GetEnumerator() |
            ForEach-Object { $_.value |
                Select-Object Name, State, StartMode, DelayedAutoStart, StartName,
                @{Name = 'Computername'; Expression = { $txtComputer.Text.toString() } },
                @{Name = 'ReportDate'; Expression = { $ReportDate } }
            } | ConvertTo-Json | Out-File -FilePath $SaveDialog.FilePath.ToString()
            [MessageBox]::Query('Export', "Service data exported to $($saveDialog.FilePath.ToString())", 0, @('OK'))`

        }
    } #if service data is found
    Else {
        [MessageBox]::ErrorQuery('Alert!', "No services to export from $($txtComputer.Text.toString())", 0, @('OK'))
    }
    $txtComputer.SetFocus()
}

Function ExportCsv {
    if ($script:services) {
        $ReportDate = Get-Date
        $SaveDialog = [SaveDialog]::New()
        [Application]::Run($SaveDialog)
        if ((-Not $SaveDialog.Canceled) -AND ($SaveDialog.FilePath.ToString() -match 'csv$')) {

            $StatusBar.Items[3].Title = "Exported to $($saveDialog.FilePath.ToString())"

            $script:services.GetEnumerator() |
            ForEach-Object { $_.value |
                Select-Object -Property Name, State, StartMode, DelayedAutoStart, StartName,
                @{Name = 'Computername'; Expression = { $txtComputer.Text.toString() } },
                @{Name = 'ReportDate'; Expression = { $ReportDate } }
            } | Export-Csv -Path $SaveDialog.FilePath.ToString() -NoTypeInformation

            [MessageBox]::Query('Export', "Service data exported to $($saveDialog.FilePath.ToString())", 0, @('OK'))`

        }
    } #if service data is found
    Else {
        [MessageBox]::ErrorQuery('Alert!', "No services to export from $($txtComputer.Text.toString())", 0, @('OK'))
    }
    $txtComputer.SetFocus()
}

Function ExportCliXML {
    if ($script:services) {
        $ReportDate = Get-Date
        $SaveDialog = [SaveDialog]::New()
        [Application]::Run($SaveDialog)
        if ((-Not $SaveDialog.Canceled) -AND ($SaveDialog.FilePath.ToString() -match 'xml$')) {

            $StatusBar.Items[3].Title = "Exported to $($saveDialog.FilePath.ToString())"

            $script:services.GetEnumerator() |
            ForEach-Object { $_.value |
                Select-Object -Property Name, State, StartMode, DelayedAutoStart, StartName,
                @{Name = 'Computername'; Expression = { $txtComputer.Text.toString() } },
                @{Name = 'ReportDate'; Expression = { $ReportDate } }
            } | Export-Clixml -Path $SaveDialog.FilePath.ToString()

            [MessageBox]::Query('Export', "Service data exported to $($saveDialog.FilePath.ToString())", 0, @('OK'))`

        }
    } #if service data is found
    Else {
        [MessageBox]::ErrorQuery('Alert!', "No services to export from $($txtComputer.Text.toString())", 0, @('OK'))
    }
    $txtComputer.SetFocus()
}
#endregion

#region setup

If ($host.name -ne 'ConsoleHost') {
    Write-Warning 'This must be run in a console host.'
    Return
}

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
$scriptVer = '0.8.0'
$TerminalGuiVersion = [System.Reflection.Assembly]::GetAssembly([terminal.gui.application]).GetName().version
$NStackVersion = [System.Reflection.Assembly]::GetAssembly([nstack.ustring]).GetName().version

[Application]::Init()
[Application]::QuitKey = 27
#[Key]::Esc

#endregion

#region create the main window and status bar
$window = [Window]@{
    Title = 'Service Report'
}

$StatusBar = [StatusBar]::New(
    @(
        [StatusItem]::New('Unknown', $(Get-Date -Format g), {}),
        [StatusItem]::New('Unknown', 'ESC to quit', {}),
        [StatusItem]::New('Unknown', "v$scriptVer", {}),
        [StatusItem]::New('Unknown', 'Ready', {})
    )
)

[Application]::Top.add($StatusBar)
#endregion

#region add menus

$MenuItem0 = [MenuItem]::New('_Clear form', '', { resetForm })
$MenuItem1 = [MenuItem]::New('_Quit', '', { [Application]::RequestStop() })
$MenuBarItem0 = [MenuBarItem]::New('_Options', @($MenuItem0, $MenuItem1))

$ExportCsvMenuItem = [MenuItem]::New('as Csv', '', { ExportCsv })
$ExportJsonMenuItem = [MenuItem]::New('as JSON', '', { ExportJson })
$ExportXmlMenuItem = [MenuItem]::New('as XML', '', { ExportCliXML })
#this is what will be on the menu bar
$MenuBarItem1 = [MenuBarItem]::New('_Export', @($ExportCsvMenuItem, $ExportJsonMenuItem, $ExportXmlMenuItem))

$about = @"
$($MyInvocation.MyCommand) v$scriptVer
PSVersion $($PSVersionTable.PSVersion)
Terminal.Gui $TerminalGuiVersion
NStack $NStackVersion
"@
$MenuItem3 = [MenuItem]::New('A_bout', '', { [MessageBox]::Query('About', $About) })
$MenuItem4 = [MenuItem]::New('_Documentation', '', { [MessageBox]::Query('Help', 'To be completed') })
$MenuBarItem2 = [MenuBarItem]::New('_Help', @($MenuItem3,$MenuItem4))

$MenuBar = [MenuBar]::New(@($MenuBarItem0,$MenuBarItem1, $MenuBarItem2))
$Window.Add($MenuBar)
#endregion

#region Add a label and text box for the computer name
$lblComputer = [Label]@{
    X    = 1
    Y    = 2
    Text = 'Computer Name:'
}
$window.Add($lblComputer)

$txtComputer = [TextField]@{
    X        = 10
    Y        = 2
    Width    = 35
    Text     = $env:COMPUTERNAME
    TabIndex = 0
}

#make the computername always upper case
$txtComputer.Add_TextChanged({
        $txtComputer.Text = $txtComputer.Text.ToString().ToUpper()
    })

$window.Add($txtComputer)
#endregion

#region alternate credentials
$CredentialFrame = [FrameView]::New('Credentials')
$CredentialFrame.x = 50
$CredentialFrame.y = 1
$CredentialFrame.width = 40
$CredentialFrame.Height = 5

$lblUser = [Label]@{
    Text = 'Username:'
    X    = 1
}
$CredentialFrame.Add($lblUser)

$txtUser = [TextField]@{
    X        = $lblUser.Frame.Width + 2
    Width    = 25
    TabIndex = 1
}
$CredentialFrame.Add($txtUser)

$lblPass = [Label]@{
    Text = 'Password:'
    X    = 1
    Y    = 2
}
$CredentialFrame.Add($lblPass)
$txtPass = [TextField]@{
    X        = $lblUser.Frame.Width + 2
    Y        = 2
    Width    = 25
    Secret   = $True
    TabIndex = 2
}
$CredentialFrame.Add($txtPass)

$Window.Add($CredentialFrame)
#endregion

#region Add a button to query services
$btnQuery = [Button]@{
    X        = 1
    Y        = 4
    Text     = '_Get Info'
    TabIndex = 4
}
$btnQuery.Add_Clicked({
        Switch ($radioGroup.SelectedItem) {
            0 { $select = 'All' }
            1 { $select = 'Running' }
            2 { $select = 'Stopped' }
        }
        $StatusBar.Items[3].Title = "Getting $select services from $($txtComputer.Text.ToString().toUpper())"
        $StatusBar.SetNeedsDisplay()
        $tableView.RemoveAll()
        $tableView.Clear()
        $tableView.SetNeedsDisplay()
        [Application]::Refresh()
        GetServiceInfo
    })
$window.Add($btnQuery)
#endregion

#region add radio group
$RadioGroup = [RadioGroup]::New(15, 3, @('_All', '_Running', '_Stopped'), 0)
$RadioGroup.DisplayMode = 'Horizontal'
$RadioGroup.TabIndex = 3
#put the radio group next to the Get Info button
$RadioGroup.y = $btnQuery.y
$Window.Add($RadioGroup)
#endregion

#region Add a table view to display the results
# https://gui-cs.github.io/Terminal.Gui/articles/tableview.html
$TableView = [TableView]@{
    X        = 1
    Y        = 6
    Width    = [Dim]::Fill()
    Height   = [Dim]::Fill()
    AutoSize = $True
}
#Keep table headers always in view
$TableView.Style.AlwaysShowHeaders = $True

$TableView.Add_SelectedCellChanged({
        $StatusBar.Items[3].Title = $script:services[$TableView.Table.Rows[$TableView.SelectedRow].Name].DisplayName
    })

$window.Add($TableView)
#endregion

# Run the application
$txtComputer.SetFocus()

[Application]::Top.Add($window)
[Application]::Run()
[Application]::ShutDown()

#end of file