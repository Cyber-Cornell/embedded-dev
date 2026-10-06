//! Puts the linker scripts (link64.ld, link32.ld) on the linker search path,
//! and relinks when they change.
fn main() {
    println!("cargo:rustc-link-search={}", env!("CARGO_MANIFEST_DIR"));
    println!("cargo:rerun-if-changed=link64.ld");
    println!("cargo:rerun-if-changed=link32.ld");
}
