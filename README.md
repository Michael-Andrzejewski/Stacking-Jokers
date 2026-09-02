# Stacking Jokers

By **Soareverix**.

A Balatro mod that keeps **Showman** permanently active and lets duplicate Jokers **stack** instead of taking a new slot. Pick up a Joker you already own and it folds into the copy you have, bumping a stack counter, so you can run a **3x Photograph** or a **2x Chad**. A stacked Joker applies its effect once per stack.

Built on commission for [Bean](https://www.youtube.com/@BeanBalatro).

## How it works

- **Always-on Showman:** duplicates always show up in the shop and packs.
- **Combine on pickup:** acquiring a Joker you already own removes the new card and increments a stack count on the existing one (with a little juice for feedback). A duplicate can be bought, or picked from a Buffoon pack, even at full slots; the button reads "Reinforce".
- **Stacking = effect x stack:** when a stacked Joker scores, its effect is scaled by the stack. Additive fields (mult, chips, money, retriggers) multiply by N; multiplier fields (x_mult, x_chips) raise to the power N. So 3x Photograph is X2^3 = **X8**, and 2x Chad retriggers 2 x 2 = **4** times.
- **Side-effect Jokers** (create cards, level hands, change hands/discards, etc.) repeat their effect N times. **Money** Jokers pay N times. **Passive** Jokers (hand size, discards, interest, probabilities) count N times and stay balanced through boss-blind debuffs. See [AUDIT.md](AUDIT.md) for the full per-Joker breakdown.
- The stack count shows on the Joker's tooltip as "Reinforced xN".

All behaviours can be toggled in the mod config.

## Owned Jokers also appear as Common

Off by default. Common Jokers stack much more than Rares only because the shop rolls them far more often. With this on, every Joker you own is also added to the **Common** pool, so once you have a Baron, further Barons show up about as often as a second Joker would. The card keeps its real rarity badge and price; only how often it is rolled changes. It applies to the shop, Buffoon packs, and Judgement.

## Requirements

- [Lovely](https://github.com/ethangreen-dev/lovely-injector) and [Steamodded](https://github.com/Steamodded/smods) (1.0.0-beta or newer).

## Install

```
cd %AppData%\Balatro\Mods
git clone https://github.com/Michael-Andrzejewski/Stacking-Jokers.git StackingJokers
```

## Debug hotkeys

The stacking rules for passives, debuffs, and copies rarely come up in normal play. Turn on **Debug hotkeys** in the mod config, start a run, and use:

- **F6** gives the test set (2x Juggler, 2x Turtle Bean, 2x Faceless Joker, 2x Invisible Joker, 3x Photograph) and $100.
- **F7** debuffs every Joker you own, or restores them. This is what Crimson Heart does to one Joker per hand. Hand size, discards, and interest should return to the same numbers after a debuff and restore.
- **F8** puts a duplicate of your first Joker into the open booster pack, or into the shop, so you can test "Reinforce" at full slots.
- **F9** shows one line of state on screen and in the log: hand size, discards, interest, and each Joker's stack, rounds, or counter.

While debug is on, every Joker tooltip also shows the current hand size, discards, and interest. The same actions are available as Lua functions for a console or bot bridge: `StackingJokers.give()`, `StackingJokers.debuff()`, `StackingJokers.spawn_dup()`, `StackingJokers.state()`.

## Known limitations

- **A stack sells once**, for one copy's sell value. Reinforcing is a money sink.
- **Ankh and Invisible Joker** copy one Joker, not the whole stack; the copy folds back in, so a stack of N becomes N + 1.
- **Ceremonial Dagger / Madness** destroy one Joker per blind by design; their accumulated mult / x_mult scales with the stack.
- **Probabilistic Jokers** (Misprint, Business Card, Bloodstone, etc.) match in expected value but with different variance than N separate copies.
- The incoming duplicate's edition and eternal/perishable/rental stickers are dropped; the kept copy wins. Combining is by Joker type, ignoring edition.
- Self-scaling Jokers (Green Joker, Ride the Bus, etc.) apply the correct scaled total; the number printed on the card shows the base counter.

A full audit of every vanilla Joker is in [AUDIT.md](AUDIT.md).
