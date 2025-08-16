# Panda Probs

A generic-ish video poker calculator implemented in Zig.

## Motivation

Calculating optimal strategy for video poker is a challenging combinatorial problem. A brute-force approach would require evaluating:

- $\binom{52}{5} \approx 2.6 \times 10^6\$ unique initial 5-card hands.
- For each hand, 32 possible ways to hold.
- For each discard choice, $\binom{47}{0}\ to \binom{47}{5}$ possible replacements.

An upper bound on the number of hands to consider:

$$\binom{52}{5} \times 32 \times \binom{47}{5} \approx 1.3 \times 10^{14}$$

## Performance

This app uses optimizations inspired by [Wizard of Odds’ methodology](https://wizardofodds.com/games/video-poker/methodology/) to reduce the search space and runs in **<1 second** on a Macbook Pro M1.

## Usage

```bash
make run-fast
```
