# Global preferences

NEVER EVER write anything public (PR reply, ...) in my name without asking. EVER. Watch out or I'll switch to codex :P

## Sandbox
You are most probably in a bwrap sandbox
  - $HOME is this project's own persistent home, not the host's. ~/.cargo, ~/.rustup, ~/.npm and ~/.cache start empty. If a toolchain is missing, install it into $HOME (rustup, cargo install, npm, uv, ...). It stays between sessions and doesn't affect other projects or the host.
  - /usr, /etc and /opt are read-only host directories. You can't install system packages (no pacman/sudo). Ask me if something is only available that way.
  - /tmp is persistent and belongs to this project only.
  - Only the project path(s) are mounted from the host, plus ~/.claude and the other agent config dirs. Those are shared with the host, so don't change them unless I ask.
  - gh can be enabled per project. Ask me if you need it
  - You only see this sandbox's processes. There's no host systemd --user, D-Bus or /run/user. Network is on unless I disabled it.
  - GPU, KVM, X11 and Wayland are available only if enabled for this project; ask if you need them.

## Rust projects

- Before committing, always run: `cargo fmt` (use `cargo +nightly fmt` if the project requires nightly rustfmt features), `cargo clippy -- -W clippy::pedantic`, and `cargo test`
- Fix all warnings before committing

## All projects

- don't ammend commits unless I tell you to, it's ok to ask where it makes sense
- if you use TDD and use test vectors, make SURE they are correct or you just wire in wrong behaviour

## Environments

I have the following machines:

silence: i9 13900k with rx 6800, 64GB RAM (Arch/FreeBSD/macOS/windows)
bee: beelink EQR6 with AMD 6900HX APU, 20 GB RAM (Arch/windows)
fuji: fujitsu lifebook U937 with i5-7200U, 20 GB RAM (macOS/Arch)
air: M1 MBA 16GB RAM (macOS/asahi alarm)
eiger: M2 MBp 16GB RAM (macOS/asahi alarm)
m4: M4 max macbook pro, 64 GB RAM (macOS)
truenas: NAS custom built from Fujitsu D3402-B21 mainboard with i7 7700 CPU, 5 HDD in RAID-Z1, 2 SSD in mirror, nvme for OS (truenas)
yoga: lenovo slim 7x X1E, with 16GB RAM, linux and windows. right speaker is blown due to experimentation with audio software in linux. Replaced the speakers but still right channel dead. (Arch/Ubuntu/Windows)
imac: 2019 iMac (macOS/ubuntu)
oldnas: i5-6500 with GTX-1050 (Arch)
z400: HP z400 workstation with Xeon X5687 and RX 460, 20GB RAM (Arch)
vaio: Intel Pentium 3556U, Haswell (Q3 2013) GPU: integrated Intel HD Graphics for 4th-gen CPUs (Gen 7.5)
