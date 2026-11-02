# Convert Word Files to Faithful PDFs with a Gotenberg Sidecar

## Problem
An app builds a tailored resume as a Word file, and the PDF made from it goes to employers, so PDF fidelity is what the reader sees. The app's own drawn PDF was an approximation. Beside the Word rendering it came out in a serif font instead of Roboto, lost the heading color and every bold line, and ran three pages instead of two.

## Fix
Gotenberg's LibreOffice-only image wraps LibreOffice in an HTTP API (`POST /forms/libreoffice/convert`, multipart field `files`) and handles supervision, timeouts and recycling. The image is pinned at `8.37.0-libreoffice`, about 443 MB compressed. Its Carlito, Caladea and Liberation fonts stand in for Calibri, Cambria, Arial and Times with identical widths, so line and page breaks match Word.

1. Add the sidecar on an `internal: true` network shared only with the app, with no published ports. It has no authentication and runs documents through LibreOffice, so never expose it publicly.
2. Use `--libreoffice-auto-start=false` to start LibreOffice on first use, `--libreoffice-restart-after=10` to bound memory growth, and a 768 MB limit. Hardening: `no-new-privileges`, no capabilities, read-only fonts.
3. Mount a folder of Roboto, Carlito and Liberation files read-only under `/usr/share/fonts`. Verify with `docker compose exec pdf-converter fc-match Roboto`.
4. Give the app `CONVERTER_URL`. It POSTs the exact `.docx` it built and stores the PDF that comes back. The app distrusts the reply: no redirects, 10 MB in, 20 MB out, and the body must start with `%PDF-`.
5. Keep the drawn PDF as the fallback. A timeout (20 seconds by default), network error, non-200 answer, oversize file or non-PDF body raises an error. The caller uses the drawn PDF, labels it an approximation and adds a render note.

## Gotchas
- **The image has no Roboto.** `fc-match Roboto` gives Noto Sans, and the resume converted to four pages in Noto Serif, worse than the drawn PDF. With the fonts mounted it came out as two pages in Roboto.
- **Calibri and Cambria are not in the image.** Their stand-ins match widths, not every letterform. A font with no metric twin shifts page breaks.
- **Name the upload `.docx`.** LibreOffice picks its importer by extension.

## Result
On a NAS the container used about 6 MB idle and about 100 MB after a conversion, against its 768 MB limit, and a first conversion took about 2 seconds cold. A Word-built resume converts to two pages in Roboto, matching the Word rendering. A converter that is down, slow or wrong costs fidelity, never availability.

## Script
If you have a similar problem, here is a script you can try. The script reads only the `.docx` you name and writes only the PDF at `-OutPath`. The sidecar publishes no ports, so run it from inside that network or against a throwaway copy.

```yaml
# compose.yaml: an app and a Gotenberg (LibreOffice) PDF converter sidecar. No ports are published.
services:
  app:
    image: registry.example.com/app:1.0.0
    restart: unless-stopped
    environment:
      CONVERTER_URL: http://pdf-converter:3000   # remove this line and the app uses its own drawn PDF
    networks: [default, pdf-internal]            # default is the app's normal route in and out; pdf-internal is shared with the converter only
    depends_on: [pdf-converter]                  # the converter starts with the app; if it is down or slow the app still answers
    read_only: true
    tmpfs: [/tmp]
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]

  pdf-converter:
    # LibreOffice-only Gotenberg, pinned. It has no authentication: keep it off every published port.
    image: gotenberg/gotenberg:8.37.0-libreoffice
    restart: unless-stopped
    command:
      - gotenberg
      - --api-timeout=30s
      - --libreoffice-auto-start=false   # start soffice on first use instead of at boot
      - --libreoffice-restart-after=10   # recycle soffice to bound memory growth
      - --log-level=warn
    volumes:
      # Roboto, Carlito and Liberation font files. The image has no Roboto; fontconfig finds these without fc-cache.
      - ./fonts:/usr/share/fonts/custom:ro
    mem_limit: 768m
    memswap_limit: 768m
    pids_limit: 256
    networks: [pdf-internal]
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]

networks:
  pdf-internal:
    driver: bridge
    internal: true   # no outbound access: the converter never needs the internet
```

```powershell
<#
.SYNOPSIS
Sends one .docx to a Gotenberg LibreOffice converter and checks the PDF that comes back.

.DESCRIPTION
Test-PdfSidecar.ps1 posts one Word file as multipart form data (field name "files") to
{ConverterUrl}/forms/libreoffice/convert, the route an app uses. It reports the HTTP status,
elapsed time and output size, then checks that the output starts with "%PDF-".
It reads only the .docx you name and writes only the PDF at -OutPath.
Exit code 0 means HTTP 200 and a PDF came back; 1 means anything else.

.PARAMETER ConverterUrl
Base URL of the converter. Default: http://localhost:3000

.PARAMETER DocxPath
Path to the .docx file to convert.

.PARAMETER OutPath
Where to write the returned PDF. Default: pdf-sidecar-test.pdf in the temp folder.

.EXAMPLE
./Test-PdfSidecar.ps1 -DocxPath ./sample.docx -OutPath ./sample.pdf
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ConverterUrl = 'http://localhost:3000',
    [Parameter(Mandatory)][string]$DocxPath,
    [string]$OutPath = (Join-Path ([System.IO.Path]::GetTempPath()) 'pdf-sidecar-test.pdf')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DocxPath -PathType Leaf)) {
    Write-Host "FAIL: file not found: $DocxPath"
    exit 1
}
$docx = Get-Item -LiteralPath $DocxPath
if ($docx.Extension -ne '.docx') {
    Write-Warning 'The file does not end in .docx; LibreOffice chooses its importer by extension.'
}

$endpoint = $ConverterUrl.TrimEnd('/') + '/forms/libreoffice/convert'
Write-Host "POST $endpoint ($($docx.Name), $($docx.Length) bytes)"

$status = 0
$watch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    # -SkipHttpErrorCheck keeps a 4xx/5xx from throwing, so the status is reported either way.
    $response = Invoke-WebRequest -Uri $endpoint -Method Post -Form @{ files = $docx } `
        -OutFile $OutPath -PassThru -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 60
    $status = [int]$response.StatusCode
} catch {
    $watch.Stop()
    # Connection errors and redirects (not followed) land here.
    if ((Test-Path -LiteralPath $OutPath) -and (Get-Item -LiteralPath $OutPath).Length -eq 0) { Remove-Item -LiteralPath $OutPath -Force }
    Write-Host ("FAIL: request failed after {0:N2} s: {1}" -f $watch.Elapsed.TotalSeconds, $_.Exception.Message)
    exit 1
}
$watch.Stop()

$size = 0
$isPdf = $false
if (Test-Path -LiteralPath $OutPath) {
    $size = (Get-Item -LiteralPath $OutPath).Length
    $head = New-Object byte[] 5
    $stream = [System.IO.File]::OpenRead($OutPath)
    try { $read = $stream.Read($head, 0, 5) } finally { $stream.Dispose() }
    $isPdf = ($read -eq 5) -and ([System.Text.Encoding]::ASCII.GetString($head) -eq '%PDF-')
}

Write-Host ("Status:  {0}" -f $status)
Write-Host ("Elapsed: {0:N2} s" -f $watch.Elapsed.TotalSeconds)
Write-Host ("Size:    {0:N0} bytes" -f $size)
Write-Host ("PDF:     {0}" -f $(if ($isPdf) { 'yes, starts with %PDF-' } else { 'no' }))

if ($status -eq 200 -and $isPdf) {
    Write-Host "OK: saved $OutPath"
    exit 0
}
if ($size -gt 0 -and -not $isPdf) { Remove-Item -LiteralPath $OutPath -Force }   # do not leave an error page named .pdf
Write-Host 'FAIL: expected HTTP 200 and a PDF.'
exit 1
```
