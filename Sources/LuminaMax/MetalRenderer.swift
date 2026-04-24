import AppKit
import MetalKit

class MetalRenderer: MTKView, MTKViewDelegate {
    private let edrColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
    private var metalCommandQueue: MTLCommandQueue?

    /// The EDR multiplier. Values > 1.0 trigger HDR brightness.
    var edrMultiplier: Float = 16.0 {
        didSet {
            // Update the clear color to force the EDR mode
            updateClearColor()
        }
    }

    init?(screen: NSScreen) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }

        super.init(frame: .zero, device: device)

        // Critical: drawable is only 1x1 pixel — that's all we need!
        // The mere presence of an EDR-capable Metal layer with pixel values > 1.0
        // is enough to trigger the display's HDR mode
        autoResizeDrawable = false
        drawableSize = CGSize(width: 1, height: 1)

        metalCommandQueue = device.makeCommandQueue()
        guard metalCommandQueue != nil else {
            print("Could not create Metal command queue")
            return nil
        }

        // Configure as MTKView delegate
        delegate = self
        colorPixelFormat = .rgba16Float
        colorspace = edrColorSpace
        preferredFramesPerSecond = 5 // Low FPS is fine, we just need to keep the layer alive

        // Set the clear color to a very high EDR value
        // This is the key — clearColor values >> 1.0 signal EDR content
        updateClearColor()

        // Configure the underlying CAMetalLayer for EDR
        if let metalLayer = layer as? CAMetalLayer {
            metalLayer.wantsExtendedDynamicRangeContent = true
            metalLayer.isOpaque = false
            metalLayer.pixelFormat = .rgba16Float
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateClearColor() {
        // Use a very high HDR value — BrightIntosh uses 16.0
        // This forces the display compositor to activate HDR/XDR mode
        let hdrValue = Double(edrMultiplier)
        clearColor = MTLClearColorMake(hdrValue, hdrValue, hdrValue, 1.0)
    }

    func screenUpdate(screen: NSScreen) {
        updateClearColor()
    }

    // MARK: - MTKViewDelegate

    func draw(in view: MTKView) {
        guard let commandQueue = metalCommandQueue,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        // Nothing to draw — the clearColor itself is the EDR content
        renderEncoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Nothing to do
    }
}
