# padavan-ng (Fork) #

> **Note:** This repository is a fork of the upstream [padavan-ng project by Sergey Hadzhioglu](https://gitlab.com/hadzhioglu/padavan-ng).
> It includes compilation and build fixes for modern Linux distributions with GCC 14/15, C23 compatibility fixes, and improved repository hygiene.

Welcome to the padavan-ng project

This project aims to improve the supported devices on the software part, allowing power users to take full control over their hardware.
This project was created in hope to be useful, but comes without warranty or support. Installing it will probably void your warranty.
Contributors of this project are not responsible for what happens next. Flash at your own risk!

### Contribution ###

Feel free to send in improvements/fixes. I'll keep the issue/pull request system open for that purpose.
NOTE: if and when a possible interesting change will get added depends on a verification/test of the particular change and if i have time to do it.

### Compilation Instructions ###

#### Verified Build Environment

This release was built, verified, and is **guaranteed to compile** on our reference build host:

- **Reference Host OS:** Ubuntu 26.04.1 LTS (Resolute Raccoon) x86_64, Linux kernel 7.0
- **Reference Host Compiler:** GCC **15.2.0** (`gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0`)
- **Reference Host Build Tools:** GNU Make 4.4.1, Autotools (autoconf 2.72, automake 1.17), kmod 32+, Python 3.12+
- **Cross-Compiler Toolchain:**
  - Generator: crosstool-NG (MIPS32)
  - Cross-Compiler: `mipsel-linux-uclibc-gcc` **7.5.0** (`toolchain/out/bin/mipsel-linux-uclibc-gcc`)
  - Target Architecture: MIPS32r2, Little-Endian (`mipsel`)
  - Target C Library: **uClibc-ng 1.0.52**
  - Target Kernel: Linux **3.4.113**

**Compatible / Closely Related Environments:**
Due to shared package ecosystems, modern glibc, and toolchain configurations, successful compilation is also expected on:
- **Ubuntu:** 24.04 LTS (Noble Numbat), 25.04, 22.04 LTS (Jammy Jellyfish)
- **Debian:** Debian 12 (Bookworm), Debian 13 (Trixie), Debian Testing
- Other modern GNU/Linux distributions with GCC 13/14/15 and GNU Make 4.3+ (requires `CT_EXTRA_CFLAGS_FOR_HOST="-O2 -std=gnu17"` for crosstool-NG on GCC 14/15 hosts, see Step 2).

#### 1. Install Dependencies

Ubuntu Desktop 22.04 LTS or newer is recommended. When building on modern Linux distributions (e.g. Ubuntu 24.04 / 25.04 / 26.04 with host GCC 14/15), standard C compatibility flags are required (see Step 2).

```shell
sudo apt update
sudo apt upgrade
sudo apt install -y autoconf autoconf-archive automake autopoint bison build-essential ca-certificates cmake cpio curl dos2unix doxygen fakeroot flex gawk gettext git gperf help2man htop kmod libarchive-tools libblkid-dev libc-ares-dev libcurl4-openssl-dev libdevmapper-dev libev-dev libevent-dev libexif-dev libflac-dev libgmp3-dev libid3tag0-dev libidn2-dev libjpeg-dev libkeyutils-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libogg-dev libsqlite3-dev libssl-dev libsystemd-dev libtool libtool-bin libudev-dev libunbound-dev libvorbis-dev libxml2-dev locales mc nano pkg-config ppp-dev python3 python3-docutils sshpass texinfo unzip uuid uuid-dev vim wget xxd zlib1g-dev
```

Automated build workflow reference: [Automatic Padavan firmware builds using GitHub servers](https://github.com/shvchk/padavan-builder-workflow).

#### 2. Build the Cross-Compiler Toolchain

> **IMPORTANT:** The cross-toolchain must be built **before** running the tree clean script (`./clear_tree.sh`) or building the firmware image. Otherwise, sub-makefiles will fail searching for `mipsel-linux-uclibc-gcc`.

```shell
cd toolchain
./build_toolchain.sh
```

*Note for modern build hosts with GCC 14 / GCC 15:*  
If the build fails during host GMP configuration (`too many arguments to function 'g'`), ensure the C standard compatibility flag is set in `toolchain/samples/mipsel-linux-uclibc/crosstool.config`:
```ini
CT_EXTRA_CFLAGS_FOR_HOST="-O2 -std=gnu17"
```

Once built, the cross-compiler will be located at:  
`toolchain/out/bin/mipsel-linux-uclibc-gcc`

#### 3. Board Configuration

Navigate to the `trunk` directory and set up the target board configuration `.config`:

```shell
cd ../trunk
# Copy the board template (e.g. Smart Box Pro with SPI flash mod):
cp configs/templates/smartbox_pro.config .config
```

Or configure manually in `.config`:
- `CONFIG_FIRMWARE_PRODUCT_ID="SMARTBOX_SPI"` (for Smart Box Pro with 16MB SPI flash mod)
- Common packages:
  - `CONFIG_FIRMWARE_INCLUDE_AMNEZIAWG=y`
  - `CONFIG_FIRMWARE_INCLUDE_NFQWS=y` (Zapret)
  - `CONFIG_FIRMWARE_INCLUDE_WIREGUARD=y`
  - `CONFIG_FIRMWARE_INCLUDE_IPSET=y`
  - `CONFIG_FIRMWARE_INCLUDE_STUBBY=y` / `CONFIG_FIRMWARE_INCLUDE_DOH=y`
  - `CONFIG_FIRMWARE_INCLUDE_SHORTCUT_FE=y` (Hardware / Fast Path NAT)
  - Disable bulky packages to conserve flash storage: `TRANSMISSION=n`, `ARIA=n`, `MINIDLNA=n`

#### 4. Clean Tree and Build Firmware

```shell
cd trunk
./clear_tree.sh
./build_firmware.sh
```

#### 5. Verify Firmware Image Size

The resulting firmware image will be placed in `trunk/images/`:

```shell
ls -lh images/*.trx
```

> **WARNING (Flash Memory Limit):**  
> For devices with 16 MB SPI flash (e.g. W25Q128 SPI mod), the final `.trx` image size must be **strictly less than 15.43 MB (16,187,392 bytes)**. A fully loaded build with anti-censorship packages typically measures ~9.5–12.5 MB.

#### 6. Flash Router via Web Interface

1. Open the router Web GUI (e.g. `http://192.168.1.1/` or `http://192.168.10.1/`).
2. Navigate to: **Administration** -> **Firmware Upgrade**.
3. Select the compiled `.trx` file and start the upgrade.
4. Wait for the router to reboot (~2–3 minutes). Existing NVRAM settings will be preserved.

### Firmware management ###
```shell 
Login details
IP: 192.168.1.1 or http://my.router
User: admin
Password: admin
WiFi name 2.4GHz: Padavan_2.4GHz
WiFi name 5GHz: Padavan_5GHz
WiFi Password 2.4/5GHz: 1234567890
```

# Support the Original Author #

To express gratitude and support Sergey Hadzhioglu's work:

ЮMoney wallet: 4100118647832050  
Link for quick replenishment: https://yoomoney.ru/to/4100118647832050  
ЮMoney Virtual Card: 5599 0020 6991 1404  
PrivatBank Virtual Card (UAH): 5169 3600 0910 4443  
PrivatBank Virtual Card (USD): 5169 3600 0910 4385  

Thank you very much for your support!  
*“I wish you all the best, and also Health! You give me the opportunity to live and breathe!”* © by Sergey Hadzhioglu

<a href="https://imgbb.com/"><img src="https://i.ibb.co/4KRbrfM/maxresdefault.jpg" alt="maxresdefault" border="0"></a>

# DISCLAIMER #
IMPORTANT NOTE!! PLEASE READ IT CAREFULLY!!
# NO WARRANTY OR SUPPORT
This product includes copyrighted third-party software licensed under the terms of the GNU General Public License. Please see The GNU General Public License for the exact terms
and conditions of this license. The firmware or any other product designed or produced by this project may contain in whole or in part pre-release, untested, or not fully tested works.
This may contain errors that could cause failures or loss of data, and may be incomplete or contain inaccuracies. You expressly acknowledge and agree that use of software or any part,
produced by this project, is at Your sole and entire risk.

ANY PRODUCT IS PROVIDED 'AS IS' AND WITHOUT WARRANTY, UPGRADES OR SUPPORT OF ANY KIND. ALL CONTRIBUTORS EXPRESSLY DISCLAIM ALL WARRANTIES AND/OR CONDITIONS, EXPRESS OR IMPLIED,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES AND/OR CONDITIONS OF SATISFACTORY QUALITY, OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY, OF QUIET ENJOYMENT, AND NONINFRINGEMENT
OF THIRD PARTY RIGHTS.
