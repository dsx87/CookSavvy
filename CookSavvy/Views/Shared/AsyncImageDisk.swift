//
//  AsyncImageDisk.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 27/06/2025.
//

import SwiftUI
import UIKit

struct DefaultPlaceholder: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UI.Common.placeholderCornerRadius)
                .foregroundStyle(theme.backgroundPrimary)
            ProgressView()
            
        }
    }
}

#Preview {
    DefaultPlaceholder()
}


struct AsyncImageDisk<Placeholder: View>: View {
    
    let imageName: String
    private var imageNamePrefix: String?
    private let imageNameBuilder: ((String?, String) -> String)
    @State private var image: UIImage? = nil
    @ViewBuilder private let placeholder: Placeholder
    
    init(
        imageName: String,
        imageNamePrefix: String?,
        imageNameBuilder: @escaping ((String?, String) -> String),
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.imageNamePrefix = imageNamePrefix
        self.imageName = imageName
        self.placeholder = placeholder()
        self.imageNameBuilder = imageNameBuilder
    }
    
    init(imageName: String, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageNamePrefix = UI.DiskImage.defaultPrefix
        self.imageName = imageName
        self.placeholder = placeholder()
        self.imageNameBuilder = ({ prefix, imageFileName in
            var imageFileName = imageFileName + UI.DiskImage.defaultExtension
            if let prefix {
                imageFileName = prefix + imageFileName
            }
            return imageFileName
            
        })
    }
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
            }
            
        }
        .task {
            let fullImageName = imageNameBuilder(self.imageNamePrefix, self.imageName)
            do {
                self.image = try await AppContainer.shared.imageService.loadImage(named: fullImageName)
            } catch {
                print(error)
            }
        }
    }
}

#Preview {
    AsyncImageDisk(
        imageName: "-bloody-mary-tomato-toast-with-celery-and-horseradish-56389813",
//        imageNamePrefix: "Food Images/Food Images/",
//        imageNameBuilder: ({ prefix, imageFileName in
//            var imageFileName = imageFileName + ".jpg"
//            if let prefix {
//                imageFileName = prefix + imageFileName
//            }
//            return imageFileName
//            
//        }),
        placeholder: ({
            Color.gray
        })
    )
}
