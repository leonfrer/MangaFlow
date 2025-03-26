import SwiftUI

struct ImageThumbnail: View {
    let path: String
    let isSelected: Bool
    let onTap: () -> Void
    @ObservedObject private var thumbnailHelper = ThumbnailCacheManager.shared

    var body: some View {
        Group {
            if let cachedImage = thumbnailHelper.cache[path] {
                let imageSize = cachedImage.size
                let aspectRatio = imageSize.width / imageSize.height

                Image(nsImage: cachedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: aspectRatio >= 1 ? 80 : 80 * aspectRatio,
                        height: aspectRatio <= 1 ? 80 : 80 / aspectRatio
                    )
                    .padding(4)
                    .onTapGesture(perform: onTap)
                    .border(isSelected ? Color.blue : Color.gray, width: 2)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .padding(4)
                    .border(Color.gray, width: 2)
                    .onAppear {
                        thumbnailHelper.loadThumbnail(path: path)
                    }
            }
        }
    }
}
