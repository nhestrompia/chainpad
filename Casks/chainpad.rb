cask "chainpad" do
  version "0.1.2"
  sha256 "836f2538c39f4042a626a7bdfc8704d9d9e7f7f3ad26b285149c861ea2c03fd8"

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
