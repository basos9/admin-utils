## MKCHRO script
```
./chroot/mkchro.sh /path/to/dir user ["dproc"]
```
Create chroot directory for basic usage (busybox shell, no libraries, no other binaries). With dproc setup also proc,sys,dev.



## CHROOT for SSH access (busybox)
For backup script we run the busybox sh (no need for libraries)
```
mkdir -p /home/backer/chroot
./chroot/mkchrot.sh /home/backer/chroot
groupadd sshchroot
gpasswd -a backer sshchroot
vim /etc/ssh/sshd_config

Match Group sshchroot
  ChrootDirectory %h/chroot

```


## CHROOT to running system
```
mount -t proc proc /rescue/proc
mount -t sysfs sys /rescue/sys
mount -o bind /dev /rescue/dev
mount -t devpts pts /rescue/dev/pts
chroot /rescue
sudo grub2-mkconfig -o $GRUB_CONFIG
```
