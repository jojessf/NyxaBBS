WHAT DA HECC
============
This is a guide on using VICE to connect to BBS servs over TPC.  Assumes you have VICE installed somewhere and a linux box with a tcpser binary to bridge your virtual serial modem with the net.

Vice RS232 Conf
===============

![Vice RS232 Conf Example](maim.20260711.014416.231800459.1783748656_vice_rs232.png)

tcpser
------
I'm using a linux machine in this case, but windows or mac should do in a pinch.  Can be the same machine as your workstation, or just another host on your LAN.  Note that the LAN IP should be indicated in the VICE "RS232 devices" serial one field like {host}:25232, as in the screencap above

ccgms