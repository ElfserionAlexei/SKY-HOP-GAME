[README.md](https://github.com/user-attachments/files/35519601/README.md)
# Sky Hop

Game pantul vertikal untuk Godot 4.2 atau lebih baru. Semua gambar dan suara dibuat lewat kode, jadi tidak ada file aset.

## Cara main

- Kiri/kanan atau A/D untuk bergerak. Di layar sentuh atau dengan mouse, tahan dan geser ke arah yang kamu mau.
- Kamu memantul sendiri setiap menyentuh platform. Ambil koin, injak musuh dari atas.
- Pegas merah melontarkan kamu lebih tinggi. Platform cokelat muda hancur setelah diinjak.
- Jatuh atau tertabrak musuh mengurangi nyawa (hati). Kalau jatuh dan masih punya nyawa, kamu dapat **Bounce Back**: jaring karet melontarkan kamu kembali naik.
- Injak musuh beruntun tanpa menyentuh platform untuk kombo skor.
- P untuk jeda. Rekor tersimpan otomatis.

## Mengubah game

Semua ada di `main.gd`. Angka yang paling sering diubah ada di bagian atas file:

- `JUMP_V`, `SPRING_V`, `BOUNCE_BACK_V`: tinggi pantulan.
- `GRAV`: gravitasi.
- `MAX_LIVES`: jumlah nyawa.
- Fungsi `generate()`: kerapatan platform, musuh, dan koin.

## Font sendiri

Supaya tampilan teks lebih berkarakter, unduh font gratis (misalnya Lilita One atau Fredoka dari Google Fonts), lalu simpan sebagai `fonts/main.ttf`. Game akan memakainya otomatis.
