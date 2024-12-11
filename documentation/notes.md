# Notes
## Swift Related Notes
### Structs vs. Classes
| Feature                     | Structs                                | Classes                                |
|-----------------------------|----------------------------------------|---------------------------------------|
| **Inheritance**             | Not supported                         | Supported                             |
| **Value Type vs Reference** | Value type (copied when assigned)     | Reference type (shared references)   |
| **Mutability**              | Immutable by default                  | Mutable by default                    |
| **Memory Management**       | Stored on the stack (usually)         | Stored on the heap                    |
| **ARC (Automatic Reference Counting)** | Not used                         | Used                                  |
| **Performance**             | Generally faster for small data       | Overhead due to ARC and heap storage  |
| **Initialization**          | Automatic memberwise initializer      | No automatic memberwise initializer   |
| **Use Cases**               | Prefer for lightweight data models    | Use for complex objects with shared state |
| **Custom Deinitializer**    | Not available                         | Available (via `deinit`)              |

### Protocols
```swift
protocol Animal {
    var name: String { get }
    func makeSound()
}

struct Dog: Animal {
    var name: String
    func makeSound() {
        print("Woof!")
    }
}
```

**Unterschiede zu Java-Interfaces:**
- Inheritance: protocols can inherit from other protocols
- Protocols can also specify properties that must be implemented (i.e. fields)
- Protocols need to deal with value/reference through the use of the mutating keyword:
```swift
protocol Animal {
    var name: String { get set }
    mutating func changeName(to newName: String)
}

struct Dog: Animal {
    var name: String
    mutating func changeName(to newName: String) {
        name = newName
    }
}
```
&rarr; `mutating` keyword is required because the method changes the state of the instance, which would not be allowed normally for value types


### Optionals
```swift
let shortForm: Int? = Int("42")
let longForm: Optional<Int> = Int("42")

let number: Int? = Optional.some(42)
let noNumber: Int? = Optional.none // == nil

// Unwrapping
if let starPath = imagePaths["star"] {
    print("The star image is at '\(starPath)'")
} else {
    print("Couldn't find the star image")
}

let number = Int("42")! // Force unwrapping: throws error when nil
print(noNumber ?? "Default Value") // Nil coalescing: use default value when nil
```

### Guard Keyword
```swift
// if vs. guard
func voteEligibilityWithIfStmnt() {
  var age = 42
  if age >= 18 {
  print("Eligible to vote")
  }
  else {
  print("Not eligible to vote")
  }
}

func voteEligibilityWithGuard() {   
  var age = 42
  guard age >= 18 else {
  print("Not Eligible to vote")
  return
  }
  print("Eligible to vote")
}

// guard with optional binding
func loadFile(at path: String?) {
    guard let path = path else {
        print("Path cannot be nil")
        return
    }
    print("Loading file at \(path)")
}
```
&rarr; Seems to be a philosophical difference between `if` and `guard` (early exit vs. normal flow)

### Opaque Return Types
```swift
var body: some View {
    RealityView { content in
        setupBasicARWorld(content)
        content.camera = .spatialTracking
    }
}
```
- `some` keyword: hides the concrete type of the return value
- Used for returning a single type conforming to a protocol or a protocol composition
- Flexibility: allows the return type to change without affecting the caller

### Closures
```swift
let closure: (Int, Int) -> Int = { (a: Int, b: Int) -> Int in
    return a + b
}
closure(1, 2) // 3

// Closure as a parameter: "()" are optional when the closure is the last parameter
RealityView { content in
    setupBasicARWorld(content)
    content.camera = .spatialTracking
}
```

## ARKit Basics
### Frameworks
- ARKit: provides the fundamental AR functionality such as visual positioning, object detection, and face tracking
- SceneKit: provides a high-level framework for working with 3D content (old; only works in conjunction with ARKit)
- RealityKit: Apple's new high-level framework for working with 3D content (supports LiDAR)
- UIKit: provides the basic building blocks for iOS apps
- MetalKit: provides a high-level interface for working with Metal, Apple's low-level graphics API

### Basic AR App with RealityKit
1. Generate a MeshResource (e.g., a box, sphere, or plane)
1. Create a Material (e.g. a SimpleMaterial)
1. Create a ModelEntity with the MeshResource and Material (use ModelComponent)
1. Create an Anchor (AnchorEntity; types: .plane, .image, .face, .object, ...)
1. Add the ModelEntity to the Anchor
1. Transform the Anchor (e.g., position, rotation, scale) if necessary
1. Add the Anchor to the Content
