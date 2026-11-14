# Stage six — reduce retained terrain payload

The original roadmap ends at stage five. This follow-up addresses a concrete
resource-retention issue found while reviewing that stage's device results.

Each Aether home-world tile previously retained three MeshData values: its top,
its skirt and the combined upload mesh. Rendering uses only the combined mesh.
The cache now retains that single payload. Grid sampling, uploaded triangles,
seam normals, skirts, materials and world preparation behavior are unchanged.

At the current 16-tile resolution this removes 1,864,192 bytes of duplicated
position/normal/index payload per planet, or about 5.33 MiB across Hoth, Tatooine
and Endor. This is a calculation of retained array elements using Swift's SIMD3
stride and UInt32 indices, not a measured reduction in total process footprint.
Allocator and RealityKit resource behavior can produce different device results.

The seam/winding regression test now reconstructs top/skirt views from the actual
combined upload payload. It still checks shared heights and normals, upward
winding, bounded skirts and geometry budgets. The independent-world tests check
contact equivalence and stable scene entities.

The Mac build and five focused simulator tests are the validation for this
change. Physical-device footprint, GPU-presented frames and sustained thermal
measurements remain pending. Stage five's REVISE decision remains in force.
