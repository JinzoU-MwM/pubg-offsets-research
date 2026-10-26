# PUBG (TslGame) Offset Research — Dokumentasi

Riset offset untuk **PUBG: BATTLEGROUNDS** (Steam AppID `578080`, build `26072644`)
pada instalasi milik Presiden di `muklis-laptop` (Windows 11, DESKTOP-3IDCMF5).

Status: **OFFSETS BELUM TERAMBIL** — binary terproteksi (KRAFTON Zakynthos + BattlEye),
`.text` terenkripsi di disk dan di proses stub; proses game utama memblokir
`ReadProcessMemory` dari luar (error 5). Jalur lanjutan sudah dipetakan di
[docs/05](docs/05-offsets-status-dan-next.md).

## Isi repo

| Path | Isi |
|---|---|
| `docs/01-target-inventory.md` | Mesin, instalasi, build, inventaris binary + SHA-256 |
| `docs/02-static-analysis.md` | Analisis proteksi: entropy, layout section, hasil ekstraksi `.rdata` |
| `docs/03-runtime-experiment.md` | Launch chain, service/driver, hasil uji baca memori proses |
| `docs/04-evidence-log.md` | Log perintah + output mentah (timeline) |
| `docs/05-offsets-status-dan-next.md` | Status offset, blocker, jalur lanjutan |
| `tools/ModDump.ps1` | Dump satu modul proses via `ReadProcessMemory` (manifest JSON) |
| `tools/DumpAll.ps1` | Dump semua region committed-readable sebuah proses |
| `tools/Capture.ps1` | Watcher: deteksi proses game + cek status dekripsi `.text` |
| `tools/analyze_binary.py` | Analisis entropy/section/PE + uji kompresi & XOR periodik |
| `tools/extract_rdata_strings.py` | Ekstraksi korpus string UTF-16 dari `.rdata` |
| `data/` | Section table, statistik string, korpus string (gz), SHA-256 |

## Ringkasan temuan (TL;DR)

1. `TslGame.exe` (237 MB, sha256 `2d80e1b4…9853`) punya **AddressOfEntryPoint = 0** dan
   17 section, termasuk section tambahan `.pubg0` (82 MB) dan `sect_8..sect_14`.
2. `.text` (73 MB) entropy **8.000**, `.data` **8.000**, `.pubg0` **7.993** →
   terenkripsi. `.rdata` (42 MB) entropy 5.41 → **plaintext**, berisi 123.681 string
   UTF-16 unik (kelas/properti/fungsi UE4, path build, dsb).
3. Tidak ada signature kompresi standar dan tidak ada pola XOR periodik;
   stub di `sect_9`/`sect_13` ter-obfuscate (coverage disassembler ≈ 0) → kelas VM.
4. Runtime: Steam → `TslGame_ZK.exe` → pasang `zksvc.exe` + driver kernel
   `navagio.sys` → `TslGame_BE.exe` (BattlEye) → `TslGame.exe` (stub) → `TslGame.exe`
   (proses game, ~4 GB working set).
5. Proses game (PID 7276) **memblokir** `ReadProcessMemory` (OpenProcess berhasil,
   read = `ERROR_ACCESS_DENIED` 5). Proses stub (PID 5656) terbaca, tapi `.text`-nya
   masih terenkripsi (entropy 7.998) → dekripsi terjadi di proses game yang terproteksi.

Detail lengkap + bukti mentah ada di `docs/`.

## Peringatan

- Binary game **tidak** disertakan di repo ini (hanya hash + analisis).
- Eksperimen runtime dilakukan pada akun Steam milik Presiden dengan BattlEye aktif.
  Setiap upaya baca memori pihak ketiga berisiko penalti akun.
