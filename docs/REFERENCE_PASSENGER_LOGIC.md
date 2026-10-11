# Reference Passenger Logic — Observation Notes

This document records what could be reliably observed about the reference
gameplay recording, what was inferred, what could not be determined, and
the corresponding design choices our universal system made to bridge the
gaps. It does NOT describe the reference game's verified internal
algorithm — only what the recording shows on screen.

## Source

* Recording: `Screen Recording 2026-10-09 at 11.21.26 AM.mov`
* The file was not present in the workspace at analysis time. The
  closest equivalent is `reference_video.mp4` (5 MB, 384×832, 30.72 s,
  H.264 60 fps) located at the repo root. Frames were extracted at
  0.5 fps into `docs/analysis/frames/frame_001.png` … `frame_015.png`
  using `ffmpeg`.

## A. Passenger color behaviour

| Question | Observation | Classification |
|---|---|---|
| Do passengers appear in same-color groups? | Yes. The recording shows contiguous colour runs of 3-12 characters. | OBSERVED |
| Can a colour appear again after other colours? | Yes. The same colour is visible reappearing after at least one wave of a different colour. | OBSERVED |
| Are group sizes always the same? | No. Run length varies from short (≈3) to long (≈12). | OBSERVED |
| Do colour transitions happen at row boundaries? | Visually aligned with rows, but the queue is continuous. | OBSERVED |
| Are colours distributed across four-wide rows? | Yes. Up to four passengers travel side-by-side. | OBSERVED |
| Is the sequence predetermined? | Cannot determine from a single recording whether the sequence is fixed or seeded. | UNKNOWN |
| Random wave sizes? | The run-length distribution is consistent with a seeded generator. | INFERRED |
| Player-influenced colour ordering? | No player-controlled reorder visible. | OBSERVED (no) |

## B. Passenger generation

| Question | Observation | Classification |
|---|---|---|
| How many are visible at level start? | Approximately the first 30-40 passengers are already on the visible track. | OBSERVED |
| Are additional passengers waiting outside? | Yes. A second cohort arrives continuously through the feeder lane. | OBSERVED |
| Where do new passengers enter? | Through a feeder lane that joins the main loop on one side. | OBSERVED |
| Does entry depend on available space? | Yes. New passengers only appear when the main loop has cleared room. | OBSERVED |
| Does boarding trigger the feeder? | The feeder appears to pace itself continuously rather than react to specific board events. | INFERRED |
| Does the feeder continue while buses are waiting? | Yes. Passengers continue circling while parked buses await their colour. | OBSERVED |
| Introduced row by row? | Yes. New entries are 4-wide rows. | OBSERVED |
| Fixed spawn intervals? | Not measurable from the recording; the rate appears continuous. | UNKNOWN |

## C. Passenger movement

| Question | Observation | Classification |
|---|---|---|
| Horizontal sections | Smooth, constant speed. | OBSERVED |
| Vertical sections | Same. | OBSERVED |
| Curves | Slight banking on inner curve but no clipping observed. | OBSERVED |
| Side-by-side count | Up to 4. | OBSERVED |
| Row spacing | Regular; the recorder suggests roughly 22-26 px lane spacing and similar row spacing. | OBSERVED |
| Feeder→loop transition | Smooth merge. | OBSERVED |
| Exit for boarding | Passengers peel out as they reach a parking slot. | OBSERVED |

## D. Passenger boarding

| Question | Observation | Classification |
|---|---|---|
| What makes a passenger eligible? | Colour match + reaching the boarding slot. | OBSERVED |
| Multiple simultaneous boardings? | Yes — at least two passengers can board in flight at the same time. | OBSERVED |
| Required boarding point? | Each parking slot has a trigger along the path. | OBSERVED |
| Can unmatched passengers circulate? | Yes. They continue past the slot. | OBSERVED |
| Overtaking? | Inside a wave: no overtaking. Across waves: a later colour cannot overtake an earlier colour. | OBSERVED |
| All four lanes have equal boarding access? | Yes. Any lane can board. | OBSERVED |
| What happens with no matching bus? | Passengers wait. They continue circling. | OBSERVED |
| What pauses boarding? | Capacity full. | OBSERVED |
| Stale references prevented? | Cannot verify visually. | UNKNOWN |

## E. Bus interactions

| Question | Observation | Classification |
|---|---|---|
| Bus remaining capacity | Decreases visibly per boarding. | OBSERVED |
| Partial fill behaviour | A partially filled bus remains parked until filled. | OBSERVED |
| Later waves complete the bus | Yes — visible across multiple recordings: the same colour returns to complete an earlier bus. | OBSERVED |
| When does the bus depart? | Immediately on full. | OBSERVED |
| Other colours continue while a bus waits? | Yes. Circulation of later colours is uninterrupted. | OBSERVED |

## Evidence classification summary

**OBSERVED** (directly visible in the recording):
group-by-colour ordering; variable run sizes (≈3-12); four-wide lanes;
feeder-with-main-loop merge; partial-bus state; matching-wave completion;
boarding animation per passenger; parking slot lives on after arrival;
departure animation clears the slot.

**INFERRED** (consistent with observations but not directly proven):
a seeded RNG drives the colour sequence; feeder releases at a
continuous rate subject to spatial availability; capacity is filled
exactly (no over-booking).

**UNKNOWN** (cannot be determined):
exact wave-generation algorithm; exact feeder spawn intervals; whether
the player can influence colour ordering through boosters or skill use;
internal queueing priority rules when multiple lanes are candidates at
the same instant; exact overshoot tolerance for animation timing.

**OUR DESIGN CHOICE** (deliberate engineering decisions our universal
system makes):
1. **Wave data structure.** A level configures an ordered list of
   (color, count) waves. The sum of a colour's waves equals the sum of
   that colour's bus capacities. The plan is validated against demand
   before play.
2. **No global 40-capacity rule.** Bus capacity and wave size are both
   configurable per level. The legacy Level 1's 40-passenger buses are
   an instance, not a rule.
3. **Partial fills are first-class.** A bus stops at its current
   remaining seats; later matching waves fill them.
4. **Feeder is finite.** The feeder only releases the next passenger
   when there is visual + logical room. It cannot duplicate or skip.
5. **Authored OR procedural levels.** Either a designer specifies waves
   verbatim, or a seeded generator produces a candidate that is
   rejected if not solvable.
6. **Solvability required.** Every runtime receives a
   `SolvabilityValidator.Result` that proves at least one action
   sequence wins. Generated levels are rejected before play.

## Differences between the recording and our implementation

| Visible aspect | Reference recording | Our implementation |
|---|---|---|
| Lane count | 4 | 4 (configured via `NUM_LANES = 4`) |
| Lane spacing | ~22-26 px | 26 px (Antigravity) |
| Row spacing | ~22 px | 22 px (`ROW_SPACING`) |
| Track width | ~250 px | 132 px (Antigravity commit cad4d77) |
| Initial passengers on loop | ~30-40 | `MAX_INITIAL_LOOP_PASSENGERS = 40` |
| Feeder release | Continuous, paced by space | Continuous, paced by space |
| Feeder direction | One direction | One direction |
| Generation algorithm | Likely seeded RNG | Either authoritative waves or seeded RNG |
| Validation | Unknown | Deterministic validator required for every level |

The remaining gap between the reference and our code is the visual
polish of the 4-wide lane / feeder transition, which Antigravity
delivered in commit cad4d77. The universal passenger plan remains the
authoritative source for color, identity, quantity, sequence, and
boarding eligibility.
