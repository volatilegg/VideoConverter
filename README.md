# VideoConverter

A Swift lib that convert array of images into video



## Usage

```swift
let frames = [UIImage]()

// The size of the output movie, should be the size of the image
let settings = VideoConverter.videoSettings(width: 120, height: 120)
let movieMaker = VideoConverter(videoSettings: settings)

// Video path url as output callback
movieMaker.createMovieFrom(images: frames) { fileURL in
    print(fileURL)
}
```
