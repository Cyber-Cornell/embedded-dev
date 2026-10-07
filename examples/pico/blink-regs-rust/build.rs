//! Picks the chip from the target (thumbv6m: RP2040, thumbv8m.main: RP2350),
//! puts its `memory.x` (for cortex-m-rt's `link.x`) and the standalone
//! `rp2040.ld` / `rp2350.ld` on the linker search path, and sets `cfg(rp2350)`.
use std::{env, fs, path::PathBuf};

fn main() {
    let out = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let chip = if env::var("TARGET").unwrap().starts_with("thumbv8m") {
        "rp2350"
    } else {
        "rp2040"
    };
    fs::copy(format!("memory-{chip}.x"), out.join("memory.x")).unwrap();
    for script in [
        "memory-rp2040.x",
        "memory-rp2350.x",
        "rp2040.ld",
        "rp2350.ld",
    ] {
        if script.ends_with(".ld") {
            fs::copy(script, out.join(script)).unwrap();
        }
        println!("cargo::rerun-if-changed={script}");
    }
    println!("cargo::rustc-link-search={}", out.display());
    println!("cargo::rustc-check-cfg=cfg(rp2350)");
    if chip == "rp2350" {
        println!("cargo::rustc-cfg=rp2350");
    }
}
