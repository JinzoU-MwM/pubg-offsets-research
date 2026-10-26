# Artefak besar (GitHub Release)

Binary game + memory dump **tidak** di-commit ke git (batas 100 MB/blob). Semua
artefak besar menempel di release GitHub repo ini, supaya riset bisa dilanjutkan
di laptop lain.

| Asset | Ukuran (B) | Isi |
|---|---|---|
| `TslGame.exe` | 237.399.936 | binary game asli (terenkripsi `.text/.data/.pubg0`, `.rdata` plaintext) |
| `TslGame_ZK.exe` | 48.058.696 | loader Zakynthos (section `.zk0–.zk2`) |
| `TslGame_BE.exe` | 1.127.200 | bootstrap BattlEye (plain) |
| `ExecPubg.exe` | 8.671.688 | launcher (terproteksi) |
| `all_5656.bin` | 454.609.920 | dump region proses TslGame.exe stub (PID 5656) + manifest |
| `all_28188_zksvc.bin` | ~54.284.288 | dump region proses `zksvc.exe` (PID 28188) + manifest — **belum terunggah** (host offline saat upload) |

Untuk tiap dump, file `*.manifest.json` menyertakan `base`, `size`, `protect`,
`file_off` tiap region → bisa direkonstruksi kembali ke virtual address.

## Cara ambil di laptop lain

```bash
# butuh gh yang sudah login ke akun pemilik repo
gh release download v1.0-artifacts \
  --repo JinzoU-MwM/pubg-offsets-research \
  --dir ./artifacts

# verifikasi
cd ./artifacts && sha256sum -c SHA256SUMS.txt
```

Atau lewat script: `bash tools/fetch_artifacts.sh [dir]`.
