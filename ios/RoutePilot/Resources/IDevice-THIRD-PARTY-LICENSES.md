# Third-Party Licenses

`IDevice.xcframework` ([idevice](https://github.com/jkcoxson/idevice) v0.1.68), which LocSim links
into the app binary, is built from the Rust crate `idevice-ffi` and statically contains the crates
below. The list was resolved from the `Cargo.lock` of idevice v0.1.68 with `cargo tree` for the iOS
device target (default features plus `obfuscate`, TLS through aws-lc) and the Mac Catalyst target
(`ring` instead of aws-lc), excluding build-time-only dependencies and procedural macros. Licenses
are as published on crates.io.

Where a crate is offered under a choice of licenses, LocSim uses it under the license in the
*Used under* column.

## Crates

| Crate | Version | License | Used under |
| --- | --- | --- | --- |
| adler2 | 2.0.1 | 0BSD OR MIT OR Apache-2.0 | MIT |
| aead | 0.5.2 | MIT OR Apache-2.0 | MIT |
| aes | 0.8.4 | MIT OR Apache-2.0 | MIT |
| async-compression | 0.4.41 | MIT OR Apache-2.0 | MIT |
| async-stream | 0.3.6 | MIT | same |
| async_zip | 0.0.18 | MIT | same |
| aws-lc-rs | 1.16.2 | ISC AND (Apache-2.0 OR ISC) | same |
| aws-lc-sys | 0.39.0 | ISC AND (Apache-2.0 OR ISC) AND Apache-2.0 AND MIT AND BSD-3-Clause AND (Apache-2.0 OR ISC OR MIT) AND (Apache-2.0 OR ISC OR MIT-0) | same |
| base64 | 0.21.7 | MIT OR Apache-2.0 | MIT |
| base64 | 0.22.1 | MIT OR Apache-2.0 | MIT |
| base64ct | 1.8.3 | Apache-2.0 OR MIT | MIT |
| block-buffer | 0.10.4 | MIT OR Apache-2.0 | MIT |
| block-padding | 0.3.3 | MIT OR Apache-2.0 | MIT |
| bytes | 1.11.1 | MIT | same |
| cbc | 0.1.2 | MIT OR Apache-2.0 | MIT |
| cfg-if | 1.0.4 | MIT OR Apache-2.0 | MIT |
| chacha20 | 0.9.1 | Apache-2.0 OR MIT | MIT |
| chacha20 | 0.10.0 | MIT OR Apache-2.0 | MIT |
| chacha20poly1305 | 0.10.1 | Apache-2.0 OR MIT | MIT |
| chrono | 0.4.44 | MIT OR Apache-2.0 | MIT |
| cipher | 0.4.4 | MIT OR Apache-2.0 | MIT |
| compression-codecs | 0.4.37 | MIT OR Apache-2.0 | MIT |
| compression-core | 0.4.31 | MIT OR Apache-2.0 | MIT |
| const-oid | 0.9.6 | Apache-2.0 OR MIT | MIT |
| core-foundation-sys | 0.8.7 | MIT OR Apache-2.0 | MIT |
| cpufeatures | 0.2.17 | MIT OR Apache-2.0 | MIT |
| crc32fast | 1.5.0 | MIT OR Apache-2.0 | MIT |
| crossbeam-channel | 0.5.15 | MIT OR Apache-2.0 | MIT |
| crossbeam-utils | 0.8.21 | MIT OR Apache-2.0 | MIT |
| crypto-common | 0.1.7 | MIT OR Apache-2.0 | MIT |
| curve25519-dalek | 4.1.3 | BSD-3-Clause | same |
| der | 0.7.10 | Apache-2.0 OR MIT | MIT |
| deranged | 0.5.8 | MIT OR Apache-2.0 | MIT |
| digest | 0.10.7 | MIT OR Apache-2.0 | MIT |
| ed25519 | 2.2.3 | Apache-2.0 OR MIT | MIT |
| ed25519-dalek | 2.2.0 | BSD-3-Clause | same |
| equivalent | 1.0.2 | Apache-2.0 OR MIT | MIT |
| errno | 0.3.14 | MIT OR Apache-2.0 | MIT |
| fastrand | 2.3.0 | Apache-2.0 OR MIT | MIT |
| flagset | 0.4.7 | Apache-2.0 | same |
| flate2 | 1.1.9 | MIT OR Apache-2.0 | MIT |
| flume | 0.11.1 | Apache-2.0/MIT | MIT |
| futures | 0.3.32 | MIT OR Apache-2.0 | MIT |
| futures-channel | 0.3.32 | MIT OR Apache-2.0 | MIT |
| futures-core | 0.3.32 | MIT OR Apache-2.0 | MIT |
| futures-executor | 0.3.32 | MIT OR Apache-2.0 | MIT |
| futures-io | 0.3.32 | MIT OR Apache-2.0 | MIT |
| futures-lite | 2.6.1 | Apache-2.0 OR MIT | MIT |
| futures-sink | 0.3.32 | MIT OR Apache-2.0 | MIT |
| futures-task | 0.3.32 | MIT OR Apache-2.0 | MIT |
| futures-util | 0.3.32 | MIT OR Apache-2.0 | MIT |
| generic-array | 0.14.7 | MIT | same |
| getrandom | 0.2.17 | MIT OR Apache-2.0 | MIT |
| getrandom | 0.3.4 | MIT OR Apache-2.0 | MIT |
| getrandom | 0.4.2 | MIT OR Apache-2.0 | MIT |
| hashbrown | 0.16.1 | MIT OR Apache-2.0 | MIT |
| hkdf | 0.12.4 | MIT OR Apache-2.0 | MIT |
| hmac | 0.12.1 | MIT OR Apache-2.0 | MIT |
| iana-time-zone | 0.1.65 | MIT OR Apache-2.0 | MIT |
| idevice | 0.1.68 | MIT | same |
| idevice-ffi | 0.1.68 | MIT | same |
| idevice-srp | 0.6.0 | MIT OR Apache-2.0 | MIT |
| if-addrs | 0.15.0 | MIT OR BSD-3-Clause | MIT |
| indexmap | 2.13.0 | Apache-2.0 OR MIT | MIT |
| inout | 0.1.4 | MIT OR Apache-2.0 | MIT |
| itoa | 1.0.18 | MIT OR Apache-2.0 | MIT |
| jktcp | 0.1.7 | MIT | same |
| lazy_static | 1.5.0 | MIT OR Apache-2.0 | MIT |
| libc | 0.2.185 | MIT OR Apache-2.0 | MIT |
| libm | 0.2.16 | MIT | same |
| lock_api | 0.4.14 | MIT OR Apache-2.0 | MIT |
| log | 0.4.29 | MIT OR Apache-2.0 | MIT |
| matchers | 0.2.0 | MIT | same |
| md-5 | 0.10.6 | MIT OR Apache-2.0 | MIT |
| mdns-sd | 0.19.2 | Apache-2.0 OR MIT | MIT |
| memchr | 2.8.0 | Unlicense OR MIT | MIT |
| miniz_oxide | 0.8.9 | MIT OR Zlib OR Apache-2.0 | MIT |
| mio | 1.1.1 | MIT | same |
| ns-keyed-archive | 0.1.5 | MIT OR Apache-2.0 | MIT |
| nskeyedarchiver_converter | 0.1.3 | MIT OR Apache-2.0 | MIT |
| nu-ansi-term | 0.50.3 | MIT | same |
| num-bigint | 0.4.6 | MIT OR Apache-2.0 | MIT |
| num-bigint-dig | 0.8.6 | MIT/Apache-2.0 | MIT |
| num-conv | 0.2.1 | MIT OR Apache-2.0 | MIT |
| num-integer | 0.1.46 | MIT OR Apache-2.0 | MIT |
| num-iter | 0.1.45 | MIT OR Apache-2.0 | MIT |
| num-traits | 0.2.19 | MIT OR Apache-2.0 | MIT |
| obfstr | 0.4.4 | MIT | same |
| once_cell | 1.21.4 | MIT OR Apache-2.0 | MIT |
| opaque-debug | 0.3.1 | MIT OR Apache-2.0 | MIT |
| parking | 2.2.1 | Apache-2.0 OR MIT | MIT |
| parking_lot | 0.12.5 | MIT OR Apache-2.0 | MIT |
| parking_lot_core | 0.9.12 | MIT OR Apache-2.0 | MIT |
| pem-rfc7468 | 0.7.0 | Apache-2.0 OR MIT | MIT |
| pin-project | 1.1.11 | Apache-2.0 OR MIT | MIT |
| pin-project-lite | 0.2.17 | Apache-2.0 OR MIT | MIT |
| pkcs1 | 0.7.5 | Apache-2.0 OR MIT | MIT |
| pkcs8 | 0.10.2 | Apache-2.0 OR MIT | MIT |
| plist | 1.8.0 | MIT | same |
| plist-macro | 0.1.6 | MIT | same |
| plist_ffi | 0.1.6 | MIT | same |
| poly1305 | 0.8.0 | Apache-2.0 OR MIT | MIT |
| powerfmt | 0.2.0 | MIT OR Apache-2.0 | MIT |
| ppv-lite86 | 0.2.21 | MIT OR Apache-2.0 | MIT |
| quick-xml | 0.38.4 | MIT | same |
| rand | 0.8.5 | MIT OR Apache-2.0 | MIT |
| rand | 0.9.2 | MIT OR Apache-2.0 | MIT |
| rand | 0.10.0 | MIT OR Apache-2.0 | MIT |
| rand_chacha | 0.3.1 | MIT OR Apache-2.0 | MIT |
| rand_chacha | 0.9.0 | MIT OR Apache-2.0 | MIT |
| rand_core | 0.6.4 | MIT OR Apache-2.0 | MIT |
| rand_core | 0.9.5 | MIT OR Apache-2.0 | MIT |
| rand_core | 0.10.0 | MIT OR Apache-2.0 | MIT |
| regex-automata | 0.4.14 | MIT OR Apache-2.0 | MIT |
| regex-syntax | 0.8.10 | MIT OR Apache-2.0 | MIT |
| ring | 0.17.14 | Apache-2.0 AND ISC | same |
| rsa | 0.9.10 | MIT OR Apache-2.0 | MIT |
| rustls | 0.23.37 | Apache-2.0 OR ISC OR MIT | MIT |
| rustls-pki-types | 1.14.0 | MIT OR Apache-2.0 | MIT |
| rustls-webpki | 0.103.10 | ISC | same |
| scopeguard | 1.2.0 | MIT OR Apache-2.0 | MIT |
| serde | 1.0.228 | MIT OR Apache-2.0 | MIT |
| serde_core | 1.0.228 | MIT OR Apache-2.0 | MIT |
| serde_json | 1.0.149 | MIT OR Apache-2.0 | MIT |
| sha1 | 0.10.6 | MIT OR Apache-2.0 | MIT |
| sha2 | 0.10.9 | MIT OR Apache-2.0 | MIT |
| sharded-slab | 0.1.7 | MIT | same |
| signal-hook-registry | 1.4.8 | MIT OR Apache-2.0 | MIT |
| signature | 2.2.0 | Apache-2.0 OR MIT | MIT |
| simd-adler32 | 0.3.8 | MIT | same |
| siphasher | 1.0.2 | MIT/Apache-2.0 | MIT |
| slab | 0.4.12 | MIT | same |
| smallvec | 1.15.1 | MIT OR Apache-2.0 | MIT |
| socket-pktinfo | 0.3.2 | MIT | same |
| socket2 | 0.6.3 | MIT OR Apache-2.0 | MIT |
| spin | 0.9.8 | MIT | same |
| spki | 0.7.3 | Apache-2.0 OR MIT | MIT |
| subtle | 2.6.1 | BSD-3-Clause | same |
| thiserror | 2.0.18 | MIT OR Apache-2.0 | MIT |
| thread_local | 1.1.9 | MIT OR Apache-2.0 | MIT |
| time | 0.3.47 | MIT OR Apache-2.0 | MIT |
| time-core | 0.1.8 | MIT OR Apache-2.0 | MIT |
| tokio | 1.50.0 | MIT | same |
| tokio-rustls | 0.26.4 | MIT OR Apache-2.0 | MIT |
| tokio-util | 0.7.18 | MIT | same |
| tracing | 0.1.44 | MIT | same |
| tracing-appender | 0.2.4 | MIT | same |
| tracing-core | 0.1.36 | MIT | same |
| tracing-log | 0.2.0 | MIT | same |
| tracing-subscriber | 0.3.23 | MIT | same |
| typenum | 1.19.0 | MIT OR Apache-2.0 | MIT |
| universal-hash | 0.5.1 | MIT OR Apache-2.0 | MIT |
| untrusted | 0.9.0 | ISC | same |
| uuid | 1.23.3 | Apache-2.0 OR MIT | MIT |
| web-time | 1.1.0 | MIT OR Apache-2.0 | MIT |
| webpki-roots | 1.0.6 | CDLA-Permissive-2.0 | same |
| x25519-dalek | 2.0.1 | BSD-3-Clause | same |
| x509-cert | 0.2.5 | Apache-2.0 OR MIT | MIT |
| zerocopy | 0.8.47 | BSD-2-Clause OR Apache-2.0 OR MIT | MIT |
| zeroize | 1.8.2 | Apache-2.0 OR MIT | MIT |
| zmij | 1.0.21 | MIT | same |

## Copyright notices

Copyright lines from each crate's license files. Entries marked *(authors)* have no copyright line
in their license files; the `authors` field of the published crate is given instead. Crates listed
under [Crate-specific license files](#crate-specific-license-files) are not repeated here.

```
idevice, idevice-ffi 0.1.68
  Copyright 2026 Jackson Coxson
adler2 2.0.1
  Copyright (C) Jonas Schievink <jonasschievink@gmail.com>
aead 0.5.2
  Copyright (c) 2019 The RustCrypto Project Developers
  Copyright (c) 2019 MobileCoin, LLC
aes 0.8.4
  Copyright (c) 2018 Artyom Pavlov
async-compression 0.4.41
  Copyright (c) Wim Looman, Allen Bui (authors)
async-stream 0.3.6
  Copyright (c) 2019 Carl Lerche
  Copyright (c) 2018 David Tolnay
async_zip 0.0.18
  Copyright (c) 2021 Harry
  Copyright (c) 2023 Cognite AS
base64 0.21.7
  Copyright (c) 2015 Alice Maz
base64 0.22.1
  Copyright (c) 2015 Alice Maz
base64ct 1.8.3
  Copyright (c) 2014 Steve "Sc00bz" Thomas (steve at tobtu dot com)
  Copyright (c) 2021-2025 The RustCrypto Project Developers
block-buffer 0.10.4
  Copyright (c) 2018-2019 The RustCrypto Project Developers
block-padding 0.3.3
  Copyright (c) 2018-2019 The RustCrypto Project Developers
bytes 1.11.1
  Copyright (c) 2018 Carl Lerche
cbc 0.1.2
  Copyright (c) 2018-2022 RustCrypto Developers
  Copyright (c) 2018 Artyom Pavlov
cfg-if 1.0.4
  Copyright (c) 2014 Alex Crichton
chacha20 0.9.1
  Copyright (c) 2019-2023 The RustCrypto Project Developers
chacha20 0.10.0
  Copyright (c) 2019-2026 The RustCrypto Project Developers
chacha20poly1305 0.10.1
  Copyright (c) 2019 The RustCrypto Project Developers
chrono 0.4.44
  Copyright (c) 2014, Kang Seonghoon.
cipher 0.4.4
  Copyright (c) 2016-2020 RustCrypto Developers
compression-codecs 0.4.37
  Copyright (c) Wim Looman, Allen Bui (authors)
compression-core 0.4.31
  Copyright (c) Wim Looman, Allen Bui (authors)
const-oid 0.9.6
  Copyright (c) 2020-2022 The RustCrypto Project Developers
core-foundation-sys 0.8.7
  Copyright (c) 2012-2013 Mozilla Foundation
cpufeatures 0.2.17
  Copyright (c) 2020-2025 The RustCrypto Project Developers
crc32fast 1.5.0
  Copyright (c) 2018 Sam Rijs, Alex Crichton and contributors
crossbeam-channel 0.5.15
  Copyright (c) 2019 The Crossbeam Project Developers
  Copyright (c) 2009 The Go Authors. All rights reserved.
crossbeam-utils 0.8.21
  Copyright (c) 2019 The Crossbeam Project Developers
crypto-common 0.1.7
  Copyright (c) 2021 RustCrypto Developers
der 0.7.10
  Copyright (c) 2020-2023 The RustCrypto Project Developers
deranged 0.5.8
  Copyright (c) 2024 Jacob Pratt et al.
digest 0.10.7
  Copyright (c) 2017 Artyom Pavlov
ed25519 2.2.3
  Copyright (c) 2018-2023 RustCrypto Developers
equivalent 1.0.2
  Copyright (c) 2016--2023
errno 0.3.14
  Copyright (c) 2014 Chris Wong
fastrand 2.3.0
  Copyright (c) Stjepan Glavina (authors)
flagset 0.4.7
flate2 1.1.9
  Copyright (c) 2014-2026 Alex Crichton
flume 0.11.1
  Copyright (c) Joshua Barretto (authors)
futures 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-channel 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-core 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-executor 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-io 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-lite 2.6.1
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-sink 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-task 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
futures-util 0.3.32
  Copyright (c) 2016 Alex Crichton
  Copyright (c) 2017 The Tokio Authors
generic-array 0.14.7
  Copyright (c) 2015 Bartłomiej Kamiński
getrandom 0.2.17
  Copyright (c) 2018-2024 The rust-random Project Developers
  Copyright (c) 2014 The Rust Project Developers
getrandom 0.3.4
  Copyright (c) 2018-2025 The rust-random Project Developers
  Copyright (c) 2014 The Rust Project Developers
getrandom 0.4.2
  Copyright (c) 2018-2026 The rust-random Project Developers
  Copyright (c) 2014 The Rust Project Developers
hashbrown 0.16.1
  Copyright (c) 2016 Amanieu d'Antras
hkdf 0.12.4
  Copyright (c) 2015-2018 Vlad Filippov
  Copyright (c) 2018-2021 RustCrypto Developers
hmac 0.12.1
  Copyright (c) 2017 Artyom Pavlov
iana-time-zone 0.1.65
  Copyright (c) 2020 Andrew D. Straw
idevice-srp 0.6.0
  Copyright (c) 2017 Artyom Pavlov
if-addrs 0.15.0
  Copyright 2018 MaidSafe.net limited.
  Copyright 2020 messense
indexmap 2.13.0
  Copyright (c) 2016--2017
inout 0.1.4
  Copyright (c) 2022 The RustCrypto Project Developers
  Copyright (c) 2022 Artyom Pavlov
itoa 1.0.18
  Copyright (c) David Tolnay (authors)
jktcp 0.1.7
  Copyright (c) 2026 Jackson Coxson
lazy_static 1.5.0
  Copyright (c) 2010 The Rust Project Developers
libc 0.2.185
  Copyright (c) The Rust Project Developers
libm 0.2.16
  Copyright (c) 2018 Jorge Aparicio
lock_api 0.4.14
  Copyright (c) 2016 The Rust Project Developers
log 0.4.29
  Copyright (c) 2014 The Rust Project Developers
matchers 0.2.0
  Copyright (c) 2019 Eliza Weisman
md-5 0.10.6
  Copyright (c) 2006-2009 Graydon Hoare
  Copyright (c) 2009-2013 Mozilla Foundation
  Copyright (c) 2016 Artyom Pavlov
mdns-sd 0.19.2
  Copyright (c) 2021-2022, Han Xu, keepsimple@gmail.com
memchr 2.8.0
  Copyright (c) 2015 Andrew Gallant
miniz_oxide 0.8.9
  Copyright 2013-2014 RAD Game Tools and Valve Software
  Copyright 2010-2014 Rich Geldreich and Tenacious Software LLC
  Copyright (c) 2017 Frommi
  Copyright (c) 2017-2024 oyvindln
  Copyright (c) 2020 Frommi
mio 1.1.1
  Copyright (c) 2014 Carl Lerche and other MIO contributors
ns-keyed-archive 0.1.5
  Copyright (c) Jackson Coxson (authors)
nskeyedarchiver_converter 0.1.3
  Copyright (c) 2024 Michael Wright
nu-ansi-term 0.50.3
  Copyright (c) 2014 Benjamin Sago
  Copyright (c) 2021-2022 The Nushell Project Developers
num-bigint 0.4.6
  Copyright (c) 2014 The Rust Project Developers
num-bigint-dig 0.8.6
  Copyright (c) 2014 The Rust Project Developers
num-conv 0.2.1
  Copyright (c) Jacob Pratt
num-integer 0.1.46
  Copyright (c) 2014 The Rust Project Developers
num-iter 0.1.45
  Copyright (c) 2014 The Rust Project Developers
num-traits 0.2.19
  Copyright (c) 2014 The Rust Project Developers
obfstr 0.4.4
  Copyright (c) 2019-2020 Casper <CasualX@users.noreply.github.com>
once_cell 1.21.4
  Copyright (c) Aleksey Kladov (authors)
opaque-debug 0.3.1
  Copyright (c) 2018-2024 The RustCrypto Project Developers
parking 2.2.1
  Copyright 2014-2020 The Rust Project Developers
parking_lot 0.12.5
  Copyright (c) 2016 The Rust Project Developers
parking_lot_core 0.9.12
  Copyright (c) 2016 The Rust Project Developers
pem-rfc7468 0.7.0
  Copyright (c) 2021 The RustCrypto Project Developers
pin-project 1.1.11
  Copyright (c) the pin-project authors (authors)
pin-project-lite 0.2.17
  Copyright (c) the pin-project-lite authors (authors)
pkcs1 0.7.5
  Copyright (c) 2021-2023 The RustCrypto Project Developers
pkcs8 0.10.2
  Copyright (c) 2020-2023 The RustCrypto Project Developers
plist 1.8.0
  Copyright (c) 2015 Edward Barnard
plist-macro 0.1.6
  Copyright (c) Jackson Coxson (authors)
plist_ffi 0.1.6
  Copyright (c) Jackson Coxson (authors)
poly1305 0.8.0
  Copyright (c) 2015-2019 RustCrypto Developers
powerfmt 0.2.0
  Copyright (c) 2023 Jacob Pratt et al.
ppv-lite86 0.2.21
  Copyright (c) 2019 The CryptoCorrosion Contributors
quick-xml 0.38.4
  Copyright (c) 2016 Johann Tuffe
rand 0.8.5
  Copyright 2018 Developers of the Rand project
  Copyright (c) 2014 The Rust Project Developers
rand 0.9.2
  Copyright 2018 Developers of the Rand project
  Copyright (c) 2014 The Rust Project Developers
rand 0.10.0
  Copyright 2018 Developers of the Rand project
  Copyright (c) 2014 The Rust Project Developers
rand_chacha 0.3.1
  Copyright 2018 Developers of the Rand project
  Copyright (c) 2014 The Rust Project Developers
rand_chacha 0.9.0
  Copyright 2018 Developers of the Rand project
  Copyright (c) 2014 The Rust Project Developers
rand_core 0.6.4
  Copyright 2018 Developers of the Rand project
  Copyright (c) 2014 The Rust Project Developers
rand_core 0.9.5
  Copyright 2018 Developers of the Rand project
  Copyright (c) 2014 The Rust Project Developers
rand_core 0.10.0
  Copyright (c) 2018-2026 The Rand Project Developers
regex-automata 0.4.14
  Copyright (c) 2014 The Rust Project Developers
regex-syntax 0.8.10
  Copyright (c) 2014 The Rust Project Developers
rsa 0.9.10
  Copyright (c) RustCrypto Developers, dignifiedquire (authors)
rustls 0.23.37
  Copyright (c) 2016, Joseph Birr-Pixton <jpixton@gmail.com>
  Copyright (c) 2016 Joseph Birr-Pixton <jpixton@gmail.com>
rustls-pki-types 1.14.0
  Copyright (c) 2023 Dirkjan Ochtman <dirkjan@ochtman.nl>
scopeguard 1.2.0
  Copyright (c) 2016-2019 Ulrik Sverdrup "bluss" and scopeguard developers
serde 1.0.228
  Copyright (c) Erick Tryzelaar, David Tolnay (authors)
serde_core 1.0.228
  Copyright (c) Erick Tryzelaar, David Tolnay (authors)
serde_json 1.0.149
  Copyright (c) Erick Tryzelaar, David Tolnay (authors)
sha1 0.10.6
  Copyright (c) 2006-2009 Graydon Hoare
  Copyright (c) 2009-2013 Mozilla Foundation
  Copyright (c) 2016 Artyom Pavlov
sha2 0.10.9
  Copyright (c) 2006-2009 Graydon Hoare
  Copyright (c) 2009-2013 Mozilla Foundation
  Copyright (c) 2016 Artyom Pavlov
sharded-slab 0.1.7
  Copyright (c) 2019 Eliza Weisman
signal-hook-registry 1.4.8
  Copyright (c) 2017 tokio-jsonrpc developers
signature 2.2.0
  Copyright (c) 2018-2023 RustCrypto Developers
simd-adler32 0.3.8
  Copyright (c) [2021] [Marvin Countryman]
siphasher 1.0.2
  Copyright 2012-2016 The Rust Project Developers.
  Copyright 2016-2026 Frank Denis.
slab 0.4.12
  Copyright (c) 2019 Carl Lerche
smallvec 1.15.1
  Copyright (c) 2018 The Servo Project Developers
socket-pktinfo 0.3.2
  Copyright (c) 2025 Pixsper
socket2 0.6.3
  Copyright (c) 2014 Alex Crichton
spin 0.9.8
  Copyright (c) 2014 Mathijs van de Nes
spki 0.7.3
  Copyright (c) 2021-2023 The RustCrypto Project Developers
thiserror 2.0.18
  Copyright (c) David Tolnay (authors)
thread_local 1.1.9
  Copyright (c) 2016 The Rust Project Developers
time 0.3.47
  Copyright (c) Jacob Pratt et al.
time-core 0.1.8
  Copyright (c) Jacob Pratt et al.
tokio 1.50.0
  Copyright (c) Tokio Contributors
tokio-rustls 0.26.4
  Copyright (c) 2017 quininer kel
tokio-util 0.7.18
  Copyright (c) Tokio Contributors
tracing 0.1.44
  Copyright (c) 2019 Tokio Contributors
tracing-appender 0.2.4
  Copyright (c) 2019 Tokio Contributors
tracing-core 0.1.36
  Copyright (c) 2019 Tokio Contributors
tracing-log 0.2.0
  Copyright (c) 2019 Tokio Contributors
tracing-subscriber 0.3.23
  Copyright (c) 2019 Tokio Contributors
typenum 1.19.0
  Copyright (c) 2014 Paho Lurie-Gregg
universal-hash 0.5.1
  Copyright (c) 2019-2020 RustCrypto Developers
uuid 1.23.3
  Copyright (c) 2014 The Rust Project Developers
  Copyright (c) 2018 Ashley Mannix, Christopher Armstrong, Dylan DPC, Hunar Roop Kahlon
web-time 1.1.0
  Copyright (c) 2023 dAxpeDDa
x509-cert 0.2.5
  Copyright (c) 2021 The RustCrypto Project Developers
zerocopy 0.8.47
  Copyright 2019 The Fuchsia Authors.
  Copyright 2023 The Fuchsia Authors
zeroize 1.8.2
  Copyright (c) 2018-2021 The RustCrypto Project Developers
zmij 1.0.21
  Copyright (c) David Tolnay (authors)
```

## License texts

### MIT

Applies to the crates used under MIT, together with the copyright notices listed above.

````
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
USE OR OTHER DEALINGS IN THE SOFTWARE.
````

### Apache-2.0

````
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.

"License" shall mean the terms and conditions for use, reproduction, and distribution as defined by Sections 1 through 9 of this document.

"Licensor" shall mean the copyright owner or entity authorized by the copyright owner that is granting the License.

"Legal Entity" shall mean the union of the acting entity and all other entities that control, are controlled by, or are under common control with that entity. For the purposes of this definition, "control" means (i) the power, direct or indirect, to cause the direction or management of such entity, whether by contract or otherwise, or (ii) ownership of fifty percent (50%) or more of the outstanding shares, or (iii) beneficial ownership of such entity.

"You" (or "Your") shall mean an individual or Legal Entity exercising permissions granted by this License.

"Source" form shall mean the preferred form for making modifications, including but not limited to software source code, documentation source, and configuration files.

"Object" form shall mean any form resulting from mechanical transformation or translation of a Source form, including but not limited to compiled object code, generated documentation, and conversions to other media types.

"Work" shall mean the work of authorship, whether in Source or Object form, made available under the License, as indicated by a copyright notice that is included in or attached to the work (an example is provided in the Appendix below).

"Derivative Works" shall mean any work, whether in Source or Object form, that is based on (or derived from) the Work and for which the editorial revisions, annotations, elaborations, or other modifications represent, as a whole, an original work of authorship. For the purposes of this License, Derivative Works shall not include works that remain separable from, or merely link (or bind by name) to the interfaces of, the Work and Derivative Works thereof.

"Contribution" shall mean any work of authorship, including the original version of the Work and any modifications or additions to that Work or Derivative Works thereof, that is intentionally submitted to Licensor for inclusion in the Work by the copyright owner or by an individual or Legal Entity authorized to submit on behalf of the copyright owner. For the purposes of this definition, "submitted" means any form of electronic, verbal, or written communication sent to the Licensor or its representatives, including but not limited to communication on electronic mailing lists, source code control systems, and issue tracking systems that are managed by, or on behalf of, the Licensor for the purpose of discussing and improving the Work, but excluding communication that is conspicuously marked or otherwise designated in writing by the copyright owner as "Not a Contribution."

"Contributor" shall mean Licensor and any individual or Legal Entity on behalf of whom a Contribution has been received by Licensor and subsequently incorporated within the Work.

2. Grant of Copyright License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare Derivative Works of, publicly display, publicly perform, sublicense, and distribute the Work and such Derivative Works in Source or Object form.

3. Grant of Patent License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable (except as stated in this section) patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer the Work, where such license applies only to those patent claims licensable by such Contributor that are necessarily infringed by their Contribution(s) alone or by combination of their Contribution(s) with the Work to which such Contribution(s) was submitted. If You institute patent litigation against any entity (including a cross-claim or counterclaim in a lawsuit) alleging that the Work or a Contribution incorporated within the Work constitutes direct or contributory patent infringement, then any patent licenses granted to You under this License for that Work shall terminate as of the date such litigation is filed.

4. Redistribution. You may reproduce and distribute copies of the Work or Derivative Works thereof in any medium, with or without modifications, and in Source or Object form, provided that You meet the following conditions:

     (a) You must give any other recipients of the Work or Derivative Works a copy of this License; and

     (b) You must cause any modified files to carry prominent notices stating that You changed the files; and

     (c) You must retain, in the Source form of any Derivative Works that You distribute, all copyright, patent, trademark, and attribution notices from the Source form of the Work, excluding those notices that do not pertain to any part of the Derivative Works; and

     (d) If the Work includes a "NOTICE" text file as part of its distribution, then any Derivative Works that You distribute must include a readable copy of the attribution notices contained within such NOTICE file, excluding those notices that do not pertain to any part of the Derivative Works, in at least one of the following places: within a NOTICE text file distributed as part of the Derivative Works; within the Source form or documentation, if provided along with the Derivative Works; or, within a display generated by the Derivative Works, if and wherever such third-party notices normally appear. The contents of the NOTICE file are for informational purposes only and do not modify the License. You may add Your own attribution notices within Derivative Works that You distribute, alongside or as an addendum to the NOTICE text from the Work, provided that such additional attribution notices cannot be construed as modifying the License.

     You may add Your own copyright statement to Your modifications and may provide additional or different license terms and conditions for use, reproduction, or distribution of Your modifications, or for any such Derivative Works as a whole, provided Your use, reproduction, and distribution of the Work otherwise complies with the conditions stated in this License.

5. Submission of Contributions. Unless You explicitly state otherwise, any Contribution intentionally submitted for inclusion in the Work by You to the Licensor shall be under the terms and conditions of this License, without any additional terms or conditions. Notwithstanding the above, nothing herein shall supersede or modify the terms of any separate license agreement you may have executed with Licensor regarding such Contributions.

6. Trademarks. This License does not grant permission to use the trade names, trademarks, service marks, or product names of the Licensor, except as required for reasonable and customary use in describing the origin of the Work and reproducing the content of the NOTICE file.

7. Disclaimer of Warranty. Unless required by applicable law or agreed to in writing, Licensor provides the Work (and each Contributor provides its Contributions) on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely responsible for determining the appropriateness of using or redistributing the Work and assume any risks associated with Your exercise of permissions under this License.

8. Limitation of Liability. In no event and under no legal theory, whether in tort (including negligence), contract, or otherwise, unless required by applicable law (such as deliberate and grossly negligent acts) or agreed to in writing, shall any Contributor be liable to You for damages, including any direct, indirect, special, incidental, or consequential damages of any character arising as a result of this License or out of the use or inability to use the Work (including but not limited to damages for loss of goodwill, work stoppage, computer failure or malfunction, or any and all other commercial damages or losses), even if such Contributor has been advised of the possibility of such damages.

9. Accepting Warranty or Additional Liability. While redistributing the Work or Derivative Works thereof, You may choose to offer, and charge a fee for, acceptance of support, warranty, indemnity, or other liability obligations and/or rights consistent with this License. However, in accepting such obligations, You may act only on Your own behalf and on Your sole responsibility, not on behalf of any other Contributor, and only if You agree to indemnify, defend, and hold each Contributor harmless for any liability incurred by, or claims asserted against, such Contributor by reason of your accepting any such warranty or additional liability.

END OF TERMS AND CONDITIONS

APPENDIX: How to apply the Apache License to your work.

To apply the Apache License to your work, attach the following boilerplate notice, with the fields enclosed by brackets "[]" replaced with your own identifying information. (Don't include the brackets!)  The text should be enclosed in the appropriate comment syntax for the file format. We also recommend that a file or class name and description of purpose be included on the same "printed page" as the copyright notice for easier identification within third-party archives.

Copyright [yyyy] [name of copyright owner]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
````

### ISC

````
ISC License

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
````

### BSD-3-Clause

````
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
````

## Crate-specific license files

Reproduced from the published crates. These include their own copyright notices.

### aws-lc-sys 0.39.0 (AWS-LC): LICENSE

````
AWS Libcrypto (AWS-LC)

AWS-LC is a fork of BoringSSL, which is itself a fork of OpenSSL.
Content from these and other sources retains their original licensing,
as described below. New files from AWS-LC are made available under the Apache-2.0 license OR the ISC
license. These licenses are reproduced at the bottom of this file.

```
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 OR ISC
```


================================================================================
BoringSSL
================================================================================

BoringSSL is a Google-maintained fork of OpenSSL. Historically, code
authored by Google for BoringSSL was licensed under the ISC License.
BoringSSL has since relicensed upstream to Apache License 2.0. Existing
AWS-LC code originating from BoringSSL retains its ISC license, while
newer code taken from BoringSSL is licensed under Apache License 2.0.

```
Copyright (c) 2014-2024 Google Inc.
SPDX-License-Identifier: ISC
```

Additional individual contributions to BoringSSL-derived code are
covered under the ISC license:

  - Brian Smith (Copyright 2016)
  - Robert Nagy (Copyright 2022)
  - Arm Ltd (Copyright 2020)

```
Copyright (c) 2025-2026 Google Inc.
SPDX-License-Identifier: Apache-2.0
```

================================================================================
OpenSSL
================================================================================

Code derived from the OpenSSL project is licensed under the
Apache License, Version 2.0.

```
Copyright (c) 1998-2011 The OpenSSL Project. All rights reserved.
SPDX-License-Identifier: Apache-2.0
```

Some OpenSSL-derived files also carry the original SSLeay copyright:

```
Copyright (c) 1995-1998 Eric Young (eay@cryptsoft.com). All rights reserved.
SPDX-License-Identifier: Apache-2.0
```

Portions of OpenSSL-derived code include contributions from:

  - Sun Microsystems, Inc. (Copyright 2002)
  - Nokia (Copyright 2005)
  - Intel Corporation (Copyright 2012-2021)

These contributions are covered under the Apache-2.0 license.

================================================================================
mlkem-native
================================================================================

Code from the mlkem-native project is licensed under Apache License 2.0 or MIT or ISC.

```
Copyright (c) The mlkem-native project authors.
SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT
```

================================================================================
mldsa-native
================================================================================

Code from the mldsa-native project is licensed under Apache License 2.0 or MIT or ISC

```
Copyright (c) The mldsa-native project authors.
SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT
```

================================================================================
Third-Party Libraries (compiled into libcrypto/libssl)
================================================================================

Fiat Cryptography
-----------------
Synthesizing Correct-by-Construction Code for Cryptographic Primitives.
See third_party/fiat/LICENSE.

```
Copyright (c) 2015-2020 the fiat-crypto authors.
SPDX-License-Identifier: MIT
```

s2n-bignum
----------
Integer arithmetic routines for cryptography.
See third_party/s2n-bignum/s2n-bignum-imported/LICENSE.

```
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
```

Note: ML-KEM/SHA3 code within s2n-bignum is licensed as
Apache-2.0 OR ISC OR MIT (with attribution), sourced from the
mlkem-native project.

Jitter Entropy RNG
-------------------
CPU Jitter Random Number Generator Library.
See third_party/jitterentropy/jitterentropy-library/LICENSE.

The Jitter Entropy library is dual-licensed under a BSD-style license
and the GNU General Public License Version 2. Amazon expressly elects
to distribute the package under the 3-Clause BSD License and NOT under
GNU General Public License Version 2.

```
Copyright (C) 2017 - 2025, Stephan Mueller <smueller@chronox.de>.
SPDX-License-Identifier: BSD-3-Clause
```

Keccak / AES Reference Implementations
---------------------------------------
Public domain (CC0) contributions.
https://creativecommons.org/public-domain/cc0

Code from sources and by authors listed in comments on top of the respective files.


================================================================================
Third-Party Libraries (NOT compiled into libcrypto/libssl)
================================================================================

The following are used for testing and build tooling only. Distributing
code linked against AWS-LC (libcrypto/libssl) does NOT trigger these
license obligations.

Google Test
-----------
See third_party/googletest/LICENSE.

```
Copyright 2008 Google Inc.
SPDX-License-Identifier: BSD-3-Clause
```

Go Standard Library
-------------------
Code in ssl/test/runner/ is derived from the Go standard library.

```
Copyright (c) The Go Authors. All rights reserved.
SPDX-License-Identifier: BSD-3-Clause
```

Wycheproof Test Vectors
------------------------
Project Wycheproof is a community managed repository of test vectors that can be used by cryptography library
developers to test against known attacks, specification inconsistencies, and other various implementation bugs.

See third_party/wycheproof_testvectors/LICENSE.

```
SPDX-License-Identifier: Apache-2.0
```


================================================================================
Full License Texts
================================================================================

Apache License 2.0
------------------
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

    1. Definitions.

        "License" shall mean the terms and conditions for use, reproduction, and distribution as defined by Sections 1 through 9 of this document.

        "Licensor" shall mean the copyright owner or entity authorized by the copyright owner that is granting the License.

        "Legal Entity" shall mean the union of the acting entity and all other entities that control, are controlled by, or are under common control with that entity. For the purposes of this definition, "control" means (i) the power, direct or indirect, to cause the direction or management of such entity, whether by contract or otherwise, or (ii) ownership of fifty percent (50%) or more of the outstanding shares, or (iii) beneficial ownership of such entity.

        "You" (or "Your") shall mean an individual or Legal Entity exercising permissions granted by this License.

        "Source" form shall mean the preferred form for making modifications, including but not limited to software source code, documentation source, and configuration files.

        "Object" form shall mean any form resulting from mechanical transformation or translation of a Source form, including but not limited to compiled object code, generated documentation, and conversions to other media types.

        "Work" shall mean the work of authorship, whether in Source or Object form, made available under the License, as indicated by a copyright notice that is included in or attached to the work (an example is provided in the Appendix below).

        "Derivative Works" shall mean any work, whether in Source or Object form, that is based on (or derived from) the Work and for which the editorial revisions, annotations, elaborations, or other modifications represent, as a whole, an original work of authorship. For the purposes of this License, Derivative Works shall not include works that remain separable from, or merely link (or bind by name) to the interfaces of, the Work and Derivative Works thereof.

        "Contribution" shall mean any work of authorship, including the original version of the Work and any modifications or additions to that Work or Derivative Works thereof, that is intentionally submitted to Licensor for inclusion in the Work by the copyright owner or by an individual or Legal Entity authorized to submit on behalf of the copyright owner. For the purposes of this definition, "submitted" means any form of electronic, verbal, or written communication sent to the Licensor or its representatives, including but not limited to communication on electronic mailing lists, source code control systems, and issue tracking systems that are managed by, or on behalf of, the Licensor for the purpose of discussing and improving the Work, but excluding communication that is conspicuously marked or otherwise designated in writing by the copyright owner as "Not a Contribution."

        "Contributor" shall mean Licensor and any individual or Legal Entity on behalf of whom a Contribution has been received by Licensor and subsequently incorporated within the Work.
    2. Grant of Copyright License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare Derivative Works of, publicly display, publicly perform, sublicense, and distribute the Work and such Derivative Works in Source or Object form.
    3. Grant of Patent License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable (except as stated in this section) patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer the Work, where such license applies only to those patent claims licensable by such Contributor that are necessarily infringed by their Contribution(s) alone or by combination of their Contribution(s) with the Work to which such Contribution(s) was submitted. If You institute patent litigation against any entity (including a cross-claim or counterclaim in a lawsuit) alleging that the Work or a Contribution incorporated within the Work constitutes direct or contributory patent infringement, then any patent licenses granted to You under this License for that Work shall terminate as of the date such litigation is filed.
    4. Redistribution. You may reproduce and distribute copies of the Work or Derivative Works thereof in any medium, with or without modifications, and in Source or Object form, provided that You meet the following conditions:
        (a) You must give any other recipients of the Work or Derivative Works a copy of this License; and
        (b) You must cause any modified files to carry prominent notices stating that You changed the files; and
        (c) You must retain, in the Source form of any Derivative Works that You distribute, all copyright, patent, trademark, and attribution notices from the Source form of the Work, excluding those notices that do not pertain to any part of the Derivative Works; and
        (d) If the Work includes a "NOTICE" text file as part of its distribution, then any Derivative Works that You distribute must include a readable copy of the attribution notices contained within such NOTICE file, excluding those notices that do not pertain to any part of the Derivative Works, in at least one of the following places: within a NOTICE text file distributed as part of the Derivative Works; within the Source form or documentation, if provided along with the Derivative Works; or, within a display generated by the Derivative Works, if and wherever such third-party notices normally appear. The contents of the NOTICE file are for informational purposes only and do not modify the License. You may add Your own attribution notices within Derivative Works that You distribute, alongside or as an addendum to the NOTICE text from the Work, provided that such additional attribution notices cannot be construed as modifying the License.

    You may add Your own copyright statement to Your modifications and may provide additional or different license terms and conditions for use, reproduction, or distribution of Your modifications, or for any such Derivative Works as a whole, provided Your use, reproduction, and distribution of the Work otherwise complies with the conditions stated in this License.
    5. Submission of Contributions. Unless You explicitly state otherwise, any Contribution intentionally submitted for inclusion in the Work by You to the Licensor shall be under the terms and conditions of this License, without any additional terms or conditions. Notwithstanding the above, nothing herein shall supersede or modify the terms of any separate license agreement you may have executed with Licensor regarding such Contributions.
    6. Trademarks. This License does not grant permission to use the trade names, trademarks, service marks, or product names of the Licensor, except as required for reasonable and customary use in describing the origin of the Work and reproducing the content of the NOTICE file.
    7. Disclaimer of Warranty. Unless required by applicable law or agreed to in writing, Licensor provides the Work (and each Contributor provides its Contributions) on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely responsible for determining the appropriateness of using or redistributing the Work and assume any risks associated with Your exercise of permissions under this License.
    8. Limitation of Liability. In no event and under no legal theory, whether in tort (including negligence), contract, or otherwise, unless required by applicable law (such as deliberate and grossly negligent acts) or agreed to in writing, shall any Contributor be liable to You for damages, including any direct, indirect, special, incidental, or consequential damages of any character arising as a result of this License or out of the use or inability to use the Work (including but not limited to damages for loss of goodwill, work stoppage, computer failure or malfunction, or any and all other commercial damages or losses), even if such Contributor has been advised of the possibility of such damages.
    9. Accepting Warranty or Additional Liability. While redistributing the Work or Derivative Works thereof, You may choose to offer, and charge a fee for, acceptance of support, warranty, indemnity, or other liability obligations and/or rights consistent with this License. However, in accepting such obligations, You may act only on Your own behalf and on Your sole responsibility, not on behalf of any other Contributor, and only if You agree to indemnify, defend, and hold each Contributor harmless for any liability incurred by, or claims asserted against, such Contributor by reason of your accepting any such warranty or additional liability.

END OF TERMS AND CONDITIONS

APPENDIX: How to apply the Apache License to your work.

To apply the Apache License to your work, attach the following boilerplate notice, with the fields enclosed by brackets "[]" replaced with your own identifying information. (Don't include the brackets!) The text should be enclosed in the appropriate comment syntax for the file format. We also recommend that a file or class name and description of purpose be included on the same "printed page" as the copyright notice for easier identification within third-party archives.

Copyright [yyyy] [name of copyright owner]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

ISC License
-----------
Permission to use, copy, modify, and/or distribute this software for
any purpose with or without fee is hereby granted, provided that the
above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.

MIT License
-----------
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

BSD 3-Clause License
--------------------
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived
   from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

MIT No Attribution (MIT-0)
--------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
````

### aws-lc-rs 1.16.2: LICENSE, ISC part (the Apache-2.0 part is the text above)

````
ISC license
-------------------------------------


Copyright Amazon.com, Inc. or its affiliates.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
````

### ring 0.17.14: LICENSE

````
*ring* uses an "ISC" license, like BoringSSL used to use, for new code
files. See LICENSE-other-bits for the text of that license.

See LICENSE-BoringSSL for code that was sourced from BoringSSL under the
Apache 2.0 license. Some code that was sourced from BoringSSL under the ISC
license. In each case, the license info is at the top of the file.

See src/polyfill/once_cell/LICENSE-APACHE and src/polyfill/once_cell/LICENSE-MIT
for the license to code that was sourced from the once_cell project.
````

### ring 0.17.14: LICENSE-other-bits

````
Copyright 2015-2025 Brian Smith.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
````

`ring` also contains code from BoringSSL under Apache-2.0 (`LICENSE-BoringSSL`, the Apache-2.0
text above). The Go and Chromium licenses in that file cover test and build infrastructure that is
not compiled into the library.

### rustls-webpki 0.103.10: LICENSE

````
Except as otherwise noted, this project is licensed under the following
(ISC-style) terms:

Copyright 2015 Brian Smith.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

The files under third-party/chromium are licensed as described in
third-party/chromium/LICENSE.
````

### untrusted 0.9.0: LICENSE.txt

````
// Copyright 2015-2016 Brian Smith.
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
````

### curve25519-dalek 4.1.3: LICENSE

````
Copyright (c) 2016-2021 isis agora lovecruft. All rights reserved.
Copyright (c) 2016-2021 Henry de Valence. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

========================================================================

Portions of curve25519-dalek were originally derived from Adam Langley's
Go ed25519 implementation, found at <https://github.com/agl/ed25519/>,
under the following licence:

========================================================================

Copyright (c) 2012 The Go Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

   * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
   * Neither the name of Google Inc. nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
````

### ed25519-dalek 2.2.0: LICENSE

````
Copyright (c) 2017-2019 isis agora lovecruft. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
````

### x25519-dalek 2.0.1: LICENSE

````
Copyright (c) 2017-2021 isis agora lovecruft. All rights reserved.
Copyright (c) 2019-2021 DebugSteven. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
````

### subtle 2.6.1: LICENSE

````
Copyright (c) 2016-2017 Isis Agora Lovecruft, Henry de Valence. All rights reserved.
Copyright (c) 2016-2024 Isis Agora Lovecruft. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
````

### libm 0.2.16: LICENSE.txt, copyright section (the crate is MIT, text above)

````
This Rust library contains the following copyrights:

    Copyright (c) 2018 Jorge Aparicio

Portions of this software are derived from third-party works licensed under
terms compatible with the above MIT license:

* musl libc https://www.musl-libc.org/. This library contains the following
  copyright:

      Copyright © 2005-2020 Rich Felker, et al.

* The CORE-MATH project https://core-math.gitlabpages.inria.fr/. CORE-MATH
  routines are available under the MIT license on a per-file basis.

The musl libc COPYRIGHT file also includes the following notice relevant to
math portions of the library:

------------------------------------------------------------------------------
Much of the math library code (src/math/* and src/complex/*) is
Copyright © 1993,2004 Sun Microsystems or
Copyright © 2003-2011 David Schultz or
Copyright © 2003-2009 Steven G. Kargl or
Copyright © 2003-2009 Bruce D. Evans or
Copyright © 2008 Stephen L. Moshier or
Copyright © 2017-2018 Arm Limited
and labelled as such in comments in the individual source files. All
have been licensed under extremely permissive terms.
------------------------------------------------------------------------------

Copyright notices are retained in src/* files where relevant.
````

### crossbeam-channel 0.5.15: LICENSE-THIRD-PARTY, Go section

````
The Go Programming Language
https://golang.org/LICENSE

Copyright (c) 2009 The Go Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

   * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
   * Neither the name of Google Inc. nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
````

### webpki-roots 1.0.6: LICENSE

````
# Community Data License Agreement - Permissive - Version 2.0

This is the Community Data License Agreement - Permissive, Version
2.0 (the "agreement"). Data Provider(s) and Data Recipient(s) agree
as follows:

## 1. Provision of the Data

1.1. A Data Recipient may use, modify, and share the Data made
available by Data Provider(s) under this agreement if that Data
Recipient follows the terms of this agreement.

1.2. This agreement does not impose any restriction on a Data
Recipient's use, modification, or sharing of any portions of the
Data that are in the public domain or that may be used, modified,
or shared under any other legal exception or limitation.

## 2. Conditions for Sharing Data

2.1. A Data Recipient may share Data, with or without modifications, so
long as the Data Recipient makes available the text of this agreement
with the shared Data.

## 3. No Restrictions on Results

3.1. This agreement does not impose any restriction or obligations
with respect to the use, modification, or sharing of Results.

## 4. No Warranty; Limitation of Liability

4.1. All Data Recipients receive the Data subject to the following
terms:

THE DATA IS PROVIDED ON AN "AS IS" BASIS, WITHOUT REPRESENTATIONS,
WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED
INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF TITLE,
NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

NO DATA PROVIDER SHALL HAVE ANY LIABILITY FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING
WITHOUT LIMITATION LOST PROFITS), HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE DATA OR RESULTS,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

## 5. Definitions

5.1. "Data" means the material received by a Data Recipient under
this agreement.

5.2. "Data Provider" means any person who is the source of Data
provided under this agreement and in reliance on a Data Recipient's
agreement to its terms.

5.3. "Data Recipient" means any person who receives Data directly
or indirectly from a Data Provider and agrees to the terms of this
agreement.

5.4. "Results" means any outcome obtained by computational analysis
of Data, including for example machine learning models and models'
insights.
````
