# AddyMouseHID

A Raw Input wrapper designed for Windows that can be used in **MATLAB**, **PowerShell**, and **CMD**. This library bypasses standard Windows mouse acceleration to provide raw sensor deltas and 5-button click states.

## Features

* **Raw Deltas**: Access high-precision  and  movement.
* **5-Button Support**: Detects Down/Up states for Left, Right, Middle, and Side buttons.
* **Scroll Tracking**: Reports vertical scroll direction and magnitude.
* **Spatial Calibration**: Linear data allows for easy conversion to millimeters (mm).
* **Zero Dependencies**: Built on .NET Framework 4.7.2 for maximum compatibility.

---

## Compilation (Generating the DLL)

To build the project and generate a clean `AddyMouseHID.dll` in your project root:

1. Open a Powershell in the project folder.
2. Run the following command:
```cmd
dotnet build -c Release

```


3. The project is configured to automatically clean up the `obj` folder and remove debug `.pdb` files, leaving only the production DLL.

---

## Usage in MATLAB

1. Ensure `AddyMouseHID.dll` is in your MATLAB path.
2. Load the library and start the reader:

```matlab
if exist('mouse', 'var') && isvalid(mouse)
    mouse.Stop();
    delete(mouse);
end
clear mouse;

if exist('hListener', 'var') && isvalid(hListener)
    delete(hListener);
end
clear hListener;

clear; clc
dllPath = 'C:\test\';
dllname = 'AddyMouseHID.dll';
asm = NET.addAssembly([dllPath,dllname]);
disp(asm.Classes)

%% 

% 1. Create the Reader object
mouse = AddyMouseHID.MouseReader();

% 2. Attach the listener 
% MATLAB now understands 'OnMouseDelta' because it follows the standard pattern
hListener = addlistener(mouse, 'OnMouseDelta', @handleMouseData);

% 3. Start the stream
% Your new Start() method doesn't require arguments as it listens to ALL mice
mouse.Start();

fprintf('Streaming started. Move your mouse to see deltas.\n');
fprintf('To stop, run: mouse.Stop(); delete(hListener);\n');

% --- Callback Function ---
function handleMouseData(~, e)
    % 'e' is now an instance of MatlabHid.MouseDeltaEventArgs
    % We access the X and Y properties directly
    dx = e.X;
    dy = e.Y;
    buttons = e.Buttons;

    % 1. Map bits to strings
    % We use a cell array for quick lookup of the transition bits
    bitValues = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
    labels = {'L-Down', 'L-Up', 'R-Down', 'R-Up', 'M-Down', 'M-Up', 'S1-Down', 'S1-Up', 'S2-Down', 'S2-Up'};
    
    btnStr = '';
    
    % 1. Handle Standard Buttons
    for i = 1:length(bitValues)
        if bitand(buttons, bitValues(i))
            if isempty(btnStr)
                btnStr = labels{i};
            else
                btnStr = [btnStr, '+', labels{i}]; 
            end
        end
    end

    % 2. Handle Vertical Scroll (Flag 1024)
    if bitand(buttons, 1024)
        scrollLabel = 'Scroll-Down';
        if e.Wheel > 0, scrollLabel = 'Scroll-Up'; end
        
        if isempty(btnStr), btnStr = scrollLabel;
        else, btnStr = [btnStr, '+', scrollLabel]; end
    end

    % 3. Handle Horizontal Scroll (Flag 2048 - Tilt Wheel)
    if bitand(buttons, 2048)
        tiltLabel = 'Tilt-Left';
        if e.Wheel > 0, tiltLabel = 'Tilt-Right'; end
        
        if isempty(btnStr), btnStr = tiltLabel;
        else, btnStr = [btnStr, '+', tiltLabel]; end
    end

    if isempty(btnStr), btnStr = 'None'; end
    
    % Your updated fprintf
    fprintf('dX: %+4d | dY: %+4d | Action: %s\n', dx, dy, btnStr);
end


%% Uncomment and execute to close the listner and the mouse object
% 
% mouse.Stop();
% delete(mouse);
% clear mouse;
% delete(hListener)


```

---

## Usage in CMD (.bat file)

Create a file named `RunMouse.bat` in the same folder as the DLL and paste the following:

```batch
@echo off
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $dllPath='AddyMouseHID.dll'; Add-Type -Path $dllPath; $m=New-Object AddyMouseHID.MouseReader; $map = @{1='L-Down'; 2='L-Up'; 4='R-Down'; 8='R-Up'; 16='M-Down'; 32='M-Up'; 64='S1-Down'; 128='S1-Up'; 256='S2-Down'; 512='S2-Up'; 2048='Tilt'}; Register-ObjectEvent -InputObject $m -EventName OnMouseDelta -SourceIdentifier 'MouseEvents'; $m.Start(); Write-Host 'Streaming to CMD... Press Ctrl+C to stop'; try { while($true) { $events = Get-Event -SourceIdentifier 'MouseEvents' -ErrorAction SilentlyContinue; if($events) { foreach($ev in $events) { $d=$ev.SourceEventArgs; $bStr = ''; foreach($key in $map.Keys){ if($d.Buttons -band $key){ $bStr += ($map[$key] + ' ') } }; if($d.Buttons -band 1024){ if($d.Wheel -gt 0){ $bStr += 'Scroll-Up ' } else { $bStr += 'Scroll-Down ' } }; if($bStr -eq ''){ $bStr = 'None' }; Write-Host ('dX: {0,4} | dY: {1,4} | Action: {2}' -f $d.X, $d.Y, $bStr.Trim()); Remove-Event -EventIdentifier $ev.EventIdentifier } }; [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -m 1 } } finally { $m.Stop() }"
pause

```

---

## Important Notes

* **Architecture**: This DLL is designed for **x64** environments.
* **Anti-Cheat**: While this is a passive listener, close the script before playing competitive games to avoid false-positive flags from kernel-level anti-cheats.

---
