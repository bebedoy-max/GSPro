@echo off
echo ===================================================
echo   AUTO-PUSH GUDANGAKUN NEBULA KE GITHUB REPOSITORY
echo ===================================================
git init
git add .
git commit -m "feat: full build GudangAkun Glassmorphism Nebula (#5)"
git branch -M main
git remote remove origin 2>nul
git remote add origin https://github.com/username-anda/gudang-akun-nebula.git
git push -u origin main
echo.
echo Selesai! Proyek berhasil di-push ke https://github.com/username-anda/gudang-akun-nebula.git
pause
