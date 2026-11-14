# Third-party notices

Portals-derived surface masks: Ethan Mollick / emollick/ai-portals, commit
`210133f4e718acb7b461f2a40c90661a40a2397f`, CC BY-NC-SA 4.0. See LICENSE and
PROVENANCE.md for the actual adaptations.

## SplitMix64

`SeededRandom.next` uses the SplitMix64 recurrence published by Sebastiano Vigna
(2015). Primary source: https://prng.di.unimi.it/splitmix.c (verified 2026-11-13).
The wrapping Swift translation keeps instance-owned state and a new 24-bit Float
conversion. It is not taken from Portals. Upstream notice:

> Written in 2015 by Sebastiano Vigna (vigna@acm.org)
>
> To the extent possible under law, the author has dedicated all copyright
> and related and neighboring rights to this software to the public domain
> worldwide.
>
> Permission to use, copy, modify, and/or distribute this software for any
> purpose with or without fee is hereby granted.
> THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
> WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
> MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
> ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
> WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
> ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
> IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

## Hall of Light inspiration

Portals — Ethan Mollick / emollick/ai-portals, commit
`210133f4e718acb7b461f2a40c90661a40a2397f`, `src/parts/million-mirrors.js` and
`src/worlds/million-mirrors.js`, CC BY-NC-SA 4.0. Analytical-room reflection and
mirror-hall composition informed newly authored Aether implementations. See
PROVENANCE.md for changes and exclusions. Preserve LICENSE when distributing.
