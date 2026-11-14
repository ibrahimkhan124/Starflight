# Aether physical-device comparison

Model: iPhone13,2; Version 27.2 (Build 24B119); target 30 Hz.

Intervals below measure game callbacks, not actual GPU-presented frames.

| Variant / window | Seconds | Callback p95 ms | CPU update p95 ms | Peak MiB | Thermal* | Outcome |
|---|---:|---:|---:|---:|---:|---|
| baseline-30 / Hoth entry 1 | 2.1 | 84 | 5 | 770.9 | 1 | entered |
| baseline-30 / Hoth flight 1 | 20.2 | 65 | 4 | 674.3 | 1 | flying |
| baseline-30 / Hoth orbit 1 | 2.0 | 84 | 4 | 698.1 | 1 | returned |
| baseline-30 / Tatooine entry 1 | 2.0 | 84 | 5 | 699.0 | 1 | entered |
| baseline-30 / Tatooine flight 1 | 20.0 | 67 | 4 | 703.2 | 1 | flying |
| baseline-30 / Tatooine orbit 1 | 2.1 | 65 | 3 | 703.0 | 1 | returned |
| baseline-30 / Endor entry 1 | 2.0 | 78 | 5 | 703.0 | 1 | entered |
| baseline-30 / Endor flight 1 | 20.1 | 66 | 4 | 703.0 | 1 | flying |
| baseline-30 / Endor orbit 1 | 2.1 | 51 | 4 | 703.1 | 1 | returned |
| baseline-30 / Hoth entry 2 | 2.1 | 84 | 6 | 703.1 | 1 | entered |
| baseline-30 / Hoth flight 2 | 20.2 | 65 | 4 | 703.0 | 1 | flying |
| baseline-30 / Hoth orbit 2 | 2.1 | 84 | 4 | 703.1 | 1 | returned |
| baseline-30 / Tatooine entry 2 | 2.1 | 77 | 6 | 703.1 | 1 | entered |
| baseline-30 / Tatooine flight 2 | 20.0 | 67 | 4 | 703.0 | 1 | flying |
| baseline-30 / Tatooine orbit 2 | 2.1 | 65 | 33 | 703.1 | 1 | returned |
| baseline-30 / Endor entry 2 | 2.0 | 84 | 6 | 703.0 | 1 | entered |
| baseline-30 / Endor flight 2 | 20.2 | 66 | 4 | 703.1 | 1 | flying |
| baseline-30 / Endor orbit 2 | 2.1 | 84 | 4 | 703.3 | 1 | returned |
| baseline-30 / Aether Reach flight | 20.2 | 51 | 9 | 704.8 | 1 | flying |
| candidate-30 / Hoth entry 1 | 2.1 | 84 | 5 | 804.9 | 1 | entered |
| candidate-30 / Hoth flight 1 | 20.2 | 65 | 4 | 751.0 | 1 | flying |
| candidate-30 / Hoth orbit 1 | 2.1 | 84 | 3 | 753.5 | 1 | returned |
| candidate-30 / Tatooine entry 1 | 2.1 | 112 | 25 | 752.9 | 1 | entered |
| candidate-30 / Tatooine flight 1 | 20.1 | 65 | 4 | 753.8 | 1 | flying |
| candidate-30 / Tatooine orbit 1 | 2.0 | 84 | 4 | 753.8 | 1 | returned |
| candidate-30 / Endor entry 1 | 2.0 | 84 | 4 | 753.7 | 1 | entered |
| candidate-30 / Endor flight 1 | 20.2 | 65 | 4 | 753.6 | 1 | flying |
| candidate-30 / Endor orbit 1 | 2.1 | 84 | 4 | 753.8 | 1 | returned |
| candidate-30 / Hoth entry 2 | 2.0 | 84 | 6 | 753.8 | 1 | entered |
| candidate-30 / Hoth flight 2 | 20.3 | 51 | 4 | 753.7 | 1 | flying |
| candidate-30 / Hoth orbit 2 | 2.1 | 84 | 4 | 753.8 | 1 | returned |
| candidate-30 / Tatooine entry 2 | 2.1 | 84 | 6 | 753.9 | 1 | entered |
| candidate-30 / Tatooine flight 2 | 20.1 | 66 | 4 | 753.4 | 1 | flying |
| candidate-30 / Tatooine orbit 2 | 2.1 | 68 | 4 | 753.5 | 1 | returned |
| candidate-30 / Endor entry 2 | 2.1 | 83 | 5 | 753.4 | 1 | entered |
| candidate-30 / Endor flight 2 | 20.1 | 66 | 4 | 753.4 | 1 | flying |
| candidate-30 / Endor orbit 2 | 2.1 | 84 | 4 | 753.5 | 1 | returned |
| candidate-30 / Aether Reach flight | 20.2 | 67 | 10 | 753.7 | 1 | flying |

*Thermal: 0 nominal, 1 fair, 2 serious, 3 critical. Peaks include GPU/driver allocations charged to the app.

## baseline-30

Local review: REVISE

- Hoth flight 1: callback p95 above review budget
- Hoth flight 1: more than 5% late callbacks
- Tatooine flight 1: callback p95 above review budget
- Tatooine flight 1: more than 5% late callbacks
- Endor flight 1: callback p95 above review budget
- Endor flight 1: more than 5% late callbacks
- Hoth flight 2: callback p95 above review budget
- Hoth flight 2: more than 5% late callbacks
- Tatooine flight 2: callback p95 above review budget
- Tatooine flight 2: more than 5% late callbacks
- Endor flight 2: callback p95 above review budget
- Endor flight 2: more than 5% late callbacks
- Aether Reach flight: callback p95 above review budget
- Aether Reach flight: more than 5% late callbacks
- Hoth entry 1: footprint above 600 MiB review budget
- Hoth flight 1: footprint above 600 MiB review budget
- Hoth orbit 1: footprint above 600 MiB review budget
- Tatooine entry 1: footprint above 600 MiB review budget
- Tatooine flight 1: footprint above 600 MiB review budget
- Tatooine orbit 1: footprint above 600 MiB review budget
- Endor entry 1: footprint above 600 MiB review budget
- Endor flight 1: footprint above 600 MiB review budget
- Endor orbit 1: footprint above 600 MiB review budget
- Hoth entry 2: footprint above 600 MiB review budget
- Hoth flight 2: footprint above 600 MiB review budget
- Hoth orbit 2: footprint above 600 MiB review budget
- Tatooine entry 2: footprint above 600 MiB review budget
- Tatooine flight 2: footprint above 600 MiB review budget
- Tatooine orbit 2: footprint above 600 MiB review budget
- Endor entry 2: footprint above 600 MiB review budget
- Endor flight 2: footprint above 600 MiB review budget
- Endor orbit 2: footprint above 600 MiB review budget
- Aether Reach flight: footprint above 600 MiB review budget

Events: `{"aetherReachPreparationSeconds": 0.13655387499602512, "aetherReachReturnedToOrbit": 1, "cancelledJumpPreservedOrbit": 1, "startupUntilReadySeconds": 3.105613624997204, "worldConstructionSeconds": 2.482014708322822}`

## candidate-30

Local review: REVISE

- Hoth flight 1: callback p95 above review budget
- Hoth flight 1: more than 5% late callbacks
- Tatooine flight 1: callback p95 above review budget
- Tatooine flight 1: more than 5% late callbacks
- Endor flight 1: callback p95 above review budget
- Endor flight 1: more than 5% late callbacks
- Hoth flight 2: callback p95 above review budget
- Hoth flight 2: more than 5% late callbacks
- Tatooine flight 2: callback p95 above review budget
- Tatooine flight 2: more than 5% late callbacks
- Endor flight 2: callback p95 above review budget
- Endor flight 2: more than 5% late callbacks
- Aether Reach flight: callback p95 above review budget
- Aether Reach flight: more than 5% late callbacks
- Hoth entry 1: footprint above 600 MiB review budget
- Hoth flight 1: footprint above 600 MiB review budget
- Hoth orbit 1: footprint above 600 MiB review budget
- Tatooine entry 1: footprint above 600 MiB review budget
- Tatooine flight 1: footprint above 600 MiB review budget
- Tatooine orbit 1: footprint above 600 MiB review budget
- Endor entry 1: footprint above 600 MiB review budget
- Endor flight 1: footprint above 600 MiB review budget
- Endor orbit 1: footprint above 600 MiB review budget
- Hoth entry 2: footprint above 600 MiB review budget
- Hoth flight 2: footprint above 600 MiB review budget
- Hoth orbit 2: footprint above 600 MiB review budget
- Tatooine entry 2: footprint above 600 MiB review budget
- Tatooine flight 2: footprint above 600 MiB review budget
- Tatooine orbit 2: footprint above 600 MiB review budget
- Endor entry 2: footprint above 600 MiB review budget
- Endor flight 2: footprint above 600 MiB review budget
- Endor orbit 2: footprint above 600 MiB review budget
- Aether Reach flight: footprint above 600 MiB review budget

Events: `{"aetherReachPreparationSeconds": 0.06058225000742823, "aetherReachReturnedToOrbit": 1, "cancelledJumpPreservedOrbit": 1, "startupUntilReadySeconds": 0.3314106666803127, "worldConstructionSeconds": 1.6908002916752594}`

## Release boundary

This automated report cannot approve release by itself. Physical iPad testing, GPU presentation evidence, visual/gameplay review and longer thermal sessions remain separate gates.
