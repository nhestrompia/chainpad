import CryptoScratchpadKit
import Testing

@MainActor
struct DetectorTests {
    private let detector = RegexDetector()

    @Test
    func detectsEVMAddress() {
        let value = "0x1234567890abcdef1234567890abcdef12345678"
        let result = detector.detect(value)

        #expect(result?.kind == .evmAddress)
        #expect(result?.type == .wallet)
    }

    @Test
    func detectsSolanaAddress() {
        let value = "So11111111111111111111111111111111111111112"
        let result = detector.detect(value)

        #expect(result?.kind == .solanaAddress)
        #expect(result?.chainHint == .solana)
    }

    @Test
    func ignoresRandomText() {
        let result = detector.detect("hello this is not crypto data")
        #expect(result == nil)
    }

    @Test
    func classifiesExplorerTransactionURL() {
        let value = "https://etherscan.io/tx/0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let result = detector.detect(value)

        #expect(result?.kind == .explorerURL)
        #expect(result?.type == .transaction)
        #expect(result?.chainHint == .ethereum)
    }
}
