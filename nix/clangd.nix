# clangd, clang-format and clang-tidy without nixpkgs' clang-tools wrapper.
# The wrapper injects the *host* glibc headers through CPATH, which shadow the
# newlib headers of a cross toolchain and cause bogus diagnostics. Unwrapped,
# clangd takes its system includes from the real compiler via --query-driver.
{ runCommand, llvmPackages }:

runCommand "clangd-unwrapped-${llvmPackages.clang-unwrapped.version}" { } ''
  mkdir -p $out/bin
  for tool in clangd clang-format clang-tidy; do
    ln -s ${llvmPackages.clang-unwrapped}/bin/$tool $out/bin/$tool
  done
''
