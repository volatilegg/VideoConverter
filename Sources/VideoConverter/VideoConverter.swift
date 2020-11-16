#if os(iOS)
import UIKit
import AVFoundation

public class MovieConverter {
    static let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    static let tempPath = paths[0] + "/exprotvideo.mp4"
    static let fileURL = URL(fileURLWithPath: tempPath)

    var assetWriter: AVAssetWriter!
    var writeInput: AVAssetWriterInput!
    var bufferAdapter: AVAssetWriterInputPixelBufferAdaptor!
    var videoSettings: [String: Any]!
    var frameTime: CMTime = CMTime(value: 1, timescale: 5)

    var completionBlock: ((URL) -> Void)?
    var movieMakerUIImageExtractor: ((Any) -> UIImage?)?

    public class func videoSettings(width: Int, height: Int) -> [String: Any] {
        if Int(width) % 16 != 0 {
            print("warning: video settings width must be divisible by 16")
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        return videoSettings
    }

    public init(videoSettings: [String: Any]) {

        if FileManager.default.fileExists(atPath: MovieConverter.tempPath) {
            guard (try? FileManager.default.removeItem(atPath: MovieConverter.tempPath)) != nil else {
                print("remove path failed")
                return
            }
        }

        self.assetWriter = try! AVAssetWriter(url: MovieConverter.fileURL, fileType: AVFileType.mov)

        self.videoSettings = videoSettings
        self.writeInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)

        if !self.assetWriter.canAdd(self.writeInput) {
            fatalError("Adding input failed")
        }

        self.assetWriter.add(self.writeInput)
        let bufferAttributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)]
        self.bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.writeInput, sourcePixelBufferAttributes: bufferAttributes)
    }

    public func createMovieFrom(urls: [URL], withCompletion: @escaping (URL) -> Void) {
        self.createMovieFromSource(
            images: urls as [Any],
            extractor: {(inputObject: Any) -> UIImage? in
                return UIImage(data: try! Data(contentsOf: inputObject as! URL))
            },
            withCompletion: withCompletion)
    }

    public func createMovieFrom(images: [UIImage], withCompletion: @escaping (URL) -> Void) {
        self.createMovieFromSource(
            images: images,
            extractor: { inputObject -> UIImage? in
                return inputObject as? UIImage
            },
            withCompletion: withCompletion)
    }

    public func createMovieFromSource(images: [Any], extractor: @escaping (Any) -> UIImage?, withCompletion: @escaping (URL) -> Void) {
        self.completionBlock = withCompletion

        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMTime.zero)

        let mediaInputQueue = DispatchQueue(label: "mediaInputQueue")
        var i = 0
        let frameNumber = images.count

        self.writeInput.requestMediaDataWhenReady(on: mediaInputQueue) {
            while true {
                if i >= frameNumber {
                    break
                }

                if self.writeInput.isReadyForMoreMediaData {
                    var sampleBuffer: CVPixelBuffer?
                    autoreleasepool {
                        let img = extractor(images[i])
                        if img == nil {
                            i += 1
                            print("Warning: counld not extract one of the frames")
                            //continue
                        }
                        sampleBuffer = self.newPixelBufferFrom(cgImage: img!.cgImage!)
                    }
                    if sampleBuffer != nil {
                        if i == 0 {
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: CMTime.zero)
                        } else {
                            let value = i - 1
                            let lastTime = CMTimeMake(value: Int64(value), timescale: self.frameTime.timescale)
                            let presentTime = CMTimeAdd(lastTime, self.frameTime)
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: presentTime)
                        }
                        i = i + 1
                    }
                }
            }
            self.writeInput.markAsFinished()
            self.assetWriter.finishWriting {
                DispatchQueue.main.sync {
                    self.completionBlock!(MovieConverter.fileURL)
                }
            }
        }
    }

    private func newPixelBufferFrom(cgImage: CGImage) -> CVPixelBuffer? {
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pxbuffer: CVPixelBuffer?
        let frameWidth = self.videoSettings[AVVideoWidthKey] as! Int
        let frameHeight = self.videoSettings[AVVideoHeightKey] as! Int

        let status = CVPixelBufferCreate(kCFAllocatorDefault, frameWidth, frameHeight, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxbuffer)
        assert(status == kCVReturnSuccess && pxbuffer != nil, "newPixelBuffer failed")

        CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxdata = CVPixelBufferGetBaseAddress(pxbuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGContext(data: pxdata, width: frameWidth, height: frameHeight, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        assert(context != nil, "context is nil")

        context!.concatenate(CGAffineTransform.identity)
        context!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pxbuffer
    }
}
#endif
