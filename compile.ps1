Write-Host "Compiling SMARTLARK..." -ForegroundColor Cyan
& dcc32 SMARTLARK.dpr
if ($LASTEXITCODE -eq 0) {
    Write-Host "Compilation successful!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Compilation failed with error code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

