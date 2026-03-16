# Rogue NES — Combat & Stats Balance Reference

All values below reflect the current code. Edit the source files listed to change them.

---

## Player Stats

| Stat | Starting Value | Source File |
|------|---------------|-------------|
| HP | 12 | `constants.asm` → `START_HP` |
| Max HP | 12 | `constants.asm` → `START_MAX_HP` |
| Defense (ascending AC) | 15 | `constants.asm` → `START_DEF` |
| Strength | 16 | `constants.asm` → `START_STR` (not used in combat yet) |
| Level | 1 | `constants.asm` → `START_LEVEL` |
| XP | 0 | `constants.asm` → `START_XP` |
| Hunger | 255 | `constants.asm` → `START_HUNGER` (turns until starving) |
| Gold | 0 | `constants.asm` → `START_GOLD` |

### Player Weapon

| Property | Value | Source |
|----------|-------|--------|
| Weapon | +1,+1 Mace (classic Rogue starting weapon) | `combat.asm` → `player_attack_monster` |
| Damage dice | 1d8 | `combat.asm` line 38-41 |
| Enchantment bonus | +1 to damage | `combat.asm` line 44-45 |
| **Total damage per hit** | **2–9** | 1d8 + 1 |
| To-hit bonus | +1 (weapon) + player_level | `combat.asm` lines 24-28 |

### Player Attack Roll

```
Roll = d20 + player_level + weapon_bonus(1)
Hit if Roll >= monster_armor (ascending AC)
```

At level 1: Roll = d20 + 1 + 1 = d20 + 2 (range 3–22)

### Player Defense

```
Monster roll = d20 + monster_level
Hit if roll >= player_def (15)
```

Classic Rogue equivalent: Ring mail (descending AC 5 → ascending 15)

---

## Monster Stats

All values from `data/monsters.asm`. Classic Rogue source used as reference.

| | Bat (B) | Emu (E) | Hobgoblin (H) | Snake (S) | Zombie (Z) |
|---|---------|---------|----------------|-----------|-------------|
| **HP dice** | 1d8 | 1d8 | 1d8 | 1d8 | 2d8 |
| **HP range** | 1–8 | 1–8 | 1–8 | 1–8 | 1–16 |
| **Defense (asc. AC)** | 17 | 13 | 15 | 15 | 12 |
| **Classic AC (desc.)** | 3 | 7 | 5 | 5 | 8 |
| **Level** | 1 | 1 | 1 | 1 | 2 |
| **Damage** | 1d2 (1–2) | 1d2 (1–2) | 1d8 (1–8) | 1d3 (1–3) | 1d8 (1–8) |
| **XP reward** | 1 | 2 | 3 | 2 | 6 |
| **Behavior** | Erratic (random 50%) | Aggressive | Aggressive | Aggressive | Aggressive |
| **Starts awake?** | No (wakes at dist ≤5) | Yes | Yes | Yes | Yes |

### Monster HP Spawn Logic

HP is rolled as `1d(base_hp)` at spawn. For zombies, `base_hp = 16` so they get 1d16 (1–16), not the classic 2d8 (2–16). This means zombies can spawn with 1 HP — classic Rogue's 2d8 guarantees at least 2.

**Source:** `dungeon.asm` → `spawn_monsters`, lines 612–620

---

## Hit Rate Table

### Player hitting monsters (Level 1)

Player roll: d20 + 2 (level 1 + weapon +1). Needs to meet/exceed monster AC.

| Monster | AC (ascending) | Min d20 to hit | Hit chance |
|---------|---------------|----------------|------------|
| Bat | 17 | 15 | 30% (6/20) |
| Emu | 13 | 11 | 50% (10/20) |
| Hobgoblin | 15 | 13 | 40% (8/20) |
| Snake | 15 | 13 | 40% (8/20) |
| Zombie | 12 | 10 | 55% (11/20) |

### Monsters hitting player (Player def = 15)

Monster roll: d20 + monster_level. Needs to meet/exceed 15.

| Monster | Level | Min d20 to hit | Hit chance |
|---------|-------|----------------|------------|
| Bat | 1 | 14 | 35% (7/20) |
| Emu | 1 | 14 | 35% (7/20) |
| Hobgoblin | 1 | 14 | 35% (7/20) |
| Snake | 1 | 14 | 35% (7/20) |
| Zombie | 2 | 13 | 40% (8/20) |

---

## Expected Combat Outcomes (Level 1 Player vs Monster)

Average hits to kill = monster avg HP ÷ player avg damage per hit (5.5)
Average hits to kill player = player HP (12) ÷ monster avg damage per hit

| Monster | Avg HP | Hits to kill | Player hits to kill (accounting miss) | Monster avg dmg | Hits to kill player | Monster hits to kill (accounting miss) | Advantage |
|---------|--------|-------------|--------------------------------------|-----------------|--------------------|-----------------------------------------|-----------|
| Bat | 4.5 | 0.8 | ~3 turns | 1.5 | 8 | ~23 turns | Player |
| Emu | 4.5 | 0.8 | ~2 turns | 1.5 | 8 | ~23 turns | Player |
| Hobgoblin | 4.5 | 0.8 | ~2 turns | 4.5 | 2.7 | ~8 turns | Player (risky) |
| Snake | 4.5 | 0.8 | ~2 turns | 2.0 | 6 | ~17 turns | Player |
| Zombie | 8.5 | 1.5 | ~3 turns | 4.5 | 2.7 | ~7 turns | Player (dangerous) |

---

## Level Up System

**Source:** `combat.asm` → `check_level_up`

### XP Thresholds

| Level | XP Required | Cumulative monsters needed (approx) |
|-------|------------|--------------------------------------|
| 2 | 10 | ~4–10 monsters |
| 3 | 20 | ~8–20 monsters |
| 4 | 40 | ~16–40 monsters |
| 5 | 80 | ~32–80 monsters |
| 6 | 160 | ~64–160 monsters |
| 7+ | 255 (cap) | — |
| Max | 12 | — |

XP is capped at 255 (8-bit). Thresholds are stored in `xp_thresholds` table.

### Level Up Effects

On level up:
1. **Max HP increases by 2–9** (1d8 + 2) — `combat.asm` lines 248–257
2. **Current HP fully healed** to new max — `combat.asm` lines 260–261
3. **Player level increases by 1** — affects to-hit roll (+1 per level)

### What Level Up Does NOT Change

- **Defense (AC)** — stays at 15 forever (no armor upgrades yet)
- **Damage** — stays at 1d8+1 forever (no weapon upgrades yet)
- **Strength** — `player_str` exists but is not used in combat formulas
- **Hunger rate** — always -1 per turn regardless of level

### Scaling Per Level

| Level | To-hit bonus | Hit rate vs Bat | Hit rate vs Zombie | Avg Max HP |
|-------|-------------|-----------------|--------------------|----|
| 1 | +2 | 30% | 55% | 12 |
| 2 | +3 | 35% | 60% | 17.5 |
| 3 | +4 | 40% | 65% | 23 |
| 4 | +5 | 45% | 70% | 28.5 |
| 5 | +6 | 50% | 75% | 34 |

---

## Hunger System

**Source:** `hunger.asm`, `constants.asm`

| Threshold | Value | Effect |
|-----------|-------|--------|
| Full | 255 | Starting value |
| Normal | 150+ | No effect |
| Hungry | 50 | Warning message shown |
| Weak | 10 | Warning message shown |
| Starving | 0 | Lose 1 HP per turn |

- Hunger decreases by 1 per turn (each player action)
- Food restores 100 hunger + heals 25% max HP
- **255 turns until starving** from full (items disabled currently)

---

## Monster Spawn Rules

**Source:** `dungeon.asm` → `spawn_monsters`

- Monsters spawn in rooms 1+ (never room 0 where player starts)
- 60% chance of a monster per room
- Max 10 monsters per floor
- Monster type is chosen by `pick_monster_type` (based on dungeon level)
- Spawns at center of room
- Aggressive monsters (Emu, Hobgoblin, Snake, Zombie) start awake
- Non-aggressive (Bat) starts asleep, wakes when player is within 5 tiles

---

## Known Balance Issues

1. **Zombie HP roll**: Uses 1d16 instead of classic 2d8 — zombies can spawn with 1 HP (classic guarantees minimum 2)
2. **No healing between fights**: No potions, food disabled — HP only recovers on level up (full heal)
3. **No armor/weapon progression**: Defense and damage are static; only to-hit improves with levels
4. **Strength unused**: `player_str` is tracked but never factors into combat rolls or damage
5. **Single attack per monster**: Classic Rogue monsters can have multiple attack dice per turn (e.g., zombie does 1d8 once; classic does 1d8 per attack)
6. **Bat too hard to hit**: AC 17 (ascending) means level 1 player only hits 30% of the time, but bat only does 1d2 damage — this matches classic Rogue where bats are annoying but harmless
