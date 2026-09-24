Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("C:\Users\atubt\OneDrive\Desktop\App projects\Vitanet\assets\logo.png")
$img.MakeTransparent([System.Drawing.Color]::White)
$img.Save("C:\Users\atubt\OneDrive\Desktop\App projects\Vitanet\assets\logo_transparent.png", [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Write-Host "Done"
