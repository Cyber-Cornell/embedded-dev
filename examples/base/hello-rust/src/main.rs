//! Hello world for this computer. Build and run: `cargo run -- [name]`

fn greeting(name: Option<&str>) -> String {
    format!("Hello, {}!", name.unwrap_or("world"))
}

fn main() {
    let name = std::env::args().nth(1);
    println!("{}", greeting(name.as_deref()));
}

#[cfg(test)]
mod tests {
    use super::greeting;

    #[test]
    fn greets() {
        assert_eq!(greeting(None), "Hello, world!");
        assert_eq!(greeting(Some("eCTF")), "Hello, eCTF!");
    }
}
