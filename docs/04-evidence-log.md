# 04 — Evidence Log (ringkas, kronologis)

Semua waktu lokal host (WIB). Perintah dijalankan dari workstation Linux.

## E1 — Konektivitas & host
```
$ ssh muklis-laptop 'hostname'
DESKTOP-3IDCMF5
$ ssh muklis-laptop 'powershell ... whoami'
desktop-m78f91m\user        # High Mandatory Level (elevated)
```

## E2 — Instalasi
```
D:\SteamLibrary\steamapps\appmanifest_578080.acf
  "name" "PUBG: BATTLEGROUNDS"  "buildid" "26072644"  "SizeOnDisk" "53058830336"
D:\SteamLibrary\steamapps\common\PUBG\TslGame\Binaries\Win64\
  TslGame.exe 237399936   TslGame_ZK.exe 48058696
  TslGame_BE.exe 1127200  ExecPubg.exe 8671688
```

## E3 — Transfer & hash
```
sha256(TslGame.exe)    = 2d80e1b49c2e7660cbd9ef1d236ee2486b7d5cc3320ebf9a5957a4b8f1e19853
sha256(TslGame_ZK.exe) = 106e4d40f34996f0a060b170e5c8f826216ff24574df4f0f32881596cf5515b3
scp -C: 237.399.936 B dalam 14,8 s
```

## E4 — Analisis statis
```
rz-bin -S TslGame.exe     -> 17 section (lihat docs/02)
entropy: .text 8.000 | .rdata 5.410 | .data 8.000 | .pubg0 7.993
EP RVA = 0x0
grep -a "++UE4+Release-4.16" -> offset 90422440
deflate/zlib/lzma/bz2 pada .text -> gagal semua
index of coincidence shift 1..1024 -> 0.00391 (datar)
capstone coverage sect_9 -> 24/20480 B
```

## E5 — Ekstraksi `.rdata`
```
unique UTF-16 strings (>=4): 123681
class-like: 16547
TslPlayerController 94 | TslCharacter 148 | PlayerState 371 | GameState 282
GWorld 0 | GNames 0 | GObjects 0 | ProcessEvent 0
```

## E6 — Launch pertama (`steam://rungameid/578080`)
```
NEW TslGame_ZK (pid 23004) -> spawn TslGame_ZK (21448) -> zksvc (13664) -> TslGame_BE
Get-Service BEService -> (tidak ada) ; TslGame.exe tidak muncul
```
Penyebab: BEService belum terpasang sehingga bootstrap BE menunggu.

## E7 — Pasang BattlEye
```
cd BattlEye; TslGame_BE.exe 1 0
sc query BEService -> STATE 1 STOPPED (terpasang)
sc start BEService -> STATE 4 RUNNING
sc query navagio   -> STATE 4 RUNNING (\??\C:\Program Files\Common Files\PUBG\navagio.sys)
```

## E8 — Launch kedua (berhasil sampai proses game)
```
t=60s TslGame 5656 (stub)
t=63s TslGame 7276 (game, WS 3,7 GB)
capture.log: FOUND pid=5656 ; BASE=0x0 ; RPM_FAIL err=5
```

## E9 — Uji akses per proses (lihat docs/03 §3.3)
```
pid=6848 BEService open=True rpm=True
pid=5656 TslGame   open=True rpm=True
pid=7276 TslGame   open=True rpm=GAGAL err=5   <-- blocker
pid=28188 zksvc    open=True rpm=True
```

## E10 — Dump
```
DumpAll 5656 -> OK regions=114 bytes=474279936
  image PE di offset dump 0x9ed000, ImageBase 0x7ff637ef0000, SizeOfImage 0x1b1eb000
  entropy .text dalam dump = 7.998  (masih terenkripsi)
DumpAll 7276 -> regions=28327 bytes=0 (semua read gagal)
```

## E11 — Artefak proteksi
```
C:\Program Files\Common Files\PUBG\zksvc.exe      23295816  v1.0.0.8 KRAFTON "Zakynthos Service"
C:\Program Files\Common Files\PUBG\navagio.sys    10925096  service kernel "navagio"
C:\Program Files (x86)\Common Files\BattlEye\BEService.exe  18991400
```
