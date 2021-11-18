### CROSS RESTORE NOTES
THIS is experimental for now

- test chroot
```
mount -t proc proc /rescue/proc
mount -t sysfs sys /rescue/sys
mount -o bind /dev /rescue/dev
mount -t devpts pts /rescue/dev/pts
sudo grub2-mkconfig -o $GRUB_CONFIG
```
- test move system folders
```
find / -mindepth 1 -maxdepth 1 -regextype egrep ! -regex '/dev|/sys|/proc|/mnt|/vagrant.*'

## move current to /sysold
find / -mindepth 1 -maxdepth 1 -regextype egrep ! -regex '/run|/proc|/dev|/sys.*|/mnt|/media|/etc|/vagrant.*|/lost\+found' -exec mv -v {} /sysold/ \;
```

- test cross restore debian 11 to redhat 6
```
cp /usr/bin/find /usr/local/bin
cp -a /lib/x86_64-linux-gnu /usr/local/lib/
root@debian11:/# cat /etc/ld.so.conf.d/x86_64-linux-gnu.conf 
# Multiarch support
/usr/local/lib/x86_64-linux-gnu

ldconfig
ldd /usr/local/bin/find 
	linux-vdso.so.1 (0x00007ffe009f8000)
	libselinux.so.1 => /usr/local/lib/x86_64-linux-gnu/libselinux.so.1 (0x00007f342deb0000)
	libm.so.6 => /usr/local/lib/x86_64-linux-gnu/libm.so.6 (0x00007f342dd6c000)
	libc.so.6 => /usr/local/lib/x86_64-linux-gnu/libc.so.6 (0x00007f342dba7000)
	libpcre2-8.so.0 => /usr/local/lib/x86_64-linux-gnu/libpcre2-8.so.0 (0x00007f342db0f000)
	libdl.so.2 => /usr/local/lib/x86_64-linux-gnu/libdl.so.2 (0x00007f342db09000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f342df39000)
	libpthread.so.0 => /usr/local/lib/x86_64-linux-gnu/libpthread.so.0 (0x00007f342dae7000)

```

