cask "iris" do
  version "0.1.3"
  sha256 "e4cf0c11fb4bdb3b5b9403abf1cae88994dc90122c8931dffa3d1cb98360edd4"

  url "https://github.com/ahmetb/Iris/releases/download/v#{version}/Iris-v#{version}.zip"
  name "Iris"
  desc "Floating webcam viewing window (a hand mirror)"
  homepage "https://github.com/ahmetb/Iris"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Iris.app"

  zap trash: [
    "~/Library/Preferences/com.iris.app.plist",
  ]
end
