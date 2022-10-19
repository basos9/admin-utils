## LIVE backup and restore

### BACKUP
Create running system tar
- backup system to local tar
```
## backup to local directory (user backer or specified by -u)
back-sys/back-sys-full.sh /var/backups/system
```
- backup system to remote ssh
```
## backup to remote ssh
back-sys/back-sys-full.sh -r ssh://user@remote:port /
```
- backup system to pipe
```
## backup to pipe
back-sys/back-sys-full.sh -z bzip2 - | ssh -p 2221 user@remote.host 'cat > /mnt/data1/host-backup.tgz
```
- reverse remote backup
```
## backup reverse
ssh root@mars -p 1081 -o ExitOnForwardFailure=yes -R 1221:127.0.0.1:22 admin-utils/back-sys/back-sys-full.sh -z bzip2 -r ssh://backer@localhost:1221 sys-auto
```
  - connect to remote system (to be backed) mars user root with ssh at port 1081
  - setup a reverse tunnel from mars to localhost via mars port 1221 (ensure fail on port forwarding fail)
  - start the backup from remote root home admin-utils/back-sys/back-sys-full.sh backup to localhost user `backer` directory mars-auto
  - as a bonus setup `backer` user as a chrooted user @see README-chroot / CHROOT for SSH access (busybox) `gpasswd -a backer sshchroot`
```
# Mount directory to chroot
mkdir /home/backer/chroot/home/backer/sys-auto
vim /etc/fstab
/var/backups/mars /home/backer/chroot/home/backer/sys-auto none bind 0 0
```

which executes
```
tar c -p --ignore-failed-read \
        --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./mnt/*
        --exclude='./root/w' --exclude='./var/*img' \
        --exclude=./var/lib/backups --exclude='$DESTP' $@ -C / ."
```



### RESTORE


#### TAR PLAN 1: EXTRACT
Extract with root
```
sudo tar xjf mars.tbz -C mars
```

#### TAR PLAN 2: MOUNT
- mount tar archivemount is slow
- mount tar  use ratarmount, minimum version 0.9.2, as earlier versions do not preserve permissions

- install ratarmount
```
https://unix.stackexchange.com/questions/24032/faster-alternative-to-archivemount/501909
pip3 install --user ratarmount
# or to force install from upstream
python3 -m pip install --user --force-reinstall git+https://github.com/mxmlnkn/ratarmount.git@v0.9.2
```
- mount tar ratarmount
```
ratarmount  -o ro mars.tgz ma
# use parallel processors for bzip2
ratarmount  -o ro -P 6 mars.tbz ma
# allow other users (and root) to read root files
ratarmount -o ro,allow_other mars.tgz ma
```


### restore from tar 
Tar extracted or mounted to directory ma
```
### test (dry run)
./res-sys.sh -v -d -S ma root@10.0.20.39 / 2>&1 | tee res-host-deb11.log

## DO
./res-sys.sh -c -v -d -S ma root@10.0.20.39 / 2>&1 | tee res-host-deb11.log

```

which executes finally
```
rsync --super -aSDz --exclude '/sys*' --exclude /proc/ --exclude /dev/ --exclude /mnt/ --exclude /etc/fstab --exclude /etc/network/interfaces --exclude '/etc/sysconfing/network-scripts*' -e 'ssh -p 22' mp// root@10.0.20.59:/
```

also we keep some files (like /etc/) in /sysold and we also sync new files in /sysnew

Things to consider afterwards
- grub install and update-grub
- fstab
- networking

### Usefull commands
- list tar contents
```
tar tvf mars.tar 
```

