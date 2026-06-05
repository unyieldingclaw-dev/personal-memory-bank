param([string]$Description = 'Select a folder')
Add-Type -AssemblyName System.Windows.Forms
$owner = New-Object System.Windows.Forms.Form
$owner.TopMost = $true
$f = New-Object System.Windows.Forms.FolderBrowserDialog
$f.Description = $Description
$f.ShowNewFolderButton = $true
if ($f.ShowDialog($owner) -eq 'OK') { $f.SelectedPath }
