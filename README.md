![version](https://img.shields.io/badge/version-18%2B-EB8E5F)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-addresses)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-addresses/total)

# 4d-plugin-addresses

The `addresses` plugin lists the machine's active (non-loopback) network interfaces and their IP addresses, using the OS's native adapter-enumeration API — `GetAdaptersAddresses` (IPHLPAPI) on Windows, `getifaddrs`/`SCNetworkConfiguration` on macOS. It exposes a single command that fills two parallel text arrays (addresses and their associated interface/adapter names) and takes no other input beyond an address-family filter.

| Command | Returns | Purpose |
|---|---|---|
| [IP ADDRESS LIST](#ip-address-list) | *(none — results via reference parameters)* | Lists IPv4/IPv6 addresses and their adapter/interface names, filtered by address family. |

**Platforms:** Windows, macOS

---

## Requirements & platform notes

- **No special runtime permissions are required on either platform.** The plugin uses the OS's standard adapter-enumeration APIs (`GetAdaptersAddresses`, `getifaddrs`), not a newer, privacy-gated local-network API.
- **All 3 parameters are mandatory.** The command reads all of them unconditionally — there's no optional/shorter form.
- **An invalid `family` value fails silently.** Passing anything other than `0`, `2`, or `23` returns both arrays at size 0 — 4D raises no error. See [Error handling & troubleshooting](#error-handling--troubleshooting) before you assume "empty result" always means "no interfaces found."
- **This reference describes the corrected plugin source** (a fix to how the Windows adapter name is retrieved). If you're running a build from before that fix, Windows adapter names may come back blank even though addresses are populated correctly.

---

## IP ADDRESS LIST

### Syntax

```4d
IP ADDRESS LIST ( addresses ; names ; family )
```

| Parameter | Type | Description |
|---|---|---|
| `addresses` | Text array (by reference) | Filled with each matching interface's IP address, in numeric string form (e.g. `192.168.1.10`, `fe80::1`). |
| `names` | Text array (by reference) | Filled with the adapter/interface name associated with each address in `addresses`, same index for index. See platform notes below — the name's format differs by platform and, on macOS, by address family. |
| `family` | Longint | Filters which address families to return. See the table below for valid values. Passed with reference syntax in the plugin's manifest, but the command only ever reads it — it never writes back to it, so a literal value works the same as a variable. |
| Result | — | This command has no return value; results are delivered entirely through `addresses` and `names`. |

`family` accepts:

| Value | Meaning |
|---|---|
| `0` | Both IPv4 and IPv6 |
| `2` | IPv4 only |
| `23` | IPv6 only |
| anything else | No addresses returned (both arrays come back empty; no 4D error is raised) |

### Description

Both `addresses` and `names` are **entirely replaced** on every call, not appended to — any prior contents are discarded, even if zero addresses match the filter (in which case both arrays come back at size 0).

Loopback interfaces are always excluded, on both platforms. Beyond that, the two platforms diverge in what counts as "active" and where the interface name comes from:

- **On Windows**, an address is included if it's flagged DNS-eligible by the OS. The adapter itself only needs to not be the loopback type — the code doesn't check whether the adapter is actually connected/up, so a disabled or disconnected adapter that still has a cached or statically-assigned address can appear in the results. The `names` value for both the IPv4 and IPv6 entries of a given adapter is the same OS-assigned friendly name (e.g. `Ethernet`, `Wi-Fi`).
- **On macOS**, an interface must have the `IFF_UP` flag set — disabled/disconnected interfaces are excluded outright, which is a stricter filter than Windows applies. The `names` value differs by address family for the *same* physical interface: IPv4 entries get the raw BSD interface name (e.g. `en0`); IPv6 entries attempt to resolve that interface's localized display name (e.g. `Wi-Fi`) and only fall back to the raw BSD name if that resolution fails. So don't assume a given interface's name string is identical across its IPv4 and IPv6 rows on macOS.

### Example

No sample/test `.4dm` file was provided with this plugin, so the examples below are illustrative, built only from standard, stable 4D language commands (array declaration, `For`, `Case of`) rather than quoted from a real test method.

Listing every address on the machine:

```4d
ARRAY TEXT($addresses;0)
ARRAY TEXT($names;0)

IP ADDRESS LIST($addresses;$names;0)  // 0 = both IPv4 and IPv6

For ($i;1;Size of array($addresses))
	ALERT($names{$i}+" : "+$addresses{$i})
End for 
```

Filtering to IPv4 only, and handling the "nothing found" case explicitly:

```4d
C_LONGINT($cAddressTypeIPv4)
$cAddressTypeIPv4:=2

ARRAY TEXT($ipv4Addresses;0)
ARRAY TEXT($ipv4Names;0)

IP ADDRESS LIST($ipv4Addresses;$ipv4Names;$cAddressTypeIPv4)

If (Size of array($ipv4Addresses)>0)
	ALERT("First IPv4 address: "+$ipv4Addresses{1}+" ("+$ipv4Names{1}+")")
Else 
	ALERT("No IPv4 addresses found")
End if 
```

---

## Error handling & troubleshooting

- **An invalid `family` value returns empty arrays, not an error.** Anything other than `0`, `2`, or `23` comes back as two size-0 arrays with no 4D error raised — check `Size of array` if you need to distinguish "bad filter value" from "genuinely no matching interfaces."
- **Arrays are fully replaced, not appended to, on every call** — including when zero matches are found. Don't rely on `addresses`/`names` retaining prior contents.
- **Windows and macOS name the same physical interface differently.** See the platform notes above — expect different formatting for the same interface across platforms, and (on macOS) even between that interface's IPv4 and IPv6 rows.
- **Windows doesn't check whether an adapter is actually connected.** A disabled or disconnected adapter with a cached/static address can still appear; macOS's `IFF_UP` check is stricter and excludes these.
- **Extremely rare: a stale, unchanged result on internal failure.** If gathering addresses fails internally (realistically, only under an out-of-memory condition), the command may leave `addresses`/`names` exactly as they were before the call, rather than clearing them or signaling a 4D error. If you're calling this repeatedly and reusing the same array variables, treat a result that never changes with some suspicion.
- **Blank Windows adapter names indicate a pre-fix build.** If addresses populate correctly but `names` is consistently empty on Windows, you're likely running a build from before the friendly-name retrieval fix — see the note at the top of this document.

---

## Quick reference

```4d
// All addresses
ARRAY TEXT($addresses;0)
ARRAY TEXT($names;0)
IP ADDRESS LIST($addresses;$names;0)

// IPv4 only
ARRAY TEXT($ipv4;0)
ARRAY TEXT($ipv4Names;0)
IP ADDRESS LIST($ipv4;$ipv4Names;2)

// IPv6 only
ARRAY TEXT($ipv6;0)
ARRAY TEXT($ipv6Names;0)
IP ADDRESS LIST($ipv6;$ipv6Names;23)
```
