cask "chainpad" do
  version "0.1.0"
  sha256 "dbf26b7ff50e327368c2ed7ea8fbc80ead8da2e0f7e3cbab0f3fc1d6cecf6be0"

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
