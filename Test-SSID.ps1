# Quick test to debug SSID detection
$netshOutput = netsh wlan show interfaces | Out-String

Write-Host "=== Full netsh output ===" -ForegroundColor Cyan
Write-Host $netshOutput
Write-Host "=========================" -ForegroundColor Cyan

Write-Host "`nTrying Profile regex..." -ForegroundColor Yellow
$profileMatch = $netshOutput | Select-String "^\s*Profile\s*:\s*(.+)" | Select-Object -First 1

if ($profileMatch) {
    $ssid = $profileMatch.Matches[0].Groups[1].Value.Trim()
    Write-Host "Found: '$ssid'" -ForegroundColor Green
}
else {
    Write-Host "No match" -ForegroundColor Red
}

Write-Host "`nTrying SSID regex..." -ForegroundColor Yellow
$ssidMatch = $netshOutput | Select-String "^\s*SSID\s*:\s*(.+)" | Select-Object -First 1

if ($ssidMatch) {
    $ssid = $ssidMatch.Matches[0].Groups[1].Value.Trim()
    Write-Host "Found: '$ssid'" -ForegroundColor Green
}
else {
    Write-Host "No match" -ForegroundColor Red
}
