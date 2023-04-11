# MONACT: Monitor & Action Daemon

Daemon that monitors a thing and executes a remediating action.

Features:
- Configurable and extendable
- Logs to syslog journald with tag "monact"
- Has a normal monitor interval SLEEP, and an error retry interval SLEEPERR,
- On the first error it goes to SOFT error state and retries NTRIES times (with SLEEPERR interval),
- After NTRIES of continuous errors, it goes to HARD error state and the remediating action is executed.
- The action is not executed again, if the state does not return to OK state.

## INSTALL 
```
./install.sh
cp /etc/monact/example.conf /etc/monact/<serviceid>.conf
# edit /etc/monact/<serviceid>.conf
# - define MONACT_CHECK=<checkid>
# - define MONACT_ACTION=<actionid>
# - define check variables from /usr/local/share/monact/<checkid>.check
# - define action variables from /usr/local/share/monact/<actionid>.act
systemctl daemon-reload
systemctl start monact@<serviceid>
systemctl enable monact@<serviceid>
journalctl -fu monact@<serviceid>
```

## CHECKS 
- diskerr.check: Checks that a device (derived from mountpoint) is still readable. This can be used for unstable interfaces (aka a usb disk that can glitch and suddently dissapear.
- web,check: Check that a web endpoint is alive, by checking status code.

## ACTIONS
- reboot.act: Reboots the system!
- log.act: Logs a line

## CUSTOM checks
Create files under /usr/local/share/monact/<checkid>.check which defines the function `monact_testit`. 
```
cp example.check.sh /usr/local/share/monact/<checkid>.check
monact_testit()
{
  curl  https://changeme | grep -q '"code":200}'
}
```
## CUSTOM actions
Create files under /usr/local/share/monact/<actionid>.act which defines the function `monact_testit`. E.g.
```
cp example.act.sh /usr/local/share/monact/<actionid>.act
monact_action()
{
  logger -t $TAG -p warn "Remedy action: something"
  something
}
```

## Configure check-mk LOGWATCH
Configure logwatch, 

```
edit __/etc/check_mk/logwatch.cfg__
```

AFTER BLOCK
```
 /var/log/syslog /var/log/kern.log
```

APPEND
```
 W monact: Error \(HARD\), giving up
```



