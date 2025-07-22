//
//  AsyncImageDisk.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 27/06/2025.
//

import SwiftUI
import UIKit

struct DefaultPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .foregroundStyle(Color.backOrange)
//                .frame(width: 100, height: 100)
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
    private let zipFileURL: URL
    private let imageExtractor: ImageExtractor = ImageExtractor()
    private let imageNameBuilder: ((String?, String) -> String)
    @State private var image: UIImage? = nil
    @ViewBuilder private let placeholder: Placeholder
    
    init(
        imageName: String,
        imageNamePrefix: String?,
        zipFileURL: URL,
        imageNameBuilder: @escaping ((String?, String) -> String),
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.imageNamePrefix = imageNamePrefix
        self.imageName = imageName
        self.placeholder = placeholder()
        self.zipFileURL = zipFileURL
        self.imageNameBuilder = imageNameBuilder
    }
    
    init(imageName: String, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageNamePrefix = "Food Images/Food Images/"
        self.imageName = imageName
        self.placeholder = placeholder()
        self.zipFileURL = Bundle.main.url(forResource: "food-ingredients-and-recipe-dataset-with-images", withExtension: "zip")!
        self.imageNameBuilder = ({ prefix, imageFileName in
            var imageFileName = imageFileName + ".jpg"
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
            } else {
                placeholder
            }
            
        }
        .task {
            do {
                let image = try await imageExtractor.extractImage(
                    withName: imageNameBuilder(self.imageNamePrefix, self.imageName),
                    
                    fromZipFile: zipFileURL)
                self.image = UIImage(data: image)
            } catch {
                print(error)
            }
        }
    }
}

#Preview {
    AsyncImageDisk(
        imageName: "-bloody-mary-tomato-toast-with-celery-and-horseradish-56389813",
        imageNamePrefix: "Food Images/Food Images/",
        zipFileURL: Bundle.main.url(forResource: "food-ingredients-and-recipe-dataset-with-images", withExtension: "zip")!,
        imageNameBuilder: ({ prefix, imageFileName in
            var imageFileName = imageFileName + ".jpg"
            if let prefix {
                imageFileName = prefix + imageFileName
            }
            return imageFileName
            
        }),
        placeholder: ({
            Color.gray
        })
    )
}
