# 4d-plugin-addresses
List IP addresses of current host

### Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|

### Version

<img src="https://cloud.githubusercontent.com/assets/1725068/18940649/21945000-8645-11e6-86ed-4a0f800e5a73.png" width="32" height="32" /> <img src="https://cloud.githubusercontent.com/assets/1725068/18940648/2192ddba-8645-11e6-864d-6d5692d55717.png" width="32" height="32" />

Array version of [IT_MyTCPAddr](http://doc.4d.com/4Dv15/4D-Internet-Commands/15/IT-MyTCPAddr.301-2397945.en.html)

## Example 

```
IP ADDRESS LIST ($addresses;AF_UNSPEC)
IP ADDRESS LIST ($addresses;AF_INET)  //IPv4 only
IP ADDRESS LIST ($addresses;AF_INET6)  //IPv6 only
```

![1](https://cloud.githubusercontent.com/assets/1725068/26291496/9e030db8-3ee9-11e7-9bba-647183ba03c2.png)

## Syntax

```
IP ADDRESS LIST (addresses;family)
```

Parameter|Type|Description
------------|------------|----
addresses|ARRAY TEXT|
family|LONGINT|
