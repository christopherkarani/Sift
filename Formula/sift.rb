class Sift < Formula
  desc "Semantic git history CLI powered by Wax"
  homepage "https://github.com/christopherkarani/Sift"
  url "https://github.com/christopherkarani/Sift/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_TARBALL_SHA256"
  license "Apache-2.0"

  depends_on "swift" => :build

  def install
    system "swift", "build", "-c", "release", "--product", "wax"
    bin.install ".build/release/wax"
  end

  test do
    assert_match "Sift semantic git history CLI", shell_output("#{bin}/wax --help")
  end
end
