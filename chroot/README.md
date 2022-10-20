## MKCHRO script
```
./chroot/mkchro.sh /path/to/dir user ["dproc"]
```
Create chroot directory for basic usage (busybox shell, no libraries, no other binaries). With dproc setup also proc,sys,dev.



## CHROOT for SSH access (busybox)

Config system, add group sshchroot for chrooters
```
cat >/etc/ssh/sshd_config.d/sshchroot.conf <<'EOF'
Match Group sshchroot
  ChrootDirectory %h/chroot

	Match All
EOF
groupadd sshchroot
systemctl restart sshd

#or for systems without sshd_config.d
vim /etc/ssh/sshd_config

Match Group sshchroot
  ChrootDirectory %h/chroot
```

Prepare a chroot for user backer
```
gpasswd -a backer sshchroot
mkdir -p /home/backer/chroot
./chroot/mkchro.sh /home/backer/chroot

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
