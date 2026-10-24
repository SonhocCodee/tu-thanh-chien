@echo off
chcp 65001 >nul
cd /d %~dp0
echo ==================================================
echo  TU THANH CHIEN - MAY CHU NHA DANG KHOI DONG
echo ==================================================
echo.
echo  Dia chi IP LAN cua may nay (nhin dong IPv4 Address):
ipconfig | findstr /i "IPv4"
echo.
echo  Gui cho ban be CUNG MANG LAN (cung wifi) duong dan:
echo         http://IP-CUA-BAN:8911/?lan=1
echo  (thay IP-CUA-BAN bang so IPv4 o tren,
echo   vi du: http://192.168.1.8:8911/?lan=1)
echo.
echo  Ban (chu nha) muon choi cung thi mo trinh duyet tren
echo  chinh may nay toi:  http://localhost:8911/?lan=1
echo.
echo  Lan chay dau, Windows se hoi quyen tuong lua (Firewall)
echo  -^> tich mang "Private networks" roi bam "Allow access".
echo.
echo  Dung tat cua so nay giua tran - tat la tran dung.
echo ==================================================
echo.
echo  Dang mo may chu (cong 8910 + 8911)...
if exist "server\tu-thanh-chien-win.console.exe" (
  server\tu-thanh-chien-win.console.exe --headless -- --netrole=server --webroot="%CD%\web"
) else (
  server\tu-thanh-chien-win.exe --headless -- --netrole=server --webroot="%CD%\web"
)
echo.
echo  May chu da dung. Nhan phim bat ky de dong cua so.
pause >nul
