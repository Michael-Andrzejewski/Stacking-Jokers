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

## Fixed — money
Mail-In Rebate, Faceless Joker, Delayed Gratification, Trading Card, Matador, To Do List (ease_dollars ×N); Golden Joker, Cloud 9, Rocket, Satellite (calculate_dollar_bonus ×N).

## Fixed — side effects run N times (RJ_REPEAT list)
The whole calculate is re-run N times for these pure side-effect jokers, so the side effect happens once per stack:
- **Create cards:** Marble, 8 Ball, DNA, Sixth Sense, Superposition, Seance, Riff-raff, Vagabond, Hallucination, Certificate, Cartomancer, Perkeo, Invisible Joker.
- **Level a hand:** Space Joker, Burnt Joker.
- **Edit cards:** Hiker (+perma chips ×N per card), Gift Card (sell value ×N), Midas Mask (idempotent).
- **Tag / hands:** Diet Cola (N tags), Burglar (hands/discards ×N).

## Fixed — slots / hands / discards (merge keeps the passive)
On merge the absorbed duplicate's add_to_deck passive is kept (not undone on dissolve); the surviving stack undoes it N times when sold. Symmetric with vanilla remove_from_deck: Juggler, Drunkard, Merry Andy, Turtle Bean, Stuntman, To the Moon, Troubadour, Oops! All 6s.

## Handled by design — mixed self-scaling + destroy
**Ceremonial Dagger, Madness — work as intended.** Both destroy exactly one joker per blind (by design), but their accumulated scaling is multiplied by the stack. Ceremonial Dagger returns mult_mod = ability.mult, scaled x N (eat a $4 joker for +8, and a 2x dagger applies +16, a 3x +24). Madness returns Xmult_mod = ability.x_mult, scaled ^ N. The on-card number shows the base counter; the applied value is scaled.

## Approximate (expected value ~right, variance differs)
Misprint, Business Card, Reserved Parking, Bloodstone, Gros Michel (extinction roll), 8 Ball, Space Joker, Hallucination.

## Special cases
- **Joker Stencil** — counts empty joker slots; a stacked card occupies 1 slot, not N, so its X-mult base is slightly off.
- **Blueprint / Brainstorm** — work as intended: a 2x Blueprint copies the neighbor's effect twice (like a Blueprint chain). If the copied joker is itself a side-effect joker, that side effect still fires once.

## N/A — passive identity, stacking is meaningless
Four Fingers, Credit Card, Chaos the Clown, Pareidolia, Splash, Shortcut, Showman, Smeared Joker, Astronomer, Egg, Mr. Bones, Luchador, Chicot.

## Display caveat (correct output, wrong on-card number)
All self-scaling counters: Green Joker, Ride the Bus, Red Card, Square Joker, Runner, Glass Joker, Hologram, Obelisk, Vampire, Yorick, Caino, Hit the Road, Constellation, Lucky Cat, Flash Card, Spare Trousers, Castle, Campfire, Ramen, Stone Joker, Wee Joker, Throwback, Ice Cream, Popcorn.
