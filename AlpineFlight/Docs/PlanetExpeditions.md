# Scenic expedition update

The selected visual directions were reviewed against Ethan Mollick's Portals gallery and relevant world builders (https://github.com/emollick/ai-portals). These native Swift landscapes are original implementations of the chosen scenery ideas; no Three.js world code or assets have been bundled.

- Coruscant: dark towers, neon street canyons, rain and layered atmospheric depth.
- Tatooine: winding sandstone canyon, strata, dusty sunlight and dunes.
- Hoth: a broad glacier, blue crevasses, snow and irregular side ridges.
- Endor: giant redwood trunks, high canopies, ferns and dawn shafts.
- Mercury: airless crater landscape and exposed grey rock.
- Venus: volcanic basalt, caldera formations and amber haze.
- Earth: granite river valley, waterfalls, forest and coast.
- Mars: dry basins, dunes and eroded ridges.
- Jupiter: layered cloud belts and a large cyclone.

Saturn, Uranus, Neptune and the Moon retain their existing scenery.

Both planetary terrain renderers draw the same vertices/triangles used for ground contact. All regions are prepared before they appear. Small decorative weather and lighting meshes do not act as solid obstacles. Large scenery stays within shared collision envelopes. Static details are grouped by material; there is no scenery streaming or detail replacement during a flight.

The quality pass adds shared 256-pixel seamless albedo and normal maps for rock, sand, snow, moss and bark. The mesh normals are smoothed without changing the terrain contact triangles. Continuous sky textures replace horizon bands. Endor tree centres vary within their cells, and its safe arrival is lowered into the forest corridor. Coruscant rain/snow uses a moving prepared batch and Jupiter rotates its cyclone as one group.

The reduced/full scenery budgets remain enforced by the existing tests (under 700,000 triangles and 100 entities for the four home planets, under 180,000 triangles and 50 entities for Solar System expeditions). The four excluded worlds retain the legacy renderer and terrain; a regression test covers that contract. Render budgets do not certify a physical-device frame rate.

Final forest foliage uses an original cached needle/branch cutout texture across crossed planes, in one prepared batch. Endor's full scene measured 315,790 triangles / 46 entities and its reduced scene 152,139 triangles / 33 entities in the focused renderer test. The normal home-world update now moves the weather batch in place. Jupiter uses irregular cloud silhouettes and offset clusters to break the earlier regular pattern, plus a cached rotating cyclone group.

Gameplay media is in `Screenshots/PlanetExpeditions-20261113/index.html`. The nine-world tour exercised the actual touch throttle and normal planet entry/orbit return controls. It ran on the iPad Air 13-inch (M4) simulator with iOS 26.5; it does not establish a physical iPad or iPhone frame-rate result.
