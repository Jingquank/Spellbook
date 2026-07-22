import Foundation

public enum MarkdownAssetResolver {
    public static func localAssetURL(source: String, packageRootURL: URL) -> URL? {
        guard !source.isEmpty, URL(string: source)?.scheme == nil else { return nil }
        let canonicalRoot = packageRootURL.standardizedFileURL.resolvingSymlinksInPath()
        let decodedSource = source.removingPercentEncoding ?? source
        let candidate = canonicalRoot
            .appending(path: decodedSource)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard candidate.isDescendantOrEqual(to: canonicalRoot) else { return nil }
        return candidate
    }
}

private extension URL {
    func isDescendantOrEqual(to ancestor: URL) -> Bool {
        let components = standardizedFileURL.pathComponents
        let ancestorComponents = ancestor.standardizedFileURL.pathComponents
        return components.count >= ancestorComponents.count
            && Array(components.prefix(ancestorComponents.count)) == ancestorComponents
    }
}
