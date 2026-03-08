cask "chainpad" do
  version "0.1.0"
  sha256 "e36ee9367a3340e94a45181c455050a5d8213f4e46fe245c6a51ed7989567c53"

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
