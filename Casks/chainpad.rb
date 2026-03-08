cask "chainpad" do
  version "0.1.0"
  sha256 "54c932c03f63b2c98fa6fcfb8dc925bfb649c2114a39539e8f2c0531b537d301"

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
