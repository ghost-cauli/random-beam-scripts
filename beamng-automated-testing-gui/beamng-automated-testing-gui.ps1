# BeamNG Vehicle Test Automation Script: GUI Version - Windows 11 Mica Style
# Clean, responsive design with modern Mica backdrop effect

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Add Windows 11 Mica API definitions
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class DwmApi {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int dwAttribute, ref int pvAttribute, int cbAttribute);
    
    [DllImport("uxtheme.dll", EntryPoint = "#95")]
    public static extern uint GetImmersiveColorFromColorSetEx(uint dwImmersiveColorSet, uint dwImmersiveColorType, bool bIgnoreHighContrast, uint dwHighContrastCacheMode);
    
    [DllImport("uxtheme.dll", EntryPoint = "#96")]
    public static extern uint GetImmersiveColorTypeFromName(IntPtr pName);
    
    [DllImport("uxtheme.dll", EntryPoint = "#98")]
    public static extern int GetImmersiveUserColorSetPreference(bool bForceCheckRegistry, bool bSkipCheckOnFail);
    
    // DWM Window Attributes
    public const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    public const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    public const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    
    // Backdrop types
    public const int DWMSBT_AUTO = 0;
    public const int DWMSBT_NONE = 1;
    public const int DWMSBT_MAINWINDOW = 2;    // Mica
    public const int DWMSBT_TRANSIENTWINDOW = 3; // Acrylic  
    public const int DWMSBT_TABBEDWINDOW = 4;  // Mica Alt
    
    // Corner preferences
    public const int DWMWCP_DEFAULT = 0;
    public const int DWMWCP_DONOTROUND = 1;
    public const int DWMWCP_ROUND = 2;
    public const int DWMWCP_ROUNDSMALL = 3;
}
"@

# Global variables
$global:userFolderPath = ""
$global:selectedUserFolderVersion = ""
$global:validVehicles = @()
$global:createFilesForAll = ""
$global:testingCancelled = $false
$global:currentBeamNGProcess = $null
$global:useLowestSettings = $false
$global:settingsBackupPath = ""
$global:allBeamNGProcesses = @()
$script:processingBulkAction = $false  # Prevent recursion in ItemCheck
$global:configPlaceholders = @{
    Type = "Unspecified"
    Description = "Unspecified"
    Value = 0
    Population = 0
}
$global:skipTestedFiles = $false

# Windows 11 dark theme color scheme - properly researched
$win10Colors = @{
    # Dark theme backgrounds
    Background = [System.Drawing.Color]::FromArgb(32, 32, 32)         # Main dark background
    DarkBackground = [System.Drawing.Color]::FromArgb(32, 32, 32)     # Same as background
    CardBackground = [System.Drawing.Color]::FromArgb(44, 44, 44)     # Elevated surfaces
    InputBackground = [System.Drawing.Color]::FromArgb(44, 44, 44)    # Input fields
    
    # Windows 11 accent blue
    AccentBlue = [System.Drawing.Color]::FromArgb(0, 120, 215)
    AccentBlueHover = [System.Drawing.Color]::FromArgb(16, 132, 208)   # Lighter blue for hover
    AccentBluePressed = [System.Drawing.Color]::FromArgb(0, 95, 184)  # Darker blue for press
    
    # Text colors for dark theme
    TextPrimary = [System.Drawing.Color]::FromArgb(255, 255, 255)     # White text
    TextSecondary = [System.Drawing.Color]::FromArgb(204, 204, 204)   # Light gray text
    TextTertiary = [System.Drawing.Color]::FromArgb(153, 153, 153)    # Medium gray text
    
    # Border and UI colors
    BorderColor = [System.Drawing.Color]::FromArgb(60, 60, 60)        # Dark borders
    BorderColorLight = [System.Drawing.Color]::FromArgb(76, 76, 76)   # Lighter borders
    
    # Status colors
    Success = [System.Drawing.Color]::FromArgb(16, 124, 16)
    Warning = [System.Drawing.Color]::FromArgb(255, 140, 0)
    Error = [System.Drawing.Color]::FromArgb(196, 43, 28)
    
    # Windows 11 button colors - subtle backgrounds
    ButtonBackground = [System.Drawing.Color]::FromArgb(68, 68, 68)        # Subtle gray background
    ButtonBackgroundHover = [System.Drawing.Color]::FromArgb(85, 85, 85)   # Lighter on hover
    ButtonBackgroundPressed = [System.Drawing.Color]::FromArgb(51, 51, 51) # Darker when pressed
    
    # Checkbox/radio colors
    CheckboxBackground = [System.Drawing.Color]::FromArgb(68, 68, 68)
    CheckboxBorder = [System.Drawing.Color]::FromArgb(109, 109, 109)
    CheckboxChecked = [System.Drawing.Color]::FromArgb(0, 120, 215)        # Accent blue when checked
}

# Create main responsive form with Windows 11 styling
$form = New-Object System.Windows.Forms.Form
$form.Text = "BeamNG Vehicle Test Automation"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(700, 500)
$form.BackColor = $win10Colors.Background  # Keep solid background initially
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Function to apply Windows 11 Mica effect
function ApplyMicaEffect($window) {
    try {
        $hwnd = $window.Handle
        
        # Always apply dark mode for consistent theming
        $darkModeValue = 1
        [DwmApi]::DwmSetWindowAttribute($hwnd, [DwmApi]::DWMWA_USE_IMMERSIVE_DARK_MODE, [ref]$darkModeValue, 4) | Out-Null
        Write-Host "Dark mode applied" -ForegroundColor Green
        
        # Check if we're on Windows 11 Build 22621+ by trying to apply Mica
        $micaValue = [DwmApi]::DWMSBT_MAINWINDOW  # Use Mica effect
        $result = [DwmApi]::DwmSetWindowAttribute($hwnd, [DwmApi]::DWMWA_SYSTEMBACKDROP_TYPE, [ref]$micaValue, 4)
        
        if ($result -eq 0) {
            Write-Host "Windows 11 Mica effect applied successfully" -ForegroundColor Green
            
            # Enable rounded corners for modern look
            $cornerValue = [DwmApi]::DWMWCP_ROUND
            [DwmApi]::DwmSetWindowAttribute($hwnd, [DwmApi]::DWMWA_WINDOW_CORNER_PREFERENCE, [ref]$cornerValue, 4) | Out-Null
            
            # For proper Mica effect, we need to extend the frame into client area
            # and make specific areas transparent black
            try {
                Add-Type @"
using System;
using System.Runtime.InteropServices;

public class DwmExtend {
    [DllImport("dwmapi.dll")]
    public static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref MARGINS pMarInset);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct MARGINS {
        public int cxLeftWidth;
        public int cxRightWidth; 
        public int cyTopHeight;
        public int cyBottomHeight;
    }
}
"@
                # Extend frame into entire client area for full Mica effect
                $margins = New-Object DwmExtend+MARGINS
                $margins.cxLeftWidth = -1
                $margins.cxRightWidth = -1
                $margins.cyTopHeight = -1
                $margins.cyBottomHeight = -1
                
                $extendResult = [DwmExtend]::DwmExtendFrameIntoClientArea($hwnd, [ref]$margins)
                if ($extendResult -eq 0) {
                    Write-Host "Frame extended for full Mica effect" -ForegroundColor Green
                    # Set form to black for proper Mica rendering
                    $window.BackColor = [System.Drawing.Color]::Black
                    return $true
                }
            } catch {
                Write-Host "Could not extend frame, using titlebar-only Mica" -ForegroundColor Yellow
            }
            
            return $true
        } else {
            Write-Host "Mica effect not available (requires Windows 11 22H2+)" -ForegroundColor Yellow
            # Fallback to dark solid background for older Windows
            $window.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
            return $false
        }
    } catch {
        Write-Host "Mica effect not supported on this system, using dark appearance" -ForegroundColor Yellow
        # Fallback to dark solid background
        $window.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
        return $false
    }
}

# Check if BeamNG executable exists
if (-not (Test-Path "Bin64\BeamNG.drive.x64.exe")) {
    [System.Windows.Forms.MessageBox]::Show("BeamNG.drive.x64.exe not found in Bin64 directory.`n`nPlease run this script from the BeamNG.drive installation directory.", "BeamNG Not Found", "OK", "Error")
    exit
}

# Main content panel - responsive, 90% width, centered, Mica-compatible
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Anchor = "Top,Bottom,Left,Right"
$mainPanel.BackColor = $win10Colors.Background  # Will be made transparent if Mica is available

# Bottom button panel - sticks to bottom right, semi-transparent for Mica
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Height = 60
$buttonPanel.Anchor = "Bottom,Left,Right"
$buttonPanel.BackColor = $win10Colors.Background  # Will be updated for Mica

# Helper function to calculate responsive dimensions
function UpdateLayout {
    $margin = [Math]::Floor($form.ClientSize.Width * 0.05)  # 5% margin each side = 90% content width
    $contentWidth = $form.ClientSize.Width - (2 * $margin)
    
    $mainPanel.Location = New-Object System.Drawing.Point($margin, 20)
    $mainPanel.Size = New-Object System.Drawing.Size($contentWidth, ($form.ClientSize.Height - 80))
    
    $buttonPanel.Location = New-Object System.Drawing.Point(0, ($form.ClientSize.Height - 60))
    $buttonPanel.Size = New-Object System.Drawing.Size($form.ClientSize.Width, 60)
}

# Handle form resize
$form.Add_Resize({
    UpdateLayout
})

# Handle form load
$form.Add_Load({
    UpdateLayout
    AutoDetectUserFolder
    
    # Apply Mica effect after form is fully loaded
    $form.BeginInvoke([System.Action]{
        $micaApplied = ApplyMicaEffect $form
        if ($micaApplied) {
            # Update panels to work with black background for Mica
            $mainPanel.BackColor = [System.Drawing.Color]::Transparent
            $buttonPanel.BackColor = [System.Drawing.Color]::Transparent  # Make transparent for Mica
            
            # Update screen backgrounds
            $screen1.BackColor = [System.Drawing.Color]::Transparent
            $screen2.BackColor = [System.Drawing.Color]::Transparent  
            $screen3.BackColor = [System.Drawing.Color]::Transparent
            $screen4.BackColor = [System.Drawing.Color]::Transparent
        } else {
            # Dark theme fallback for older Windows
            $mainPanel.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
            $buttonPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
            
            $screen1.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
            $screen2.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
            $screen3.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
            $screen4.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
        }
    })
})

# Handle form closing
$form.Add_FormClosing({
    KillAllBeamNGProcesses
    RestoreOriginalSettings
    [System.Environment]::Exit(0)
})

# Helper function to create proper Windows 11 style buttons
function CreateButton($text, $width = 80, $height = 32) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    $button.Size = New-Object System.Drawing.Size($width, $height)
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $win10Colors.BorderColor
    $button.BackColor = $win10Colors.ButtonBackground
    $button.ForeColor = $win10Colors.TextPrimary
    $button.Cursor = "Hand"
    $button.UseVisualStyleBackColor = $false  # Important for custom colors
    
    # Windows 11 hover effects - proper colors that don't conflict
    $button.Add_MouseEnter({
        $this.BackColor = $win10Colors.ButtonBackgroundHover
        $this.FlatAppearance.BorderColor = $win10Colors.BorderColorLight
    })
    
    $button.Add_MouseLeave({
        $this.BackColor = $win10Colors.ButtonBackground
        $this.FlatAppearance.BorderColor = $win10Colors.BorderColor
    })
    
    $button.Add_MouseDown({
        $this.BackColor = $win10Colors.ButtonBackgroundPressed
    })
    
    $button.Add_MouseUp({
        $this.BackColor = $win10Colors.ButtonBackgroundHover
    })
    
    return $button
}

# Navigation buttons - positioned in bottom right
$btnBack = CreateButton "Back"
$btnNext = CreateButton "Next"

function PositionBottomButtons {
    $rightMargin = 20
    $buttonSpacing = 10
    
    $btnNext.Location = New-Object System.Drawing.Point(($buttonPanel.Width - $rightMargin - $btnNext.Width), 15)
    $btnBack.Location = New-Object System.Drawing.Point(($btnNext.Left - $buttonSpacing - $btnBack.Width), 15)
}

$buttonPanel.Add_Resize({
    PositionBottomButtons
})

$buttonPanel.Controls.AddRange(@($btnBack, $btnNext))

# ==================== SCREEN 1: USER FOLDER SELECTION ====================
$screen1 = New-Object System.Windows.Forms.Panel
$screen1.Dock = "Fill"
$screen1.BackColor = $win10Colors.Background  # Will be transparent with Mica

# Don't Panic! header
$lblDontPanic = New-Object System.Windows.Forms.Label
$lblDontPanic.Text = "Don't Panic!"
$lblDontPanic.Font = New-Object System.Drawing.Font("Segoe UI", 36, [System.Drawing.FontStyle]::Bold)
$lblDontPanic.ForeColor = $win10Colors.TextPrimary
$lblDontPanic.TextAlign = "MiddleCenter"
$lblDontPanic.BackColor = [System.Drawing.Color]::Transparent  # Transparent for Mica
$lblDontPanic.Anchor = "Top,Left,Right"
$lblDontPanic.Location = New-Object System.Drawing.Point(0, 80)
$lblDontPanic.Height = 60

# Instruction
$lblInstruction = New-Object System.Windows.Forms.Label
$lblInstruction.Text = "Choose your BeamNG.drive user folder."
$lblInstruction.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$lblInstruction.ForeColor = $win10Colors.TextSecondary
$lblInstruction.TextAlign = "MiddleCenter"
$lblInstruction.BackColor = [System.Drawing.Color]::Transparent  # Transparent for Mica
$lblInstruction.Anchor = "Top,Left,Right"
$lblInstruction.Location = New-Object System.Drawing.Point(0, 160)
$lblInstruction.Height = 30

# User folder input
$txtUserFolder = New-Object System.Windows.Forms.TextBox
$txtUserFolder.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$txtUserFolder.BorderStyle = "FixedSingle"
$txtUserFolder.BackColor = $win10Colors.InputBackground  # Dark input background
$txtUserFolder.ForeColor = $win10Colors.TextPrimary     # White text
$txtUserFolder.ReadOnly = $true
$txtUserFolder.Anchor = "Top,Left,Right"
$txtUserFolder.Location = New-Object System.Drawing.Point(50, 220)
$txtUserFolder.Height = 25

$btnBrowse = CreateButton "Browse..." 100 25  # Make button same height as textbox
$btnBrowse.Anchor = "Top,Right"
$btnBrowse.Location = New-Object System.Drawing.Point(0, 220)  # Same Y position as textbox

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Detecting user folder..."
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.ForeColor = $win10Colors.TextSecondary
$lblStatus.BackColor = [System.Drawing.Color]::Transparent  # Transparent for Mica
$lblStatus.Anchor = "Top,Left,Right"
$lblStatus.Location = New-Object System.Drawing.Point(50, 260)
$lblStatus.Height = 20

# Handle screen1 resize
$screen1.Add_Resize({
    if ($screen1.Width -gt 0) {
        $txtUserFolder.Width = $screen1.Width - 170  # Leave space for browse button
        $btnBrowse.Left = $screen1.Width - 110
        $lblDontPanic.Width = $screen1.Width
        $lblInstruction.Width = $screen1.Width
        $lblStatus.Width = $screen1.Width - 100
    }
})

$screen1.Controls.AddRange(@($lblDontPanic, $lblInstruction, $txtUserFolder, $btnBrowse, $lblStatus))

# ==================== SCREEN 2: VEHICLE SELECTION ====================
$screen2 = New-Object System.Windows.Forms.Panel
$screen2.Dock = "Fill"
$screen2.BackColor = $win10Colors.Background  # Will be transparent with Mica
$screen2.Visible = $false

# Container for the list and divider
$listContainer = New-Object System.Windows.Forms.Panel
$listContainer.Anchor = "Top,Bottom,Left,Right"
$listContainer.Location = New-Object System.Drawing.Point(20, 20)

# Vehicle list - full width with dark styling but standard checkboxes
$lstVehicles = New-Object System.Windows.Forms.CheckedListBox
$lstVehicles.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lstVehicles.BorderStyle = "FixedSingle"
$lstVehicles.BackColor = $win10Colors.CardBackground    # Dark card background
$lstVehicles.ForeColor = $win10Colors.TextPrimary       # White text
$lstVehicles.CheckOnClick = $true
$lstVehicles.Dock = "Fill"
# Keep default checkbox rendering for visibility

# Divider line - positioned inside the list area
$dividerLine = New-Object System.Windows.Forms.Panel
$dividerLine.BackColor = $win10Colors.BorderColor
$dividerLine.Height = 1
$dividerLine.Anchor = "Top,Left,Right"

$listContainer.Controls.AddRange(@($lstVehicles, $dividerLine))

# Selected count label
$lblSelectedCount = New-Object System.Windows.Forms.Label
$lblSelectedCount.Text = "Selected: 0"
$lblSelectedCount.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblSelectedCount.ForeColor = $win10Colors.AccentBlue
$lblSelectedCount.BackColor = [System.Drawing.Color]::Transparent  # Transparent for Mica
$lblSelectedCount.TextAlign = "MiddleCenter"
$lblSelectedCount.Anchor = "Bottom,Left,Right"

# Handle screen2 resize
$screen2.Add_Resize({
    if ($screen2.Width -gt 0) {
        $listContainer.Width = $screen2.Width - 40
        $listContainer.Height = $screen2.Height - 70
        
        # Position divider line (approximately after first 2 items)
        $itemHeight = 16  # Approximate height of each list item
        $dividerTop = 2 + (2 * $itemHeight) + 8  # 2px border + 2 items + some padding
        $dividerLine.Location = New-Object System.Drawing.Point(1, $dividerTop)
        $dividerLine.Width = $listContainer.Width - 2
        
        $lblSelectedCount.Location = New-Object System.Drawing.Point(20, ($screen2.Height - 40))
        $lblSelectedCount.Width = $screen2.Width - 40
        $lblSelectedCount.Height = 25
    }
})

# Handle item clicks for special actions
$lstVehicles.Add_ItemCheck({
    param($sender, $e)
    
    # Prevent recursion by checking if we're already processing
    if ($script:processingBulkAction) {
        return
    }
    
    if ($e.Index -eq 0 -and $lstVehicles.Items[0] -eq "[Select None]") {
        # PREVENT the checkbox from being checked at all
        $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
        
        $script:processingBulkAction = $true
        
        # Deselect all items including [Select All]
        for ($i = 1; $i -lt $lstVehicles.Items.Count; $i++) {
            $lstVehicles.SetItemChecked($i, $false)
        }
        
        $script:processingBulkAction = $false
        UpdateSelectedCount
    }
    elseif ($e.Index -eq 1 -and $lstVehicles.Items[1] -eq "[Select All]") {
        $script:processingBulkAction = $true
        
        # Select all vehicle items (skip the first two: [Select None], [Select All])
        for ($i = 2; $i -lt $lstVehicles.Items.Count; $i++) {
            $lstVehicles.SetItemChecked($i, $true)
        }
        
        $script:processingBulkAction = $false
        UpdateSelectedCount
    }
    else {
        # For regular vehicle items
        # If user deselects any vehicle, uncheck [Select All]
        if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Unchecked) {
            if ($lstVehicles.GetItemChecked(1)) {  # If [Select All] is currently checked
                $script:processingBulkAction = $true
                $lstVehicles.SetItemChecked(1, $false)  # Uncheck [Select All]
                $script:processingBulkAction = $false
            }
        }
        # If user selects a vehicle and all vehicles are now selected, check [Select All]
        elseif ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
            $allSelected = $true
            for ($i = 2; $i -lt $lstVehicles.Items.Count; $i++) {
                if (-not $lstVehicles.GetItemChecked($i)) {
                    $allSelected = $false
                    break
                }
            }
            if ($allSelected) {
                $script:processingBulkAction = $true
                $lstVehicles.SetItemChecked(1, $true)  # Check [Select All]
                $script:processingBulkAction = $false
            }
        }
        
        $form.BeginInvoke([System.Action]{
            UpdateSelectedCount
        })
    }
})

$screen2.Controls.AddRange(@($listContainer, $lblSelectedCount))

# ==================== SCREEN 3: SETTINGS ====================
$screen3 = New-Object System.Windows.Forms.Panel
$screen3.Dock = "Fill"
$screen3.BackColor = $win10Colors.Background  # Will be transparent with Mica
$screen3.Visible = $false

# Group 1: Missing Info Files - with dark styling
$grpInfoFiles = New-Object System.Windows.Forms.GroupBox
$grpInfoFiles.Text = "Missing Info Files"
$grpInfoFiles.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grpInfoFiles.ForeColor = $win10Colors.TextPrimary
$grpInfoFiles.FlatStyle = "Flat"
$grpInfoFiles.Anchor = "Top,Left,Right"
$grpInfoFiles.Location = New-Object System.Drawing.Point(20, 20)
$grpInfoFiles.Height = 100

$radioCreateAll = New-Object System.Windows.Forms.RadioButton
$radioCreateAll.Text = "Create missing info files automatically"
$radioCreateAll.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioCreateAll.ForeColor = $win10Colors.TextPrimary
$radioCreateAll.UseVisualStyleBackColor = $true  # Use standard Windows styling
$radioCreateAll.BackColor = [System.Drawing.Color]::Transparent
$radioCreateAll.Location = New-Object System.Drawing.Point(15, 25)
$radioCreateAll.Size = New-Object System.Drawing.Size(400, 20)
$radioCreateAll.Checked = $true

$radioAskEach = New-Object System.Windows.Forms.RadioButton
$radioAskEach.Text = "Ask for each vehicle individually"
$radioAskEach.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioAskEach.ForeColor = $win10Colors.TextPrimary
$radioAskEach.UseVisualStyleBackColor = $true  # Use standard Windows styling
$radioAskEach.BackColor = [System.Drawing.Color]::Transparent
$radioAskEach.Location = New-Object System.Drawing.Point(15, 45)
$radioAskEach.Size = New-Object System.Drawing.Size(400, 20)

$radioSkipCreate = New-Object System.Windows.Forms.RadioButton
$radioSkipCreate.Text = "Don't create any missing info files"
$radioSkipCreate.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioSkipCreate.ForeColor = $win10Colors.TextPrimary
$radioSkipCreate.UseVisualStyleBackColor = $true  # Use standard Windows styling
$radioSkipCreate.BackColor = [System.Drawing.Color]::Transparent
$radioSkipCreate.Location = New-Object System.Drawing.Point(15, 65)
$radioSkipCreate.Size = New-Object System.Drawing.Size(400, 20)

$grpInfoFiles.Controls.AddRange(@($radioCreateAll, $radioAskEach, $radioSkipCreate))

$chkSkipTested = New-Object System.Windows.Forms.CheckBox
$chkSkipTested.Text = "Skip info files that already contain test results (contain 'Off-Road Score')"
$chkSkipTested.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkSkipTested.ForeColor = $win10Colors.TextPrimary
$chkSkipTested.UseVisualStyleBackColor = $true
$chkSkipTested.BackColor = [System.Drawing.Color]::Transparent
$chkSkipTested.Location = New-Object System.Drawing.Point(15, 45)
$chkSkipTested.Size = New-Object System.Drawing.Size(500, 20)

# Group 2: Config File Settings
$grpPlaceholders = New-Object System.Windows.Forms.GroupBox
$grpPlaceholders.Text = "Config File Settings"
$grpPlaceholders.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grpPlaceholders.ForeColor = $win10Colors.TextPrimary
$grpPlaceholders.FlatStyle = "Flat"
$grpPlaceholders.Anchor = "Top,Left,Right"
$grpPlaceholders.Location = New-Object System.Drawing.Point(20, 130)
$grpPlaceholders.Height = 140

$chkUsePlaceholders = New-Object System.Windows.Forms.CheckBox
$chkUsePlaceholders.Text = "Use custom values for created config files"
$chkUsePlaceholders.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkUsePlaceholders.ForeColor = $win10Colors.TextPrimary
$chkUsePlaceholders.UseVisualStyleBackColor = $true  # Use standard Windows styling
$chkUsePlaceholders.BackColor = [System.Drawing.Color]::Transparent
$chkUsePlaceholders.Location = New-Object System.Drawing.Point(15, 25)
$chkUsePlaceholders.Size = New-Object System.Drawing.Size(400, 20)

# Config fields
$lblConfigType = New-Object System.Windows.Forms.Label
$lblConfigType.Text = "Type:"
$lblConfigType.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblConfigType.ForeColor = $win10Colors.TextPrimary
$lblConfigType.Location = New-Object System.Drawing.Point(30, 55)
$lblConfigType.Size = New-Object System.Drawing.Size(60, 20)

$txtConfigType = New-Object System.Windows.Forms.TextBox
$txtConfigType.Text = "Factory"
$txtConfigType.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtConfigType.BorderStyle = "FixedSingle"
$txtConfigType.BackColor = $win10Colors.InputBackground
$txtConfigType.ForeColor = $win10Colors.TextPrimary
$txtConfigType.Location = New-Object System.Drawing.Point(90, 52)
$txtConfigType.Size = New-Object System.Drawing.Size(100, 25)
$txtConfigType.Enabled = $false

$lblValue = New-Object System.Windows.Forms.Label
$lblValue.Text = "Value:"
$lblValue.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblValue.ForeColor = $win10Colors.TextPrimary
$lblValue.Location = New-Object System.Drawing.Point(200, 55)
$lblValue.Size = New-Object System.Drawing.Size(50, 20)

$numValue = New-Object System.Windows.Forms.NumericUpDown
$numValue.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$numValue.BorderStyle = "FixedSingle"
$numValue.BackColor = $win10Colors.InputBackground
$numValue.ForeColor = $win10Colors.TextPrimary
$numValue.Location = New-Object System.Drawing.Point(250, 52)
$numValue.Size = New-Object System.Drawing.Size(80, 25)
$numValue.Maximum = 999999999
$numValue.Value = 50000
$numValue.Enabled = $false

$lblDescription = New-Object System.Windows.Forms.Label
$lblDescription.Text = "Description:"
$lblDescription.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblDescription.ForeColor = $win10Colors.TextPrimary
$lblDescription.Location = New-Object System.Drawing.Point(30, 85)
$lblDescription.Size = New-Object System.Drawing.Size(80, 20)

$txtDescription = New-Object System.Windows.Forms.TextBox
$txtDescription.Text = "Generated with VTAS GUI"
$txtDescription.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtDescription.BorderStyle = "FixedSingle"
$txtDescription.BackColor = $win10Colors.InputBackground
$txtDescription.ForeColor = $win10Colors.TextPrimary
$txtDescription.Location = New-Object System.Drawing.Point(110, 82)
$txtDescription.Size = New-Object System.Drawing.Size(200, 25)
$txtDescription.Enabled = $false

$lblPopulation = New-Object System.Windows.Forms.Label
$lblPopulation.Text = "Population:"
$lblPopulation.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblPopulation.ForeColor = $win10Colors.TextPrimary
$lblPopulation.Location = New-Object System.Drawing.Point(30, 115)
$lblPopulation.Size = New-Object System.Drawing.Size(80, 20)

$numPopulation = New-Object System.Windows.Forms.NumericUpDown
$numPopulation.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$numPopulation.BorderStyle = "FixedSingle"
$numPopulation.BackColor = $win10Colors.InputBackground
$numPopulation.ForeColor = $win10Colors.TextPrimary
$numPopulation.Location = New-Object System.Drawing.Point(110, 112)
$numPopulation.Size = New-Object System.Drawing.Size(80, 25)
$numPopulation.Maximum = 999999999
$numPopulation.Value = 1000
$numPopulation.Enabled = $false

$grpPlaceholders.Controls.AddRange(@($chkUsePlaceholders, $lblConfigType, $txtConfigType, $lblValue, $numValue, $lblDescription, $txtDescription, $lblPopulation, $numPopulation))

# Group 3: Performance Settings
$grpPerformance = New-Object System.Windows.Forms.GroupBox
$grpPerformance.Text = "Performance Settings"
$grpPerformance.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grpPerformance.ForeColor = $win10Colors.TextPrimary
$grpPerformance.FlatStyle = "Flat"
$grpPerformance.Anchor = "Top,Left,Right"
$grpPerformance.Location = New-Object System.Drawing.Point(20, 280)
$grpPerformance.Height = 80

$chkLowestSettings = New-Object System.Windows.Forms.CheckBox
$chkLowestSettings.Text = "Use lowest graphics settings for maximum performance during testing"
$chkLowestSettings.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chkLowestSettings.ForeColor = $win10Colors.TextPrimary
$chkLowestSettings.UseVisualStyleBackColor = $true  # Use standard Windows styling
$chkLowestSettings.BackColor = [System.Drawing.Color]::Transparent
$chkLowestSettings.Location = New-Object System.Drawing.Point(15, 25)
$chkLowestSettings.Size = New-Object System.Drawing.Size(500, 20)

$grpPerformance.Controls.AddRange(@($chkLowestSettings, $chkSkipTested))

# Handle screen3 resize - make groups full width
$screen3.Add_Resize({
    if ($screen3.Width -gt 0) {
        $grpInfoFiles.Width = $screen3.Width - 40
        $grpPlaceholders.Width = $screen3.Width - 40
        $grpPerformance.Width = $screen3.Width - 40
    }
})

$screen3.Controls.AddRange(@($grpInfoFiles, $grpPlaceholders, $grpPerformance))

# ==================== SCREEN 4: TESTING ====================
$screen4 = New-Object System.Windows.Forms.Panel
$screen4.Dock = "Fill"
$screen4.BackColor = $win10Colors.Background  # Will be transparent with Mica
$screen4.Visible = $false

# Console log
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.BackColor = $win10Colors.DarkBackground  # Keep dark for terminal feel
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(0, 204, 102)
$txtLog.BorderStyle = "FixedSingle"
$txtLog.Anchor = "Top,Bottom,Left,Right"
$txtLog.Location = New-Object System.Drawing.Point(20, 20)

# Progress bar - same width as console, at bottom
$lblProgress = New-Object System.Windows.Forms.Label
$lblProgress.Text = "Preparing to start testing..."
$lblProgress.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblProgress.ForeColor = $win10Colors.TextSecondary
$lblProgress.BackColor = [System.Drawing.Color]::Transparent  # Transparent for Mica
$lblProgress.Anchor = "Bottom,Left,Right"
$lblProgress.TextAlign = "MiddleCenter"

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = "Blocks"
$progressBar.Anchor = "Bottom,Left,Right"

# Handle screen4 resize
$screen4.Add_Resize({
    if ($screen4.Width -gt 0) {
        $txtLog.Width = $screen4.Width - 40
        $txtLog.Height = $screen4.Height - 80
        
        $lblProgress.Location = New-Object System.Drawing.Point(20, ($screen4.Height - 55))
        $lblProgress.Width = $screen4.Width - 40
        $lblProgress.Height = 20
        
        $progressBar.Location = New-Object System.Drawing.Point(20, ($screen4.Height - 30))
        $progressBar.Width = $screen4.Width - 40
        $progressBar.Height = 20
    }
})

$screen4.Controls.AddRange(@($txtLog, $lblProgress, $progressBar))

# Add all screens to main panel
$mainPanel.Controls.AddRange(@($screen1, $screen2, $screen3, $screen4))

# Add main panels to form
$form.Controls.AddRange(@($mainPanel, $buttonPanel))

# ==================== NAVIGATION LOGIC ====================
$currentScreen = 1

function ShowScreen($screenNumber) {
    $global:currentScreen = $screenNumber
    
    # Hide all screens
    $screen1.Visible = $false
    $screen2.Visible = $false
    $screen3.Visible = $false
    $screen4.Visible = $false
    
    # Reset button styling to defaults
    $btnNext.BackColor = $win10Colors.ButtonBackground
    $btnNext.ForeColor = $win10Colors.TextPrimary
    $btnBack.BackColor = $win10Colors.ButtonBackground
    $btnBack.ForeColor = $win10Colors.TextPrimary
    
    # Show current screen
    switch ($screenNumber) {
        1 { 
            $screen1.Visible = $true
            $btnBack.Visible = $false
            $btnNext.Visible = $true
            $btnNext.Text = "Next"
            # Re-validate the folder to properly set the enabled state
            if ($global:userFolderPath -and (Test-Path (Join-Path -Path $global:userFolderPath -ChildPath "version.txt"))) {
                ValidateUserFolder $global:userFolderPath
            } else {
                $btnNext.Enabled = $false
            }
        }
        2 { 
            $screen2.Visible = $true
            $btnBack.Visible = $true
            $btnNext.Visible = $true
            $btnNext.Text = "Next"
            $btnNext.Enabled = $true
        }
        3 { 
            $screen3.Visible = $true
            $btnBack.Visible = $true
            $btnNext.Visible = $true
            $btnNext.Text = "Start"
            $btnNext.Enabled = $true
            # Make Start button blue
            $btnNext.BackColor = $win10Colors.AccentBlue
            $btnNext.ForeColor = $win10Colors.TextPrimary
        }
        4 { 
            $screen4.Visible = $true
            $btnBack.Visible = $true
            $btnBack.Enabled = $false
            $btnNext.Visible = $true
            $btnNext.Text = "Cancel"
            $btnNext.Enabled = $true
            # Make Cancel button red
            $btnNext.BackColor = $win10Colors.Error
            $btnNext.ForeColor = $win10Colors.TextPrimary
            # Remove hover effects for red button
            $btnNext.Add_MouseEnter({})
            $btnNext.Add_MouseLeave({})
        }
    }
}

# ==================== EVENT HANDLERS ====================

$btnNext.Add_Click({
    switch ($global:currentScreen) {
        1 { 
            LoadVehicles
            ShowScreen 2
        }
        2 { 
            $global:validVehicles = @()
            # Skip the first two items ([Select None], [Select All]) and only collect actual vehicles
            for ($i = 2; $i -lt $lstVehicles.Items.Count; $i++) {
                if ($lstVehicles.GetItemChecked($i)) {
                    $global:validVehicles += $lstVehicles.Items[$i]
                }
            }
            
            if ($global:validVehicles.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("Please select at least one vehicle before continuing.", "No Vehicles Selected", "OK", "Warning")
                return
            }
            
            ShowScreen 3
        }
        3 { 
            # Set configuration based on radio buttons
            if ($radioCreateAll.Checked) {
                $global:createFilesForAll = "Y"
            } elseif ($radioSkipCreate.Checked) {
                $global:createFilesForAll = "N"
            } else {
                $global:createFilesForAll = "A"
            }
            
            # Set placeholders
            if ($chkUsePlaceholders.Checked) {
                $global:configPlaceholders.Type = $txtConfigType.Text
                $global:configPlaceholders.Description = $txtDescription.Text
                $global:configPlaceholders.Value = [int]$numValue.Value
                $global:configPlaceholders.Population = [int]$numPopulation.Value
            }
            
            # Set performance settings
            $global:useLowestSettings = $chkLowestSettings.Checked
            $global:skipTestedFiles = $chkSkipTested.Checked
            
            ShowScreen 4
            StartTesting
        }
        4 { 
            if ($btnNext.Text -eq "Cancel") {
                # Cancel testing
                $global:testingCancelled = $true
                AddLog "CANCELLING TESTING..."
                
                KillAllBeamNGProcesses
                RestoreOriginalSettings
                
                $lblProgress.Text = "Testing cancelled by user"
                $btnNext.Text = "Exit"
                $btnNext.BackColor = $win10Colors.White
                $btnNext.ForeColor = $win10Colors.TextPrimary
                # Restore normal hover effects
                $btnNext.Add_MouseEnter({
                    $this.BackColor = $win10Colors.AccentBlue
                    $this.ForeColor = $win10Colors.White
                })
                $btnNext.Add_MouseLeave({
                    $this.BackColor = $win10Colors.White
                    $this.ForeColor = $win10Colors.TextPrimary
                })
                $btnBack.Enabled = $true
                
                AddLog "=== TESTING CANCELLED ==="
            } else {
                # Exit application
                KillAllBeamNGProcesses
                RestoreOriginalSettings
                [System.Environment]::Exit(0)
            }
        }
    }
})

$btnBack.Add_Click({
    switch ($global:currentScreen) {
        2 { ShowScreen 1 }
        3 { ShowScreen 2 }
        4 { 
            if ($global:currentBeamNGProcess -and -not $global:currentBeamNGProcess.HasExited) {
                return  # Testing in progress
            }
            
            # Reset and go back to start
            $global:testingCancelled = $false
            $global:validVehicles = @()
            $txtLog.Clear()
            $progressBar.Value = 0
            $lblProgress.Text = "Preparing to start testing..."
            ShowScreen 1
        }
    }
})

$btnBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select BeamNG User Folder"
    if ($folderDialog.ShowDialog() -eq "OK") {
        ValidateUserFolder $folderDialog.SelectedPath
    }
})

$chkUsePlaceholders.Add_CheckedChanged({
    $enabled = $chkUsePlaceholders.Checked
    $txtConfigType.Enabled = $enabled
    $txtDescription.Enabled = $enabled
    $numValue.Enabled = $enabled
    $numPopulation.Enabled = $enabled
})

# ==================== HELPER FUNCTIONS ====================

function AutoDetectUserFolder {
    $defaultPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "BeamNG.drive"
    if (Test-Path $defaultPath) {
        ValidateUserFolder $defaultPath
    } else {
        $lblStatus.Text = "Default path not found. Please browse to select user folder."
        $lblStatus.ForeColor = $win10Colors.Warning
    }
}

function ValidateUserFolder($path) {
    $txtUserFolder.Text = $path
    $global:userFolderPath = $path
    
    $versionFile = Join-Path -Path $path -ChildPath "version.txt"
    if (-not (Test-Path $versionFile)) {
        $lblStatus.Text = "Invalid folder: version.txt not found"
        $lblStatus.ForeColor = $win10Colors.Error
        $btnNext.Enabled = $false
        return
    }
    
    try {
        $versionData = Get-Content -Path $versionFile -Raw -ErrorAction Stop
        $global:selectedUserFolderVersion = $versionData -replace "^(\d+\.\d+)\.\d+.*", '$1'
        
        $vehiclesPath = Join-Path -Path $path -ChildPath (Join-Path -Path $global:selectedUserFolderVersion -ChildPath "vehicles")
        if (Test-Path $vehiclesPath) {
            $lblStatus.Text = "Valid user folder detected (Version: $global:selectedUserFolderVersion)"
            $lblStatus.ForeColor = $win10Colors.Success
            $btnNext.Enabled = $true
        } else {
            $lblStatus.Text = "Invalid folder: vehicles subfolder not found in version $global:selectedUserFolderVersion"
            $lblStatus.ForeColor = $win10Colors.Error
            $btnNext.Enabled = $false
        }
    } catch {
        $lblStatus.Text = "Invalid folder: cannot read version.txt"
        $lblStatus.ForeColor = $win10Colors.Error
        $btnNext.Enabled = $false
    }
}

function LoadVehicles {
    $lstVehicles.Items.Clear()
    
    # Add special action items at the top - no divider item, just visual line
    $lstVehicles.Items.Add("[Select None]")
    $lstVehicles.Items.Add("[Select All]")
    
    # Add actual vehicles
    $vehiclesPath = Join-Path -Path $global:userFolderPath -ChildPath (Join-Path -Path $global:selectedUserFolderVersion -ChildPath "vehicles")
    
    if (Test-Path $vehiclesPath) {
        $vehicles = Get-ChildItem -Path $vehiclesPath -Directory
        foreach ($vehicle in $vehicles) {
            $lstVehicles.Items.Add($vehicle.Name)
        }
    }
    UpdateSelectedCount
}

function UpdateSelectedCount {
    $count = 0
    # Skip the first two items ([Select None], [Select All]) and only count actual vehicles
    for ($i = 2; $i -lt $lstVehicles.Items.Count; $i++) {
        if ($lstVehicles.GetItemChecked($i)) {
            $count++
        }
    }
    $lblSelectedCount.Text = "Selected: $count"
}

function AddLog($message, $bold = $false) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    if ($bold) {
        $txtLog.AppendText("`r`n")
        $txtLog.AppendText("[$timestamp] *** $message ***`r`n")
    } else {
        $txtLog.AppendText("[$timestamp] $message`r`n")
    }
    
    $txtLog.SelectionStart = $txtLog.Text.Length
    $txtLog.ScrollToCaret()
    $form.Refresh()
}

function StartTesting {
    $global:testingCancelled = $false
    
    AddLog "=== STARTING VEHICLE TESTING ==="
    
    if ($global:useLowestSettings) {
        if (ApplyLowestSettings) {
            AddLog "Applied lowest graphics settings for maximum performance"
        } else {
            AddLog "WARNING: Could not apply lowest settings - continuing with current settings"
        }
    }
    
    $vehiclesPath = Join-Path -Path $global:userFolderPath -ChildPath (Join-Path -Path $global:selectedUserFolderVersion -ChildPath "vehicles")
    $totalConfigs = 0
    $createdFiles = 0
    
    foreach ($vehicle in $global:validVehicles) {
        $pcFiles = Get-ChildItem -Path (Join-Path -Path $vehiclesPath -ChildPath $vehicle) -Filter "*.pc"
        $totalConfigs += $pcFiles.Count
    }
    
    $progressBar.Maximum = $totalConfigs
    $progressBar.Value = 0
    $currentProgress = 0
    
    AddLog "Total configurations to process: $totalConfigs"
    AddLog "Selected vehicles: $($global:validVehicles -join ', ')"
    
    foreach ($vehicle in $global:validVehicles) {
        if ($global:testingCancelled) {
            AddLog "Testing stopped due to cancellation"
            return
        }
        
        AddLog ""
        AddLog "Processing vehicle: $vehicle"
        $lblProgress.Text = "Processing vehicle: $vehicle"
        
        $pcFiles = Get-ChildItem -Path (Join-Path -Path $vehiclesPath -ChildPath $vehicle) -Filter "*.pc"
        $missingInfoFiles = @()
        
        foreach ($pcFile in $pcFiles) {
            $infoFileName = "info_$($pcFile.BaseName).json"
            $infoFilePath = Join-Path $pcFile.Directory.FullName $infoFileName
            
            if (Test-Path $infoFilePath) {
                if ($global:skipTestedFiles) {
                    try {
                        $infoContent = Get-Content $infoFilePath -Raw -ErrorAction Stop
                        if ($infoContent -match "Off-Road Score") {
                            AddLog "Skipped (already tested): $($pcFile.Name) -> $infoFileName"
                            continue
                        }
                    } catch {
                        AddLog "Warning: Could not read $infoFileName, will process anyway"
                    }
                }
                AddLog "Found: $($pcFile.Name) -> $infoFileName"
            } else {
                $missingInfoFiles += $pcFile
                AddLog "Missing: $($pcFile.Name) -> $infoFileName"
            }
        }
        
        if ($missingInfoFiles.Count -gt 0) {
            $createFiles = $global:createFilesForAll
            if ($createFiles -eq "A") {
                $result = [System.Windows.Forms.MessageBox]::Show("Create missing info files for $vehicle?", "Create Info Files", "YesNo", "Question")
                $createFiles = if ($result -eq "Yes") { "Y" } else { "N" }
            }
            
            if ($createFiles -eq "Y") {
                foreach ($pcFile in $missingInfoFiles) {
                    $infoFileName = "info_$($pcFile.BaseName).json"
                    $infoFilePath = Join-Path $pcFile.Directory.FullName $infoFileName
                    
                    $infoContent = @{
                        "Config Type" = $global:configPlaceholders.Type
                        Configuration = "$($pcFile.BaseName) (Transmission type)"
                        Description = $global:configPlaceholders.Description
                        Population = $global:configPlaceholders.Population
                        Value = $global:configPlaceholders.Value
                    }
                    
                    $infoContent | ConvertTo-Json | Set-Content $infoFilePath
                    (Get-Content -Path $infoFilePath) -replace '  ', ' ' | Set-Content -Path $infoFilePath
                    AddLog "Created: $infoFileName"
                    $createdFiles++
                }
            }
        }
        
        foreach ($pcFile in $pcFiles) {
            if ($global:testingCancelled) {
                AddLog "Testing stopped due to cancellation"
                return
            }
            
            $currentProgress++
            $progressBar.Value = $currentProgress
            $lblProgress.Text = "Testing: $vehicle - $($pcFile.BaseName) ($currentProgress/$totalConfigs)"
            # Check if we should skip this already-tested configuration
            if ($global:skipTestedFiles) {
                $infoFileName = "info_$($pcFile.BaseName).json"
                $infoFilePath = Join-Path (Join-Path -Path $vehiclesPath -ChildPath $vehicle) $infoFileName
                
                if (Test-Path $infoFilePath) {
                    try {
                        $infoContent = Get-Content $infoFilePath -Raw -ErrorAction Stop
                        if ($infoContent -match "Off-Road Score") {
                            AddLog "Skipping already tested: $($pcFile.BaseName)"
                            continue
                        }
                    } catch {
                        AddLog "Warning: Could not read info file for $($pcFile.BaseName), testing anyway"
                    }
                }
            }
            $workContent = '[{"type": "testVehiclesPerformances", "vehicle":"' + $vehicle + '", "pcFile":"' + $pcFile.BaseName + '"}]'
            Set-Content "work.json" -Value $workContent -NoNewline
            
            AddLog "Testing configuration: $($pcFile.BaseName)" $true
            
            try {
                AddLog "Starting BeamNG.drive.x64.exe..."
                $global:currentBeamNGProcess = Start-Process -FilePath "Bin64\BeamNG.drive.x64.exe" -ArgumentList "-batch -lua extensions.load('util_worker')" -PassThru
                
                $global:allBeamNGProcesses += $global:currentBeamNGProcess
                
                AddLog "BeamNG process started (PID: $($global:currentBeamNGProcess.Id))"
                
                $exitCode = WaitForProcessAsync $global:currentBeamNGProcess
                
                if ($global:testingCancelled) {
                    AddLog "Testing cancelled during BeamNG execution"
                    return
                }
                
                AddLog "BeamNG process exited with code: $exitCode"
                
                $global:allBeamNGProcesses = $global:allBeamNGProcesses | Where-Object { $_.Id -ne $global:currentBeamNGProcess.Id }
                $global:currentBeamNGProcess = $null
                
            } catch {
                AddLog "ERROR: Failed to start BeamNG.drive.x64.exe - $($_.Exception.Message)"
                $exitCode = -1
                $global:currentBeamNGProcess = $null
            }
            
            if ($exitCode -eq 0) {
                AddLog "Completed: $($pcFile.BaseName)"
            } else {
                AddLog "FAILED: $($pcFile.BaseName) (Exit code: $exitCode)"
            }
            
            $form.Refresh()
        }
    }
    
    if (-not $global:testingCancelled) {
        AddLog ""
        AddLog "=== TESTING COMPLETE ==="
        AddLog "Vehicles tested: $($global:validVehicles -join ', ')"
        AddLog "Total configurations processed: $totalConfigs"
        AddLog "Info files created: $createdFiles"
        
        $lblProgress.Text = "Testing completed successfully!"
        
        RestoreOriginalSettings
        
        $btnNext.Text = "Exit"
        $btnNext.BackColor = $win10Colors.ButtonBackground
        $btnNext.ForeColor = $win10Colors.TextPrimary
        $btnBack.Enabled = $true
        
        [System.Windows.Forms.MessageBox]::Show("Vehicle testing completed!`n`nTotal configurations: $totalConfigs`nInfo files created: $createdFiles", "Testing Complete", "OK", "Information")
    }
}

function ApplyLowestSettings {
    try {
        $scriptPath = $PSScriptRoot
        if (-not $scriptPath) {
            $scriptPath = Get-Location
        }
        $lowestSettingsFile = Join-Path $scriptPath "settings-lowest.json"
        
        AddLog "Looking for settings-lowest.json at: $lowestSettingsFile"
        
        if (-not (Test-Path $lowestSettingsFile)) {
            AddLog "ERROR: settings-lowest.json not found at $lowestSettingsFile"
            return $false
        }
        
        $settingsFolder = Join-Path -Path $global:userFolderPath -ChildPath (Join-Path -Path $global:selectedUserFolderVersion -ChildPath "settings")
        $currentSettingsFile = Join-Path $settingsFolder "settings.json"
        $global:settingsBackupPath = Join-Path $settingsFolder "settings.json.bak"
        
        AddLog "Settings folder: $settingsFolder"
        AddLog "Current settings file: $currentSettingsFile"
        AddLog "Backup path: $global:settingsBackupPath"
        
        if (-not (Test-Path $settingsFolder)) {
            AddLog "Creating settings folder: $settingsFolder"
            New-Item -ItemType Directory -Path $settingsFolder -Force | Out-Null
        }
        
        if (Test-Path $currentSettingsFile) {
            Copy-Item $currentSettingsFile $global:settingsBackupPath -Force
            AddLog "Backed up original settings to settings.json.bak"
        } else {
            AddLog "No existing settings.json found - will create new one"
        }
        
        Copy-Item $lowestSettingsFile $currentSettingsFile -Force
        AddLog "Applied lowest graphics settings from $lowestSettingsFile"
        
        if (Test-Path $currentSettingsFile) {
            AddLog "Successfully created new settings.json"
            return $true
        } else {
            AddLog "ERROR: Failed to create new settings.json"
            return $false
        }
        
    } catch {
        AddLog "ERROR applying lowest settings: $($_.Exception.Message)"
        AddLog "Stack trace: $($_.ScriptStackTrace)"
        return $false
    }
}

function RestoreOriginalSettings {
    if ($global:settingsBackupPath -and (Test-Path $global:settingsBackupPath)) {
        try {
            $settingsFolder = Join-Path -Path $global:userFolderPath -ChildPath (Join-Path -Path $global:selectedUserFolderVersion -ChildPath "settings")
            $currentSettingsFile = Join-Path $settingsFolder "settings.json"
            
            AddLog "Restoring settings from: $global:settingsBackupPath"
            AddLog "Restoring to: $currentSettingsFile"
            
            Copy-Item $global:settingsBackupPath $currentSettingsFile -Force
            Remove-Item $global:settingsBackupPath -Force
            
            AddLog "Restored original graphics settings"
            $global:settingsBackupPath = ""
        } catch {
            AddLog "ERROR restoring settings: $($_.Exception.Message)"
            AddLog "Stack trace: $($_.ScriptStackTrace)"
        }
    } else {
        if ($global:settingsBackupPath) {
            AddLog "No backup file found at: $global:settingsBackupPath"
        }
    }
}

function KillAllBeamNGProcesses {
    AddLog "Checking for running BeamNG processes..."
    
    foreach ($process in $global:allBeamNGProcesses) {
        if ($process -and -not $process.HasExited) {
            try {
                AddLog "Terminating tracked BeamNG process (PID: $($process.Id))..."
                $process.Kill()
                $process.WaitForExit(3000)
                AddLog "Process terminated successfully"
            } catch {
                AddLog "Error terminating tracked process: $($_.Exception.Message)"
            }
        }
    }
    
    try {
        $beamngProcesses = Get-Process -Name "BeamNG.drive.x64" -ErrorAction SilentlyContinue
        foreach ($process in $beamngProcesses) {
            try {
                AddLog "Found running BeamNG process (PID: $($process.Id)), terminating..."
                $process.Kill()
                $process.WaitForExit(3000)
                AddLog "BeamNG process terminated"
            } catch {
                AddLog "Error terminating BeamNG process: $($_.Exception.Message)"
            }
        }
        
        if ($beamngProcesses.Count -eq 0) {
            AddLog "No running BeamNG processes found"
        }
    } catch {
        AddLog "Error checking for BeamNG processes: $($_.Exception.Message)"
    }
    
    $global:allBeamNGProcesses = @()
    $global:currentBeamNGProcess = $null
}

function WaitForProcessAsync($process) {
    AddLog "Waiting for BeamNG to complete test..."
    
    while (-not $process.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        
        if ($global:testingCancelled) {
            AddLog "Process wait cancelled by user"
            return -1
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    return $process.ExitCode
}

# Initialize and show the form
ShowScreen 1
$form.ShowDialog()
