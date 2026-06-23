# Reinforced Jokers — full joker audit

Goal: a stacked joker (count N) should behave exactly like N separate copies.

The mod scales a stacked joker via:
1. Its returned effect table — additive keys ×N, multiplicative keys ^N.
2. `ease_dollars()` side-effect money ×N (during that joker's calculate).
3. `Card:calculate_dollar_bonus` (end-of-round money) ×N.

That covers any joker whose effect flows through a returned scalable field or through money. What it can NOT reach: effects delivered by other one-shot side effects (creating/destroying cards, leveling hands, granting slots/hands, editing other cards) — those run once regardless of N.

## Bottom line

- **~100 jokers work correctly**, including essentially all scoring jokers (mult / chips / x_mult / retrigger).
- **Self-scaling jokers** (Green Joker, Ride the Bus, Glass, Hologram, Obelisk, Vampire, Yorick, Caino, etc.) are **correct in total output** — the ^N/×N scaling exactly compensates for the counter growing once per trigger. The only artifact is cosmetic: the number printed on the card shows one copy's growth, not the scaled value.
- **Probabilistic jokers** work in expected value but with different variance (one scaled roll instead of N independent rolls).
- **~25 jokers underscale** because they deliver their effect via a non-money side effect.

## Fixed by the money hooks (now correct)
Mail-In Rebate, Faceless Joker, Delayed Gratification, Trading Card, Matador, To Do List (ease_dollars); Golden Joker, Cloud 9, Rocket, Satellite (calculate_dollar_bonus).

## Still underscaling — side effect runs once (candidates for a per-stack loop)

**Creates cards (makes 1, should make N):** Marble Joker, 8 Ball, DNA, Sixth Sense, Superposition, Seance, Riff-raff, Vagabond, Hallucination, Certificate, Cartomancer, Perkeo, Invisible Joker.

**Levels a poker hand once:** Space Joker, Burnt Joker.

**Edits cards once:** Hiker (+perma chips per card), Gift Card (sell value to others), Midas Mask (gold-ifies — idempotent, stacking adds nothing).

**Destroys jokers (eats 1, should eat N):** Ceremonial Dagger, Madness. (Both also have a scalable scoring half that DOES scale — only the destruction underscales.)

**Slots / hands / discards via add_to_deck (applied once, or applied then removed when the duplicate dissolves):** Burglar, Turtle Bean, To the Moon, Juggler, Drunkard, Troubadour, Merry Andy, Stuntman (hand-size half), Oops! All 6s.

**Tags:** Diet Cola (one Double tag).

## Approximate (expected value ~right, variance differs)
Misprint, Business Card, Reserved Parking, Bloodstone, Gros Michel (extinction roll), 8 Ball, Space Joker, Hallucination.

## Special cases
- **Joker Stencil** — counts empty joker slots; a stacked card occupies 1 slot, not N, so its X-mult base is slightly off.
- **Blueprint / Brainstorm** — work as intended: a 2x Blueprint copies the neighbor's effect twice (like a Blueprint chain). If the copied joker is itself a side-effect joker, that side effect still fires once.

## N/A — passive identity, stacking is meaningless
Four Fingers, Credit Card, Chaos the Clown, Pareidolia, Splash, Shortcut, Showman, Smeared Joker, Astronomer, Egg, Mr. Bones, Luchador, Chicot.

## Display caveat (correct output, wrong on-card number)
All self-scaling counters: Green Joker, Ride the Bus, Red Card, Square Joker, Runner, Glass Joker, Hologram, Obelisk, Vampire, Yorick, Caino, Hit the Road, Constellation, Lucky Cat, Flash Card, Spare Trousers, Castle, Campfire, Ramen, Stone Joker, Wee Joker, Throwback, Ice Cream, Popcorn.
