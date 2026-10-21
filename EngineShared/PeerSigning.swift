import Foundation
import Security

enum PeerSigning {
    static func requirement(for url: URL) throws -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { throw NSError(domain: "OverflowBar.Signature", code: 1) }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess, let requirement else { throw NSError(domain: "OverflowBar.Signature", code: 2) }
        var string: CFString?
        guard SecRequirementCopyString(requirement, [], &string) == errSecSuccess, let string else { throw NSError(domain: "OverflowBar.Signature", code: 3) }
        return string as String
    }
    static func containingApplication(of helper: URL) throws -> URL {
        var url = helper
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            if url.pathExtension == "app" { return url }
        }
        throw NSError(domain: "OverflowBar.Signature", code: 4)
    }
}
