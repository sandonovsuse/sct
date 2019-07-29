# SupportConfig Tool

A tool to perform essential operation on [supportconfigs][sct1], spanning from unpacking and splitting the archive, to running any of currently ported [YaST][sct2] module against its root file system.  

# Installation 

```sh
$ git clone https://github.com/sandonovsuse/sct.git
$ make install
```
# Usage

Navigate to directory containing supportconfigs and run:
```sh
$ (/usr/sbin)/yast sct
```

# Ported YaST modules

- [Sysconfig Editor][sct3]
- [Hosts file Editor][sct4]
- [Crowbar][sct5] 
- [Syslog][sct6]

# Prerequisites

- Write permission on a directory containing supportconfigs
- YaST 3.0

# Screenshots

![Image 1. Browse supportconfigs](https://github.com/sandonovsuse/sct/raw/master/screenshots/001.png)
![Image 2. Unpack supportconfig](https://github.com/sandonovsuse/sct/raw/master/screenshots/002.png)
![Image 3. YaST Crowbar](https://github.com/sandonovsuse/sct/raw/master/screenshots/005.png)
![Image 4. YaST Sysconfig](https://github.com/sandonovsuse/sct/raw/master/screenshots/006.png)
![Image 5. Syslog scan for errors](https://github.com/sandonovsuse/sct/raw/master/screenshots/007.png)
![Image 6. Syslog](https://github.com/sandonovsuse/sct/raw/master/screenshots/008.png)

   [sct1]: <https://en.opensuse.org/Supportutils>
   [sct2]: <https://en.opensuse.org/Portal:YaST>
   [sct3]: <https://github.com/yast/yast-sysconfig>
   [sct4]: <https://github.com/yast/yast-network>
   [sct5]: <https://github.com/yast/yast-crowbar>
   [sct6]: <https://github.com/yast/yast-yast2/blob/master/library/system/src/clients/view_anymsg.rb>

