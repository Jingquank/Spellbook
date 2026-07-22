enum FallbackThumbnailComposition: Int, CaseIterable {
    case croppedGeometry
    case mosaicTiles
    case concentricForms
    case radialFan
    case wovenStrips

    init(index: Int) {
        let compositions = Self.allCases
        let remainder = index % compositions.count
        let wrappedIndex = remainder >= 0 ? remainder : remainder + compositions.count
        self = compositions[wrappedIndex]
    }
}
