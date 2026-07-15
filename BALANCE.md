# Rogue 6502 — Combat & Stats Balance Reference

All values below reflect the current code. Edit the source files listed to change them.

---

## Combat System

JRPG-style flat ATK/DEF with accuracy check. No dice rolls for damage.

### Player Attack Formula

```
Hit check:  rng(100) < (85 + player_agility - monster_evasion)
Damage:     weapon_power + enchantment + player_str - monster_def +/- 1
            (minimum 1 damage on a hit)
```

**Source:** `combat.asm` → `player_attack_monster`

### Monster Attack Formula

```
Monsters always hit (no miss chance).
Damage:     monster_atk - (armor_defense + enchantment + player_def) +/- 1
            (minimum 1 damage)
```

**Source:** `combat.asm` → `monster_attack_player`

---

## Player Stats

| Stat | Starting Value | Source |
|------|---------------|--------|
| HP | 12 | `constants.asm` → `START_HP` |
| Max HP | 12 | `constants.asm` → `START_MAX_HP` |
| STR bonus | 0 | `constants.asm` → `START_STR` |
| DEF bonus | 0 | `constants.asm` → `START_DEF` |
| Agility | 10 | `constants.asm` → `START_AGI` |
| Level | 1 | `constants.asm` → `START_LEVEL` |
| XP | 0 | `constants.asm` → `START_XP` |
| Hunger | 200 | `constants.asm` → `START_HUNGER` |
| Gold | 0 | `constants.asm` → `START_GOLD` |

Starting equipment: Mace (+1 enchantment), Leather Armor (+0 enchantment)

---

## Weapons

**Source:** `data/items.asm` → `weapon_power`

| Weapon | ATK Power | Notes |
|--------|-----------|-------|
| Dagger | 4 | Weakest; light backup |
| Mace | 6 | Starting weapon |
| Short Sword | 7 | Slight upgrade |
| Battle Axe | 9 | Early-mid |
| Long Sword | 10 | Mid-tier |
| Morning Star | 11 | Mid-tier |
| War Hammer | 12 | Heavy hitter |
| Halberd | 14 | Late-game reach |
| Two-Hand Sword | 15 | Best weapon |

Enchantment modifier adds directly to ATK (+1, +2, etc). Found weapons spawn with +1 enchantment.

Bare hands: 2 ATK (`constants.asm` → `DEFAULT_WEAPON_POWER`).

---

## Armor

**Source:** `data/items.asm` → `armor_defense`

| Armor | DEF | Notes |
|-------|-----|-------|
| Padded Armor | 3 | Weakest |
| Leather Armor | 4 | Starting armor |
| Studded Armor | 5 | Slight upgrade |
| Ring Mail | 6 | Early upgrade |
| Scale Mail | 8 | Mid-game |
| Banded Mail | 9 | Mid-game |
| Chain Mail | 10 | Late-game |
| Splint Mail | 11 | Late-game |
| Plate Mail | 12 | Best armor |

Enchantment modifier adds directly to DEF. Found armor spawns with +0 enchantment.

---

## Monsters

**Source:** `data/monsters.asm`

| Monster | HP | ATK | DEF | Evasion | XP | Floors | Behavior |
|---------|-----|-----|-----|---------|-----|--------|----------|
| Bat (B) | 3 | 2 | 0 | 30 | 1 | 0-2 | Erratic, sleeps |
| Snake (S) | 5 | 3 | 0 | 20 | 2 | 0-2 | Aggressive |
| Emu (E) | 6 | 4 | 1 | 5 | 2 | 0-2 | Aggressive |
| Hobgoblin (H) | 8 | 5 | 2 | 5 | 3 | 0-2 | Aggressive |
| Zombie (Z) | 14 | 6 | 3 | 0 | 6 | 0-4 | Aggressive |
| Centaur (C) | 20 | 9 | 4 | 10 | 15 | 3-6 | Aggressive |
| Wraith (W) | 18 | 8 | 3 | 20 | 55 | 5-7+ | Aggressive |
| Troll (T) | 28 | 12 | 5 | 5 | 50 | 5-7+ | Aggressive |
| Griffin (G) | 40 | 16 | 7 | 10 | 100 | 7+ | Aggressive |

Monster HP is flat (no dice roll at spawn).

### Monster Spawn Tiers

- Floors 0-2: Bat, Emu, Hobgoblin, Snake, Zombie (5 types)
- Floors 3-4: + Centaur (6 types)
- Floors 5-6: + Troll, Wraith (8 types)
- Floors 7+: + Griffin (all 9 types)

72% chance of a monster per room. Max 10 per floor. Aggressive monsters start awake; Bat sleeps until player is within 5 tiles.

---

## Hit Rate Examples

Base hit chance: 85% (`constants.asm` → `BASE_HIT_CHANCE`)

| Target | Evasion | Hit Chance (Level 1, AGI 10) |
|--------|---------|------------------------------|
| Bat | 30 | 65% |
| Snake | 20 | 75% |
| Emu | 5 | 90% |
| Hobgoblin | 5 | 90% |
| Zombie | 0 | 95% |
| Centaur | 10 | 85% |
| Wraith | 20 | 75% |
| Griffin | 10 | 85% |

Minimum hit chance: 5%. Agility grows +2 every odd level.

---

## Expected Combat Outcomes (Level 1, Mace +1, Leather Armor)

Player effective ATK: 6 + 1 (enchant) + 0 (str) = 7
Player effective DEF: 4 + 0 (enchant) + 0 (def bonus) = 4

| Monster | Player DMG/hit | Hits to kill | Monster DMG/hit | Hits to kill player |
|---------|---------------|-------------|-----------------|---------------------|
| Bat | 7-0 = 7 | 1 | 2-4 = 1 (min) | 12 |
| Snake | 7-0 = 7 | 1 | 3-4 = 1 (min) | 12 |
| Emu | 7-1 = 6 | 1 | 4-4 = 1 (min) | 12 |
| Hobgoblin | 7-2 = 5 | 2 | 5-4 = 1 | 12 |
| Zombie | 7-3 = 4 | 3-4 | 6-4 = 2 | 6 |

---

## Level Up System

**Source:** `combat.asm` → `check_level_up`

### XP Thresholds

| Level | XP Required |
|-------|------------|
| 2 | 10 |
| 3 | 20 |
| 4 | 40 |
| 5 | 80 |
| 6 | 160 |
| 7+ | 255 (cap) |
| Max | 12 |

### Level Up Effects

1. **Max HP +5** (flat, predictable)
2. **Current HP fully healed** to new max
3. **STR bonus +1** every level (adds to weapon damage)
4. **DEF bonus +1** every even level (adds to armor defense)
5. **Agility +2** every odd level (adds to hit chance)

### Scaling Per Level

| Level | STR | DEF | AGI | Max HP | Hit vs Bat | Hit vs Zombie |
|-------|-----|-----|-----|--------|-----------|--------------|
| 1 | 0 | 0 | 10 | 12 | 65% | 95% |
| 2 | 1 | 1 | 10 | 17 | 65% | 95% |
| 3 | 2 | 1 | 12 | 22 | 67% | 97% |
| 4 | 3 | 2 | 12 | 27 | 67% | 97% |
| 5 | 4 | 2 | 14 | 32 | 69% | 99% |

---

## Items

### Potions (6 types)

**Source:** `items.asm` → `item_use`

| Potion | Effect |
|--------|--------|
| Healing | Restore 25% max HP |
| Extra Healing | Restore 50% max HP |
| Strength | +1 permanent STR bonus |
| Poison | -1 permanent STR bonus |
| Confusion | Random movement for 10 turns |
| Blindness | Can't see (fog suppressed) for 15 turns |

### Wands (4 types)

Auto-target nearest awake monster within 8 tiles. Charges: 3-8 (random at spawn).

| Wand | Effect |
|------|--------|
| Teleport Away | Move target to random room |
| Slow Monster | Target skips 50% of turns (permanent) |
| Fire | Deal 8 damage |
| Lightning | Deal 12 damage |

### Item Spawn Rates

Per room: Gold 50%, Food 25%, Equipment 45%.

Equipment distribution: Potion 40%, Weapon 20%, Armor 20%, Wand 20%.

---

## Status Effects

**Source:** `constants.asm`, `hunger.asm` → `status_update`

| Effect | Flag | Duration | Behavior |
|--------|------|----------|----------|
| Confusion | `STATUS_CONFUSED` | 10 turns | Directional input replaced with random direction |
| Blindness | `STATUS_BLIND` | 15 turns | Fog reveals suppressed; screen goes dark |

Timers decrement once per player turn. Messages shown when effects wear off.

---

## Hunger System

**Source:** `hunger.asm`, `constants.asm`

| Threshold | Value | Effect |
|-----------|-------|--------|
| Full | 200 | Starting value |
| Normal | 150+ | No effect |
| Hungry | 50 | Warning message |
| Weak | 10 | Warning message |
| Starving | 0 | Lose 1 HP per turn |

Food restores 100 hunger + heals 25% max HP.

---

## Dungeon Generation

**Source:** `dungeon.asm`

- 6x6 grid, 64x48 tile map
- 10-20 rooms per floor, 75% chance per grid cell
- L-shaped corridors connecting sequential rooms
- Max dungeon level: 13
- Stairs up in room 0 (except floor 0), stairs down in last room

---

## Dungeon Color Themes

**Source:** `ppu.asm` → `set_level_bg_color`, `data/palettes.asm`

Each floor has a unique color scheme (cycles through 13 themes). Affects background, wall border, and wall fill colors.
