#### Setup serveo proxy access in Putty
* Enter serveo alias as hostname in Putty.
![putty1](img/putty1.png)
* Enter login username in `Connection > Data`
![putty2](img/putty2.png)
* Tick `Allow agent forewarding` in `Connection > SSH > Auth`
![putty3](img/putty3.png)
* Select proxy type `local` in `Connection > Proxy`
* Enter proxy hostname`serveo.net` and port `22` in `Connection > Proxy`
* Enter login username in `Connection > Proxy`
* Enter telnet command / local proxy command `plink %user@%proxyhost:%proxyport -nc %host:%port` in `Connection > Proxy`
![putty4](img/putty4.png)
