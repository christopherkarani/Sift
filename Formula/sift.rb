class Sift < Formula
  desc "Semantic git history CLI powered by Wax"
  homepage "https://github.com/christopherkarani/Sift"
  url "https://github.com/christopherkarani/Sift/archive/refs/tags/0.0.1.tar.gz"
  sha256 "ea6d5f85a6fc5045be59cff5408111e3bc819dcf42381926b8eea8a3eda468c0"
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
