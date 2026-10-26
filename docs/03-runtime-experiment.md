# 03 — Eksperimen Runtime (SSH ke muklis-laptop)

Semua perintah dijalankan non-interaktif lewat SSH:
`ssh muklis-laptop "powershell -NoProfile -EncodedCommand <base64-utf16le>"`.

## 3.1 Launch chain yang teramati

Percobaan `Start-Process 'steam://rungameid/578080'` + watcher proses (sampling 3 s):

```
t=33s  TslGame_ZK       (loader Zakynthos)
t=36s  zksvc            (service KRAFTON, dipasang ke C:\Program Files\Common Files\PUBG)
t=39s  TslGame_BE       (bootstrap BattlEye)
t=60s  TslGame   5656   (stub, working set ~32 MB)
t=63s  TslGame   7276   (proses game, working set 3,7–4,4 GB)
```

Command line proses game (dari `Win32_Process`):

```
TslGame.exe -HitchFpsPercentage=5 -CrashSendLog
  -LobbyUrl=https://prod-live-front.playbattlegrounds.com?provider=steam
  -NoAce -EnableScreenshotWhenCrash -EnableIntegrityCheck
  -CohDiskCache -UserBE -Xe -WatchDogPort=65476 -ExecPubgStartTimeStamp=103477429740
```

`-UserBE` + `-Xe` (Xenuine) + `-EnableIntegrityCheck` menandakan dua lapis proteksi
(BattlEye user-mode + Zakynthos).

## 3.2 Service & driver setelah launch

```
sc query navagio   -> STATE: 4 RUNNING, kernel driver,
                      BINARY_PATH_NAME \??\C:\Program Files\Common Files\PUBG\navagio.sys
sc query BEService -> STATE: 4 RUNNING
sc query BEDaisy   -> FAILED 1060 (tidak ada service terpisah)
```

Event log System mencatat pemasangan service `navagio` (kernel mode, demand start)
dan `BattlEye Service` saat launch pertama.

## 3.3 Uji akses memori proses (kunci hasil)

`OpenProcess(PROCESS_QUERY_INFORMATION|VM_READ)` + `ReadProcessMemory` dari proses
PowerShell elevated:

| PID | Proses | OpenProcess | ReadProcessMemory |
|---|---|---|---|
| 6848 | `BEService.exe` | OK | OK |
| 19460 | `TslGame_BE.exe` | OK | OK |
| 28188 | `zksvc.exe` | OK | OK |
| 5656 | `TslGame.exe` (stub) | OK | **OK** |
| 7276 | `TslGame.exe` (game, 4,4 GB) | OK | **GAGAL, `GetLastError()=5` (ACCESS_DENIED)** |

Watcher `Capture.ps1` pada percobaan yang sama mencatat:

```
FOUND pid=5656 at 2026-10-25T17:30:14.85+07:00
BASE=0x0 module=
RPM_FAIL at t=0 err=5 ... (berulang)
```

`MainModule` juga kosong untuk PID 7276 → handle yang diberikan kernel sudah
"di-strip" akses bacanya oleh callback milik driver proteksi.

## 3.4 Dump proses stub (PID 5656)

`DumpAll.ps1 -ProcId 5656` → `regions=114 bytes=474.279.936`.

Analisis dump (`tools/analyze_binary.py` + parser PE):

- Ditemukan image PE utuh di offset dump `0x9ed000`:
  `machine 0x8664, 17 section, TimeDateStamp 1792475941` (sama dengan `TslGame.exe`),
  `ImageBase 0x7ff637ef0000` (ASLR), `SizeOfImage 0x1b1eb000`.
- Entropy `.text` di dalam dump = **7.998** → **masih terenkripsi**.
- `.rdata` di dump = plaintext (entropy 5.066, marker `WindowsNoEditor` di
  `0x10d559a8`, `++UE4+Release-4.16` di `0x11cb36a8`).

Kesimpulan: PID 5656 adalah **stub sebelum dekripsi**. Dekripsi `.text` terjadi di
proses game (PID 7276) yang aksesnya diblokir.

## 3.5 Percobaan dump proses game (PID 7276)

`DumpAll.ps1 -ProcId 7276`:

```
regions=28327 bytes=0
```

28.327 region ter-enumerasi (VirtualQueryEx masih jalan), tetapi **nol byte** berhasil
dibaca; seluruh isi file hasil adalah nol (7,5 GB) dan langsung dihapus di host.

## 3.6 Catatan opsec

- Eksperimen memakai akun Steam Presiden dengan BattlEye aktif; setiap upaya baca
  memori pihak ketiga berisiko penalti akun.
- Driver `navagio.sys` (KRAFTON) berjalan di kernel dan ikut mengawasi proses.
- Tidak ada injeksi, patch, atau modifikasi binary game yang dilakukan.
