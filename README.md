# 4d-plugin-addresses
List IP addresses of current host

Previous (v16 or earlier) available in [thread-unsafe](https://github.com/miyako/4d-plugin-addresses/tree/thread-unsafe) branch

### Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|

### Version

<img src="https://cloud.githubusercontent.com/assets/1725068/18940649/21945000-8645-11e6-86ed-4a0f800e5a73.png" width="32" height="32" /> <img src="https://cloud.githubusercontent.com/assets/1725068/18940648/2192ddba-8645-11e6-864d-6d5692d55717.png" width="32" height="32" /> <img src="https://user-images.githubusercontent.com/1725068/41266195-ddf767b2-6e30-11e8-9d6b-2adf6a9f57a5.png" width="32" height="32" />

![preemption xx](https://user-images.githubusercontent.com/1725068/41327179-4e839948-6efd-11e8-982b-a670d511e04f.png)

Multi version of [IT_MyTCPAddr](http://doc.4d.com/4Dv15/4D-Internet-Commands/15/IT-MyTCPAddr.301-2397945.en.html)

Software loopback network interfaces (``IF_TYPE_SOFTWARE_LOOPBACK``, ``IFF_LOOPBACK``) are excluded. 

Link-local IPv6 addresses (with a ``%`` suffix) are excluded on Windows (``IP_ADAPTER_ADDRESS_DNS_ELIGIBLE`` filter).

On macOS, the localised display name (``SCNetworkInterfaceGetLocalizedDisplayName``) or the BSD name (``ifaddrs.ifa_name``) is returned.

On WIndows, the friendly name (``IP_ADAPTER_ADDRESSES.FriendlyName``) is returned.

## Syntax

```
addresses:=IP Address list (family)
```

Parameter|Type|Description
------------|------------|----
family|LONGINT|
addresses|TEXT|``json``

![2](https://cloud.githubusercontent.com/assets/1725068/26295099/1ba062d4-3f03-11e7-9514-fb0eea1f7588.png)

![3](https://cloud.githubusercontent.com/assets/1725068/26295191/ae4baf26-3f03-11e7-93fe-08ca41e0e2c9.png)
