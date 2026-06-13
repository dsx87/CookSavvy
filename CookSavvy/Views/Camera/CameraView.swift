//
//  CameraView.swift
//  CookSavvy
//

import SwiftUI
import AVFoundation

/// Camera screen for AI ingredient detection.
///
/// Renders different layouts based on `CameraViewModel.State`:
/// - `.requestingPermission` — spinner while awaiting authorization
/// - `.permissionDenied` — instructional screen with deep-link to Settings
/// - `.capturing` — live `CameraCaptureView` (UIKit UIViewController wrapper)
/// - `.processing` — frozen captured image with a loading overlay
/// - `.noIngredientsFound` — empty-state prompt with retry option
/// - `.error` — auto-dismissing error toast
struct CameraView: View {
    @StateObject var viewModel: CameraViewModel
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch viewModel.state {
            case .requestingPermission:
                ProgressView()
                    .tint(.white)
                
            case .permissionDenied:
                permissionDeniedView
                
            case .capturing:
                CameraCaptureView(onPhotoCaptured: viewModel.photoCaptured)
                    .overlay(alignment: .top) { disclosureBanner }

            case .processing(let image):
                processingView(image: image)
                
            case .noIngredientsFound:
                noIngredientsView
                
            case .error(let message):
                errorToastView(message: message)
            }
        }
        .onAppear {
            viewModel.checkCameraPermission()
        }
    }
    
    /// One-line privacy disclosure overlaid on the live preview, informing users that captured
    /// photos are sent off-device to the AI service for ingredient detection (ticket T-034).
    /// Top-center placement clears the top-left close button and the bottom-center shutter.
    private var disclosureBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text(Strings.Camera.aiProcessingDisclosure)
        }
        .font(UI.Fonts.smallCaption)
        .foregroundColor(.white.opacity(0.8))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Camera.aiProcessingDisclosure)
    }

    /// Full-screen instruction card shown when camera permission is denied or restricted.
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: Icons.Camera.camera)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text(Strings.Camera.accessRequired)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(Strings.Camera.accessDescription)
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button {
                    viewModel.openSettings()
                } label: {
                    Text(Strings.Camera.openSettings)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                
                Button {
                    viewModel.dismiss()
                } label: {
                    Text(Strings.Common.cancel)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
    
    /// Overlay shown during AI processing: displays the frozen captured image with a spinner.
    private func processingView(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(Strings.Camera.detecting)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    /// Empty-state view shown when AI detection found no ingredients in the captured image.
    private var noIngredientsView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: Icons.Camera.warning)
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text(Strings.Camera.noIngredientsTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(Strings.Camera.noIngredientsSubtitle)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                VStack(spacing: 12) {
                    Button {
                        viewModel.retryCapture()
                    } label: {
                        Text(Strings.Camera.tryAgain)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        viewModel.dismiss()
                    } label: {
                        Text(Strings.Common.cancel)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
        }
    }
    
    /// Brief error toast displayed at the bottom of the screen before auto-dismissal.
    private func errorToastView(message: String) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    Image(systemName: Icons.Camera.errorCircle)
                        .foregroundColor(.red)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.red.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
    }
}

/// SwiftUI wrapper around `CameraCaptureViewController`, bridging UIKit camera capture to SwiftUI.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onPhotoCaptured: (UIImage) -> Void
    var showsCloseButton: Bool = true
    
    /// Creates and configures the UIKit camera controller used by this representable.
    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        let controller = CameraCaptureViewController()
        controller.onPhotoCaptured = onPhotoCaptured
        controller.showsCloseButton = showsCloseButton
        return controller
    }
    
    /// No-op updater because camera configuration is set during controller creation.
    func updateUIViewController(_ uiViewController: CameraCaptureViewController, context: Context) {}
}

/// UIKit view controller managing the `AVCaptureSession` live preview and shutter button.
///
/// Sets up the rear wide-angle camera, adds a preview layer covering the full view,
/// and lays out a round capture button and optional close button using Auto Layout.
final class CameraCaptureViewController: UIViewController {
    var onPhotoCaptured: ((UIImage) -> Void)?
    var showsCloseButton: Bool = true
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    /// Sets up camera session and overlays once the view has loaded.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }
    
    /// Keeps the preview layer frame in sync with view bounds changes.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    /// Configures the `AVCaptureSession` with a rear camera input, photo output, and preview layer.
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.photoOutput = output
        self.previewLayer = previewLayer
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    /// Adds the capture and (optionally) close buttons to the view hierarchy using Auto Layout.
    private func setupUI() {
        view.addSubview(captureButton)
        if showsCloseButton {
            view.addSubview(closeButton)
        }
        
        var constraints = [
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
        ]

        if showsCloseButton {
            constraints.append(contentsOf: [
                closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
                closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                closeButton.widthAnchor.constraint(equalToConstant: 40),
                closeButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }
    
    /// Captures a still photo (or a blank simulator placeholder image in simulator builds).
    @objc private func capturePhoto() {
        guard !DeviceUtility.isSimulator else {
            self.onPhotoCaptured?(UIImage())
            return
        }
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    /// Dismisses the camera controller when the close button is tapped.
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    /// Stops camera capture when the controller is deallocated.
    deinit {
        captureSession?.stopRunning()
    }
}

/// Handles AVCapture still-photo callbacks and forwards successful images to SwiftUI.
extension CameraCaptureViewController: AVCapturePhotoCaptureDelegate {
    /// Processes captured photo data and emits a `UIImage` via `onPhotoCaptured`.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(image)
        }
    }
}
