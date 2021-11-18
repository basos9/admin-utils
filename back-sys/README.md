## LIVE backup and restore

### BACKUP
- from system tar
  - backup with tar script   
```
./back-sys-full.sh -z bzip2 - | ssh -p 2221 user@remote.host 'cat > /mnt/data1/host-backup.tgz

```

which executes
```
tar c -p --ignore-failed-read \
        --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./mnt/*
        --exclude='./root/w' --exclude='./var/*img' \
        --exclude=./var/lib/backups --exclude='$DESTP' $@ -C / ."
```

### RESTORE
- mount tar archivemount is slow, use ratarmount
- install ratarmount
```
https://unix.stackexchange.com/questions/24032/faster-alternative-to-archivemount/501909
pip3 install --user ratarmount
```
- mount tar ratarmount
```
ratarmount  -o ro mars.tgz ma
```
- restore from tar mounted with ratarmount
```
### test
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

