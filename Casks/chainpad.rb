cask "chainpad" do
  version "0.1.1"
  sha256 "ff3e11b05a7c2d1f94141fce155f22f8fa0562537f95d27b8aa79cd3fdb6e932"

  url "https://github.com/nhestrompia/chainpad/releases/download/v#{version}/ChainPad-#{version}.app.zip"
  name "ChainPad"
  desc "Menu bar crypto clipboard scratchpad"
  homepage "https://github.com/nhestrompia/chainpad"

  depends_on macos: ">= :sonoma"

  app "ChainPad.app"

  zap trash: [
    "~/Library/Application Support/ChainPad",
    "~/Library/Preferences/com.chainpad.app.plist",
  ]
end
