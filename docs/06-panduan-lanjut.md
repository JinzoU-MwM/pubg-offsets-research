# 06 — Panduan Lanjut di Laptop Lain

Checklist supaya riset bisa dilanjutkan tanpa mengulang dari nol.

## 1. Ambil repo + artefak

```bash
gh auth login
gh repo clone JinzoU-MwM/pubg-offsets-research
cd pubg-offsets-research
bash tools/fetch_artifacts.sh ./artifacts
cd artifacts && sha256sum -c SHA256SUMS.txt
```

## 2. Toolchain yang dipakai (terverifikasi di riset ini)

| Tool | Versi/keperluan |
|---|---|
| radare2 / rizin | `rz-bin -S`, `rz-bin -H` (section & header) |
| Capstone 5.0.7 | cek coverage disassembly (deteksi stub ter-VM) |
| Ghidra (`/opt/ghidra/support/analyzeHeadless`) | analisis lanjutan image hasil dekripsi |
| REA MCP (reverse-engineering agent) | `open_binary`, `analyze_function`, `search_strings`, `xrefs` |
| Volatility 3 (`/usr/bin/vol`, v2.28.2) | analisis `MEMORY.DMP` |
| Python 3 + `zlib/lzma/bz2` | uji kompresi |
| PowerShell (di host Windows) | `tools/*.ps1` untuk dump proses |
| SSH key ke `muklis-laptop` (Tailscale) | host: `desktop-m78f91m\user`, elevated |

## 3. Status terakhir yang harus diingat

- `.text` PUBG = **terenkripsi**, `.rdata` = **plaintext** (123.681 string UTF-16).
- Proses stub PID 5656: terbaca, tapi `.text` masih terenkripsi (entropy 7.998).
- Proses game PID 7276: diblokir (`RPM err=5`). Ini blocker utama.
- Driver proteksi: `C:\Program Files\Common Files\PUBG\navagio.sys` (service `navagio`).
- BattlEye terpasang via `TslGame_BE.exe 1 0`; `BEService` harus RUNNING supaya game
  mau lanjut dari stub ke proses game.

## 4. Langkah lanjut yang paling murah dulu

1. **Nyalakan host** (`muklis-laptop`), lanjutkan `gh`/ssh.
2. Ambil artefak yang belum terunggah: `all_28188_zksvc.bin` + `*.manifest.json`
   dari `C:\Users\User\pubgcap\`, lalu `gh release upload v1.0-artifacts <file>`.
3. Jalur A (docs/05): aktifkan complete crash dump, jalankan game sampai menu,
   trigger bugcheck, ambil `C:\Windows\MEMORY.DMP`, analisis dengan Volatility 3.
   Target output: `windows.memmap --pid <game> --dump` → image terdekripsi.
4. Setelah image terdekripsi: cari `GWorld`, `GNames`/`FNamePool`, `GObjects`
   lewat xref string/global; lalu parse tabel `PropPointers` untuk offset properti.

## 5. Kriteria sukses

- `.text` image hasil dump: entropy ≈ 6,2 dan coverage disassembly > 0,9.
- `GWorld` menunjuk ke objek dengan vtable di `.rdata` image.
- Daftar `nama:offset` per kelas (`TslCharacter`, `TslPlayerController`,
  `TslWeaponProcessor`, dst.) ter-generate dan tervalidasi silang dengan korpus
  string di `data/rdata_utf16_strings.txt.gz`.
