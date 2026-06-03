$content = Get-Content 'src\shared\FishConfig.lua' -Raw
$content = [regex]::Replace($content, '(EnergyRequired\s*=\s*)([0-9.]+)(,?)', {
    param($m)
    $val = [double]$m.Groups[2].Value
    $newval = [Math]::Round($val * 1.33)
    return $m.Groups[1].Value + $newval + $m.Groups[3].Value
})
Set-Content 'src\shared\FishConfig.lua' $content -Encoding UTF8
