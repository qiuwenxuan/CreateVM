# 检查当前 PowerShell 执行策略，并设置为 RemoteSigned（如果不是）
$currentPolicy = Get-ExecutionPolicy -ErrorAction SilentlyContinue
if ($currentPolicy -ne "RemoteSigned") {
    Set-ExecutionPolicy RemoteSigned -Scope Process -Force
}

# 检查是否以管理员身份运行
function Test-Admin {
    $isAdmin = $false
    try {
        $test = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $test.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        $isAdmin = $false
    }
    return $isAdmin
}

if (-not (Test-Admin)) {
    Write-Host "当前未以管理员身份运行。请以管理员身份重新运行此脚本。"
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "创建虚拟机"
$form.Size = New-Object System.Drawing.Size(500,250)

# 创建标签和文本框
$labels = @("虚拟机名称", "vhdx镜像路径", "虚拟机存储路径", "网络名称")
$y = 20
$textBoxes = @{}

foreach ($label in $labels) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(10, $y)
    $form.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Name = $label -replace " ", ""
    $txt.Width = 250
    $txt.Location = New-Object System.Drawing.Point(120, $y)

    # 为“vhdx镜像路径”和“虚拟机存储路径”添加文件或文件夹选择按钮
    if ($label -eq "vhdx镜像路径") {
        $btnSelect = New-Object System.Windows.Forms.Button
        $btnSelect.Text = "选择文件"
        $btnSelect.Location = New-Object System.Drawing.Point(380, $y)
        $btnSelect.Add_Click({
            $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
            $fileBrowser.Filter = "VHDX files (*.vhdx)|*.vhdx|All files (*.*)|*.*"
            if ($fileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $textBoxes["vhdx镜像路径"].Text = $fileBrowser.FileName
            }
        })
        $form.Controls.Add($btnSelect)
    } elseif ($label -eq "虚拟机存储路径") {
        $btnSelect = New-Object System.Windows.Forms.Button
        $btnSelect.Text = "选择文件夹"
        $btnSelect.Location = New-Object System.Drawing.Point(380, $y)
        $btnSelect.Add_Click({
            $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $textBoxes["虚拟机存储路径"].Text = $folderBrowser.SelectedPath
            }
        })
        $form.Controls.Add($btnSelect)
    }

    $form.Controls.Add($txt)
    $textBoxes[$label] = $txt
    $y += 40
}

# 创建提交按钮
$btnSubmit = New-Object System.Windows.Forms.Button
$btnSubmit.Text = "提交"
$btnSubmit.Location = New-Object System.Drawing.Point(150, $y)
$btnSubmit.Add_Click({
    $vmName = $textBoxes["虚拟机名称"].Text
    $vhdxPath = $textBoxes["vhdx镜像路径"].Text
    $vmPath = $textBoxes["虚拟机存储路径"].Text
    $vSwitch = $textBoxes["网络名称"].Text

    # 验证字段是否为空
    if ([string]::IsNullOrEmpty($vmName) -or [string]::IsNullOrEmpty($vhdxPath) -or [string]::IsNullOrEmpty($vmPath) -or [string]::IsNullOrEmpty($vSwitch)) {
        [System.Windows.Forms.MessageBox]::Show("所有字段均为必填项！", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # 创建虚拟机，增加启动内存到 1GB
    New-VM -Name $vmName -MemoryStartupBytes 1GB -BootDevice VHD -Generation 2 -VHDPath $vhdxPath -Path $vmPath

    # 设置动态内存
    Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $true -MinimumBytes 1GB -MaximumBytes 4GB -Buffer 20

    # 添加虚拟交换机
    Add-VMNetworkAdapter -VMName $vmName -SwitchName $vSwitch

    # 设置CPU数量
    Set-VMProcessor -VMName $vmName -Count 2

    # 启动虚拟机
    Start-VM -Name $vmName

    # 显示成功信息
    [System.Windows.Forms.MessageBox]::Show("虚拟机创建成功", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})
$form.Controls.Add($btnSubmit)

# 显示窗口
$form.Topmost = $true
$form.ShowDialog()
