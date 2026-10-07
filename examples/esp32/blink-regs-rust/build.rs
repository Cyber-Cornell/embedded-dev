//! Puts the linker script (esp32.ld) on the linker search path, and relinks
//! when it changes.
fn main() {
    println!("cargo:rustc-link-search={}", env!("CARGO_MANIFEST_DIR"));
    println!("cargo:rerun-if-changed=esp32.ld");
}
