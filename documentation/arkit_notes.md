# ARKit Notes

## General
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