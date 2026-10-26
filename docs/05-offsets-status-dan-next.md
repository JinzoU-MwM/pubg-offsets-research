# 05 — Status Offset & Jalur Lanjutan

## 5.1 Definisi "semua offset" untuk PUBG

Yang dimaksud offset di scene UE4/PUBG:

1. **Global engine**: `GWorld`, `GNames`/`FNamePool`, `GObjects`/`GUObjectArray`,
   `ProcessEvent`, `StaticFindObject`, `GEngine`.
2. **Chain objek**: `UWorld → PersistentLevel → Actors[]`, `GameState → PlayerArray`,
   `PlayerController → AcknowledgedPawn → RootComponent → ComponentToWorld`,
   `PlayerCameraManager` (view matrix), `LocalPlayer → PlayerController`.
3. **Struct member** per kelas (`TslCharacter`, `TslPlayerController`,
   `TslWeaponProcessor`, `TslVehicleRiderComponent`, dst.) — nilai offset properti.
4. **Fungsi**: alamat `ProcessEvent`, `GetBoneMatrix`, `LineOfSightTo`, dsb.

## 5.2 Status saat ini

| Komponen | Status | Bukti |
|---|---|---|
| Inventaris target | **SELESAI** | docs/01 |
| Peta proteksi statis | **SELESAI** | docs/02 |
| Launch chain runtime | **SELESAI** | docs/03, E6–E8 |
| Korpus nama UE4 (kelas/properti/fungsi) | **SELESAI** (statik, dari `.rdata` plaintext) | `data/rdata_utf16_strings.txt.gz` |
| Image terdekripsi (`.text`) | **BELUM** | PID 7276 memblokir `ReadProcessMemory` (err 5); PID 5656 masih terenkripsi |
| Global offset (GWorld/GNames/GObjects) | **BELUM** | butuh image terdekripsi |
| Member offset per kelas | **BELUM** | butuh image terdekripsi (tabel `PropPointers` di `.rdata` image) |

Alasan teknis: `.text`/`.data`/`.pubg0` terenkripsi di disk; dekripsi terjadi di
proses game yang dilindungi driver kernel `navagio` + BattlEye (handle read di-strip).
Dump modul dari proses stub hanya menghasilkan salinan yang masih terenkripsi.

## 5.3 Jalur lanjutan (berurut, dengan konsekuensi)

### A. Complete memory dump lewat bugcheck (rekomendasi opsec)
Ide: ambil snapshot RAM fisik saat game berjalan, tanpa driver pembaca yang bisa
dideteksi BattlEye.

1. `HKLM\SYSTEM\CurrentControlSet\Control\CrashControl`:
   `CrashDumpEnabled=1` (complete), `AutoReboot=1`, `Overwrite=1`.
2. Pastikan game berjalan sampai menu (image sudah terdekripsi, ±4 GB WS).
3. Trigger bugcheck (mis. proses dengan `RtlSetProcessIsCritical(TRUE)` lalu
   `TerminateProcess`, atau driver kecil yang memanggil `KeBugCheckEx`).
4. Setelah reboot: `C:\Windows\MEMORY.DMP` (±16 GB) berisi seluruh RAM.
5. Analisis dengan **Volatility 3** (`/usr/bin/vol`, v2.28.2 sudah tersedia di
   workstation): `windows.vadinfo`, `windows.memmap --pid <game> --dump`,
   `windows.dumpfiles --pid <game>` → rekonstruksi image + heap.
6. Simpan hanya image/region relevan (ratusan MB), bukan 16 GB.

Risiko: reboot paksa; perlu cek BitLocker sebelum eksekusi; game harus dijalankan
ulang setelah boot. Alternatif lebih murah: dump image saja dulu (cukup untuk
`PropPointers` + global), heap menyusul.

### B. Driver pembaca (BYOVD / kdmapper)
`C:\hwid-spoof\kdmapper` sudah ada di host. Driver kecil yang memakai
`KeStackAttachProcess` + `MmCopyVirtualMemory` bisa membaca PID 7276 dan menulis
dump image+heap ke disk.

Risiko: BattlEye mendeteksi pemetaan kdmapper/iqvw64e → **peluang ban tinggi**.
Hanya jika Presiden menerima risiko akun.

### C. Reverse `navagio.sys` / `zksvc.exe`
Driver 10,9 MB, service 23 MB; kemungkinan ada IOCTL baca memori atau jalur
dekripsi. Ini pekerjaan riset panjang (proteksi komersial ter-obfuscate), tapi
hasilnya bisa memberi dekripsi offline tanpa menyentuh proses game.

### D. Ekstraksi offline dari loader
Perlu membalik rutin dekripsi (AES software, tanpa AES-NI; stub ter-VM). Butuh
deobfuscator/emulasi (Unicorn) dan waktu signifikan. Bisa dikerjakan bertahap
setelah image runtime didapat, sebagai pembanding.

## 5.4 Yang bisa dipakai sekarang

Korpus nama dari `.rdata` (123.681 string unik) dapat langsung dipakai untuk:
- memetakan nama kelas/properti fungsi game (`Tsl*`, `WeaponProcessor`,
  `GroggyHealth`, `ComponentToWorld`, dst.),
- menyiapkan *schema* dump SDK (nama → offset diisi setelah image tersedia),
- memverifikasi hasil dump runtime (nama di dump harus cocok dengan korpus ini).

## 5.5 Bukti yang harus dipenuhi sebelum status berubah jadi SELESAI

- Image `TslGame.exe` hasil dekripsi dengan `.text` entropy ≈ 6,2 dan disassembly
  coverage > 0,9 → bukti dekripsi berhasil.
- Tabel `PropPointers`/`UClass` terbaca → daftar `nama:offset` per kelas.
- Offset global divalidasi (mis. `GWorld` menunjuk ke objek `UWorld` dengan vtable
  di `.rdata` image).
