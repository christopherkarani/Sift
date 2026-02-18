class Sift < Formula
  desc "Semantic git history CLI powered by Wax"
  homepage "https://github.com/christopherkarani/Sift"
  url "https://github.com/christopherkarani/Sift/archive/refs/tags/0.0.2.tar.gz"
  sha256 "e174e2f0449925f7831e382c4afd7288e9b9cd6d10b2bd67653eaf6e59466553"
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
