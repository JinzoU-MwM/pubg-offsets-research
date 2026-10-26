# 01 — Target Inventory

## Host

| Item | Nilai | Bukti |
|---|---|---|
| Hostname | `DESKTOP-3IDCMF5` | `ssh muklis-laptop 'hostname'` |
| User | `desktop-m78f91m\user` (High Mandatory Level / elevated) | `whoami /groups` |
| OS | Windows 11 | `bcdedit /enum {current}` → `path \WINDOWS\system32\winload.efi` |
| Model | HP Victus by HP Gaming Laptop 16-s0xxx | `Win32_ComputerSystem` |
| CPU | AMD Ryzen 5 7640HS w/ Radeon 760M | `Win32_Processor` |
| RAM | 16.415.322.112 B (~15,3 GiB) | `Win32_ComputerSystem.TotalPhysicalMemory` |
| HypervisorPresent | True (`hypervisorlaunchtype Auto`) | `Win32_ComputerSystem` + `bcdedit` |
| VBS | `VirtualizationBasedSecurityStatus = 2`, `SecurityServicesRunning = {0}` | `Win32_DeviceGuard` |
| Test Signing | `No` | `bcdedit` |

## Instalasi game

| Item | Nilai |
|---|---|
| Steam library | `D:\SteamLibrary` (`appmanifest_578080.acf`) |
| Path game | `D:\SteamLibrary\steamapps\common\PUBG` |
| AppID / BuildID | `578080` / `26072644` |
| SizeOnDisk | `53.058.830.336` B (~49,4 GiB) |
| LastPlayed (sebelum riset) | `0` (belum pernah dijalankan) |
| Akun Steam login | `76561198331337073` (`dota2lol92`) |

## Binary inti (`TslGame\Binaries\Win64`)

| File | Ukuran (B) | SHA-256 |
|---|---|---|
| `TslGame.exe` | 237.399.936 | `2d80e1b49c2e7660cbd9ef1d236ee2486b7d5cc3320ebf9a5957a4b8f1e19853` |
| `TslGame_ZK.exe` | 48.058.696 | `106e4d40f34996f0a060b170e5c8f826216ff24574df4f0f32881596cf5515b3` |
| `TslGame_BE.exe` | 1.127.200 | `d9841a11885a25607f379e829be9c20e2c79800469c3f89e6cb515608b0568de` |
| `ExecPubg.exe` | 8.671.688 | `725590cfe05d13e6e0b8495c24c8c8fc45bfcb51a408454d84af2794b6b159e1` |

File lain yang relevan: `BattlEye\BEClient_x64.dll` (5.965.616 B),
`BattlEye\BEService_x64.exe` (18.991.400 B), `BattlEye\BELauncher.ini`
(`GameID=pubg`, `MasterPort=7827`), `TslGame_Hash.csv` (61.557 B — hanya hash pak/dll,
tanpa offset), `onnxruntime.dll`, `iigw\*`.

Tidak ada PDB/MAP/SYM yang dikirim bersama game (`Get-ChildItem -Include *.pdb,*.map,*.sym`
→ kosong).

## Komponen proteksi yang dipasang saat launch pertama

| Komponen | Path | Versi / Ukuran |
|---|---|---|
| Zakynthos service | `C:\Program Files\Common Files\PUBG\zksvc.exe` | `1.0.0.8`, KRAFTON, 23.295.816 B |
| Zakynthos driver | `C:\Program Files\Common Files\PUBG\navagio.sys` | 10.925.096 B, service kernel `navagio` (demand start) |
| Uninstaller | `C:\Program Files\Common Files\PUBG\uninstaller.exe` | 10.061.640 B |
| BattlEye service | `C:\Program Files (x86)\Common Files\BattlEye\BEService.exe` | dipasang lewat `TslGame_BE.exe 1 0` |

Catatan: `navagio` = nama pantai di Zakynthos → penamaan internal packer KRAFTON.
