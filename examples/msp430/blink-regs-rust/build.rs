//! Puts `memory.x` (for msp430-rt's `link.x`) and the standalone `msp430g2553_rt.ld`
//! on the linker search path, and relinks when they change.
use std::{env, fs, path::PathBuf};

fn main() {
    let out = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    for script in ["memory.x", "msp430g2553_rt.ld"] {
        fs::copy(script, out.join(script)).unwrap();
        println!("cargo:rerun-if-changed={script}");
    }
    println!("cargo:rustc-link-search={}", out.display());
}
