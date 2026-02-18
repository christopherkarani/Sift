class Sift < Formula
  desc "Semantic git history CLI powered by Wax"
  homepage "https://github.com/christopherkarani/Sift"
  url "https://github.com/christopherkarani/Sift/archive/refs/tags/0.0.3.tar.gz"
  sha256 "59efac1a74e495549129bd84a7365c649687af9a7d8b06239a3238f175cf338e"
  license "Apache-2.0"

  depends_on "swift" => :build

  def install
    ENV["SWIFTPM_DISABLE_SANDBOX"] = "1"
    system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "wax"
    bin.install ".build/release/wax"
  end

  test do
    assert_match "Sift semantic git history CLI", shell_output("#{bin}/wax --help")
  end
end
