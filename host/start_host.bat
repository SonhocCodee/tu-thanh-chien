@echo off
chcp 65001 >nul
cd /d %~dp0
echo ==================================================
echo  TU THANH CHIEN - MAY CHU NHA DANG KHOI DONG
echo ==================================================
echo.
echo  Dia chi IP LAN cua may nay (tim dong IPv4 Address):
ipconfig | findstr /i "IPv4"
echo.
echo  Gui cho ban be cung mang LAN duong dan:
echo         http://IP-CUA-BAN:8911/?lan=1
echo  (thay IP-CUA-BAN bang so IPv4 o tren)
echo.
echo  Ban (chu nha) choi cung: mo trinh duyet tren chinh may
echo  nay toi:  http://localhost:8911/?lan=1
echo.
echo  Lan chay dau Windows se hoi quyen tuong lua
echo  -^> bam "Allow access" / Cho phep (mang Private).
echo  Dung tat cua so nay giua tran - tat la tran dung.
echo ==================================================
server\tu-thanh-chien.exe --headless -- --netrole=server --webroot="%CD%\web"
pause
