# 02 — Analisis Statis Binary

## 2.1 PE header `TslGame.exe`

- Machine `0x8664`, 17 section, TimeDateStamp `1792475941`.
- ImageBase `0x140000000`, **AddressOfEntryPoint RVA `0x0`**.
- `SizeOfImage` (di memori) `0x1b1eb000`.
- EP = 0 → file **tidak bisa dieksekusi langsung oleh Windows loader**; harus dimap
  oleh loader ZK.

### Section layout (raw)

```
paddr      size       vaddr       vsize      perm  name
0x00000800 0x4658e00  0x140001000 0x102e3000 -r-x  .text
0x04659600 0x289ae00  0x1502e4000 0x28a0000  -r--  .rdata
0x06ef4400 0x100a00   0x152b84000 0xb56000   -rw-  .data
0x06ff4e00 0x596200   0x1536da000 0x5a0000   -r--  .pdata
0x0758b000 0x200      0x153c7a000 0x1000     -r--  .rodata
0x0758b200 0x3a00     0x153c7b000 0x14000    -r--  _RDATA
0x0758ec00 0x4f05c00  0x153c8f000 0x56d0000  -r-x  .pubg0      <- tambahan packer
0x0c494800 0x64a00    0x15935f000 0x65000    -r--  .rsrc
0x0c4f9200 0x200      0x1593c4000 0x1000     -r--  sect_8
0x0c4f9400 0xbfd000   0x1593c5000 0xbfd000   -r-x  sect_9      <- stub (12 MB)
0x0d0f6400 0x6de00    0x159fc2000 0x6e000    -r--  sect_10
0x0d164200 0xa600     0x15a030000 0xba000    -rw-  sect_11
0x0d16e800 0x200      0x15a0ea000 0x1000     -r--  sect_12
0x0d16ea00 0x303200   0x15a0eb000 0x304000   -r-x  sect_13
0x0d471c00 0x600000   0x15a3ef000 0x600000   -r--  sect_14
0x0da71c00 0x0        0x15a9ef000 0x9000     -rw-  ...
0x0da71c00 0x7f2400   ...                              (TYPE_NO_LOAD)
```

## 2.2 Entropy per section

| Section | Entropy | Interpretasi |
|---|---|---|
| `.text` | **8.000** | terenkripsi/terkompresi kuat |
| `.rdata` | 5.410 | **plaintext** |
| `.data` | **8.000** | terenkripsi |
| `.pubg0` | **7.993** | terenkripsi |
| `sect_9` | 6.445 | kode/stub (obfuscated) |
| `sect_10` | 5.819 | data/konstanta + string zlib |
| `sect_11` | 4.836 | data (termasuk string `XenuineX`) |
| `sect_13` | 6.200 | kode (obfuscated) |
| `sect_14` | 7.457 | data terenkripsi ringan |

## 2.3 `.rdata` plaintext → korpus UE4

- 123.681 string UTF-16 unik (≥4 karakter) berhasil diekstrak (lihat
  `data/rdata_utf16_strings.txt.gz`), 71.404 string ASCII ≥8 karakter.
- 16.547 di antaranya berbentuk nama kelas/properti (pola `[UAFTEI]Name`).
- Bukti engine: string `++UE4+Release-4.16` di file offset `90422440`
  (`0x563C0A8`), dan path build `D:\wk\cwd3b\build\UnrealEngine\Engine\Source\Runtime\...`.
- Nama kunci yang **ada** di `.rdata` (UTF-16 count): `TslPlayerController` 94,
  `TslCharacter` 148, `PlayerState` 371, `GameState` 282, `WeaponProcessor` 36,
  `CurrentWeapon` 22, `BoneMatrix` 6, `ComponentToWorld` 12, `RootComponent` 89,
  `Mesh` 2989, `LocalPlayer` 61, `PlayerCameraManager` 23, `ULevel` 16,
  `PersistentLevel` 5, `RelativeLocation` 41.
- Nama yang **tidak ada** (count 0): `GWorld`, `GNames`, `GObjects`,
  `GUObjectArray`, `ProcessEvent`, `FNamePool`, `OwningGameInstance`,
  `GroggyHealth` — konsisten dengan binary shipping yang di-strip simbol global.

## 2.4 Uji kompresi & kripto

| Uji | Hasil |
|---|---|
| Raw deflate (`.text` @0x800) | `error -3: invalid block type` |
| zlib | `incorrect header check` |
| LZMA / XZ / Zstd / bzip2 | signature tidak ditemukan / gagal decode |
| Index of coincidence (XOR repeating key) | datar `0.00391` pada semua shift 1–1024 → tidak ada XOR periodik |
| AES S-box | ada di `.rdata` @`0x4ed1c20`, `0x4edd120`, `0x4edd4c0` |
| AES-NI (`aesenc/aesdec/aeskeygenassist/pclmul`) | **0** kemunculan di seluruh file |
| Tabel CRC32 | `.rdata` @`0x4eba0c0`, `sect_13` @`0xd1399d0` |
| String zlib (`incorrect header check`, `unknown compression method`, `invalid window size`) | `.rdata` @`0x4eb8dc8` (milik UE4) dan `sect_10` @`0xd1387b8` (milik packer) |

Kesimpulan: enkripsi kunci-simetris penuh, bukan kompresi, bukan XOR sederhana.

## 2.5 Stub packer ter-obfuscate

Disassembly dengan Capstone (x86-64) pada 20 KB pertama tiap section kode:

| Section | Instruksi valid | Coverage |
|---|---|---|
| `sect_9` | 14 | 24 B / 20.480 B ≈ **0,00** |
| `sect_13` | 25 | 105 B / 20.480 B ≈ **0,01** |
| `.pubg0` | 4 | 10 B / 8.192 B ≈ 0,00 |

Pola yang terlihat: rantai `jmp`/`int3`/garbage (kelas VMProtect) → analisis statis
murni tidak produktif.

## 2.6 Binary lain

| File | Temuan |
|---|---|
| `TslGame_ZK.exe` | Section `.text/.rdata/.data` **SizeOfRawData = 0**; kode nyata hanya di `.zk2` (47 MB, high entropy). EP `0x2fecdfd` berada di `.zk2` (terenkripsi) → butuh bootstrapper eksternal. Import hanya 8 fungsi (VERSION, COMCTL32, KERNEL32, USER32, ADVAPI32, SHELL32, bcrypt, WS2_32) → API resolution dinamis. |
| `ExecPubg.exe` | 8,67 MB, EP `0xd55204` jatuh di section `001` yang high-entropy; byte di EP = sampah saat didisasm → juga terproteksi. |
| `TslGame_BE.exe` | 1,13 MB, **tidak** terproteksi (401 string). Import: `OpenSCManagerW`, `ShellExecuteExW`, `NtWaitForSingleObject`, `GetModuleFileNameW`, dll. `BELauncher.ini`: `64BitExe=TslGame.exe`, `SilentInstall=1`, `BasePort=7830`. |

## 2.7 Catatan reproduksi

Nilai entropy pada tabel 2.2 dihitung atas **seluruh** isi section. Script
`tools/analyze_binary.py` menghitung atas sampel maksimum 1 MiB per section agar
cepat, sehingga angkanya bisa sedikit berbeda (contoh `.rdata`: 5,410 penuh vs
4,683 sampel 1 MiB). Kesimpulan (terenkripsi vs plaintext) tidak berubah.
