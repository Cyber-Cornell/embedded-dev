//! Puts `memory.x` (for cortex-m-rt's `link.x`) and the standalone `mspm0l2228.ld`
//! on the linker search path, and relinks when they change.
use std::{env, fs, path::PathBuf};

fn main() {
    let out = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    for script in ["memory.x", "mspm0l2228.ld"] {
        fs::copy(script, out.join(script)).unwrap();
        println!("cargo:rerun-if-changed={script}");
    }
    println!("cargo:rustc-link-search={}", out.display());
}
