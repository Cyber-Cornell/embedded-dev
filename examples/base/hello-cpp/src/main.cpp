// Hello world for this computer. Build and run:
//   cmake --preset default && cmake --build build && ./build/hello [name]
#include <cstddef>
#include <iostream>
#include <span>
#include <string_view>

int main(int argc, char* argv[]) {
  const std::span args(argv, static_cast<std::size_t>(argc));
  const std::string_view name = args.size() > 1 ? args[1] : "world";
  std::cout << "Hello, " << name << "!\n";
  return 0;
}
