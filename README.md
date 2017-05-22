# 4d-plugin-addresses
List IP addresses of current host

### Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|

### Version

<img src="https://cloud.githubusercontent.com/assets/1725068/18940649/21945000-8645-11e6-86ed-4a0f800e5a73.png" width="32" height="32" /> <img src="https://cloud.githubusercontent.com/assets/1725068/18940648/2192ddba-8645-11e6-864d-6d5692d55717.png" width="32" height="32" />

Array version of [IT_MyTCPAddr](http://doc.4d.com/4Dv15/4D-Internet-Commands/15/IT-MyTCPAddr.301-2397945.en.html)

Software loopback network interfaces (``IF_TYPE_SOFTWARE_LOOPBACK``, ``IFF_LOOPBACK``) are excluded. 

Link-local IPv6 addresses (with a ``%`` suffix) are excluded on Windows (``IP_ADAPTER_ADDRESS_DNS_ELIGIBLE`` filter).

On macOS, the localised display name (``SCNetworkInterfaceGetLocalizedDisplayName``) or the BSD name (``ifaddrs.ifa_name``) is returned.

On WIndows, the friendly name (``IP_ADAPTER_ADDRESSES.FriendlyName``) is returned.

## Example 

```
IP ADDRESS LIST (addresses;names;AF_UNSPEC)
IP ADDRESS LIST (addresses;names;AF_INET)  //IPv4 only
IP ADDRESS LIST (addresses;names;AF_INET6)  //IPv6 only
```

![2](https://cloud.githubusercontent.com/assets/1725068/26295099/1ba062d4-3f03-11e7-9514-fb0eea1f7588.png)

## Syntax

```
IP ADDRESS LIST (addresses;family)
```

Parameter|Type|Description
------------|------------|----
addresses|ARRAY TEXT|
names|ARRAY TEXT|
family|LONGINT|
