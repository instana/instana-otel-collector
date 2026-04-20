# MSI Installer Assets

Graphical assets used in the Windows MSI installer. Current files are **placeholders** — replace with Instana-branded assets before production release.

## Required Assets

| File | Format | Size | Purpose |
|------|--------|------|---------|
| `idot64.ico` | ICO | 64x64 (multi-res) | Application icon in Add/Remove Programs |
| `idot64.png` | PNG | 64x64 | Logo for documentation |
| `banner.bmp` | BMP 24-bit | 493 x 58 | Top banner in installer dialogs |
| `welcome.bmp` | BMP 24-bit | 493 x 312 | Welcome/completion screen image |

## Regenerating Placeholders

```powershell
cd tools/packaging/windows/idot-windows-installer/assets
.\create-placeholders.ps1
```

## Status

- [x] idot64.ico — Placeholder (solid teal/blue)
- [x] idot64.png — Placeholder (solid teal/blue)
- [x] banner.bmp — Placeholder (solid teal/blue, 493x58)
- [x] welcome.bmp — Placeholder (solid teal/blue, 493x312)

Replace with final branded assets per IBM/Instana brand guidelines before production release.
