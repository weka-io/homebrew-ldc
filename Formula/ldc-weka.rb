class LdcWeka < Formula
  desc "Portable D programming language compiler - fork for Weka.IO"
  homepage "https://wiki.dlang.org/LDC"
  url "https://github.com/weka/ldc.git", tag: "v1.24.0-weka3", revision: "53bad14845f2aab47a67908377c11ac5d93de72e"
  version "1.24.0-weka3.1"
  license "BSD-3-Clause"
  head "https://github.com/weka-io/ldc.git", :shallow => false, :branch => "weka-master"

  conflicts_with "ldc", :because => "this is a patched ldc"
  version_scheme 2

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/weka/ldc/releases/download/v1.24.0-weka3"
    sha256 big_sur: "7c6f1bd6463b70e925a6ed19378fb6fc0789b5b6220cc72305db89c78888f768"
    sha256 arm64_big_sur: "3165ee960954f5b198e31c63c67025ec46fd98c43d7d782117adecd77ffa3a4b"
  end

  depends_on "cmake" => :build
  depends_on "libconfig" => :build
  depends_on "pkg-config" => :build
  depends_on "llvm@11"

  uses_from_macos "libxml2" => :build

  resource "ldc-bootstrap" do
    on_macos do
      if Hardware::CPU.intel?
        url "https://github.com/ldc-developers/ldc/releases/download/v1.26.0/ldc2-1.26.0-osx-x86_64.tar.xz"
        sha256 "b5af4e96b70b094711659b27a93406572cbd4ecf7003c1c84445c55c739c06a1"
      else
        url "https://github.com/ldc-developers/ldc/releases/download/v1.26.0/ldc2-1.26.0-osx-arm64.tar.xz"
        sha256 "303930754c819d0f88434813a82122196bf3fe76ea5bd1b0f16d100b540100e6"
      end
    end

    on_linux do
      url "https://github.com/ldc-developers/ldc/releases/download/v1.26.0/ldc2-1.26.0-linux-x86_64.tar.xz"
      sha256 "06063a92ab2d6c6eebc10a4a9ed4bef3d0214abc9e314e0cd0546ee0b71b341e"
    end
  end


  # Add support for building against LLVM 11.1
  # This is already merged upstream via https://github.com/ldc-developers/druntime/pull/195
  # but it needs adjustments to apply against 1.24.0 tarball
  patch :DATA

  def install
    ENV.cxx11
    (buildpath/"ldc-bootstrap").install resource("ldc-bootstrap")

    profdata_path = "#{buildpath}/instr_profiles/weka1.24-10nov2020.profdata"
    dmd_with_pgo = "#{buildpath}/ldc-bootstrap/bin/ldmd2 -fprofile-instr-use=#{profdata_path}"
    mkdir "build" do
      args = std_cmake_args + %W[
        -DLLVM_ROOT_DIR=#{Formula["llvm@11"].opt_prefix}
        -DINCLUDE_INSTALL_DIR=#{include}/dlang/ldc
        -DD_COMPILER=#{dmd_with_pgo}
      ]

      system "cmake", "..", *args
      system "make"
      system "make", "install"

      on_macos do
        # Workaround for https://github.com/ldc-developers/ldc/issues/3670
        cp Formula["llvm"].opt_lib/"libLLVM.dylib", lib/"libLLVM.dylib"
      end
    end
  end

  test do
    (testpath/"test.d").write <<~EOS
      import std.stdio;
      void main() {
        writeln("Hello, world!");
      }
    EOS
    system bin/"ldc2", "test.d"
    assert_match "Hello, world!", shell_output("./test")
    system bin/"ldc2", "-flto=thin", "test.d"
    assert_match "Hello, world!", shell_output("./test")
    system bin/"ldc2", "-flto=full", "test.d"
    assert_match "Hello, world!", shell_output("./test")
    system bin/"ldmd2", "test.d"
    assert_match "Hello, world!", shell_output("./test")
  end
end

__END__
--- ldc-1.24.0-src/runtime/druntime/src/ldc/intrinsics.di.ORIG	2021-02-19 00:16:52.000000000 +0000
+++ ldc-1.24.0-src/runtime/druntime/src/ldc/intrinsics.di	2021-02-19 00:17:05.000000000 +0000
@@ -26,6 +26,7 @@
 else version (LDC_LLVM_900)  enum LLVM_version =  900;
 else version (LDC_LLVM_1000) enum LLVM_version = 1000;
 else version (LDC_LLVM_1100) enum LLVM_version = 1100;
+else version (LDC_LLVM_1101) enum LLVM_version = 1101;
 else static assert(false, "LDC LLVM version not supported");
 
 enum LLVM_atleast(int major) = (LLVM_version >= major * 100);
--- a/driver/timetrace.d
+++ b/driver/timetrace.d
@@ -136,7 +136,7 @@ struct TimeTraceProfiler
     // timeBegin / time_scale = time in microseconds
     static if (is(typeof(&QueryPerformanceFrequency)))
     {
-        uint time_scale = 1_000;
+        timer_t time_scale = 1_000;
     } else {
         enum time_scale = 1_000;
     }
