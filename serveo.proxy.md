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


#### Setup serveo proxy access in ConnectBot
* Add a host with `root@serveo.net`

![connectbot1](img/connectbot1.png)
* Untick `Start shell session` and save.

![connectbot2](img/connectbot2.png)
* Long tap on the newly created host and select `Edit port forwards`

![connectbot3](img/connectbot3.png)
* Add a port forward with Type `local`, Source port `2222` and destination `serveo_alias:22` where `serveo_alias` is the alias given to serveo connection. Then click create port forward.

![connectbot4](img/connectbot4.png)
* Add a new host with `username@localhost:2222` where `username` is the login username.

![connectbot5](img/connectbot5.png)
* Now connect to the first host and leave the connection unclosed.
* Connect to the second host and you should have a login shell.
