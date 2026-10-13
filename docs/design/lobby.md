# Lobby, parties and campaign

Status: **proposal** (2026-10-11). Figma mockups: file "Untitled", sections "Lobby UI: world-first" and "Party system".

## The idea

The lobby is a **place you walk around, not a menu.** You make a party in the lobby, and the party teleports together into its **own private server** and plays the campaign there, level after level, until it leaves. No teleport between levels; the next map just loads.

```
Lobby place (public)          Game place (private server, one per party)
  walk around, make a party ──► HQ hub ──► level ──► results ──► HQ hub ──► ...
  step on a pad                  (pick a level)       NEXT / RETRY / HQ
```

Why:
- **Friends stay together.** A session becomes "let's play a few levels", not one round and back to the lobby.
- **It is the level plan we already have.** Diner 1-1 to 1-4, then Pasko sa Barrio, then the third map ([maps.md](maps.md)) read as a campaign.
- **Feels like a real game**, which helps with the "Overcooked ripoff" problem.

## Lobby place

World first. The screen UI is only coins, two buttons, the party bar, and small panels that show while you stand somewhere.

| Thing | What it does |
|---|---|
| **QUICK PLAY pad** | The only pad. Groups strangers who step on it into a temporary party (up to 4) and starts after a short countdown. Same private-server flow, but a short run (see below). |
| **Chef locker** | Walk up, press E / tap: the chef picker slides up and the camera turns to face your chef. Also in the HQ hub. |
| **LobbyHUD** | Coins (top right, clear of the Roblox top bar), INVITE and DAILY (left; above the joystick on mobile). |

Parties don't use a pad: the leader presses START on the party bar. Solo is a party of one pressing START. Same code path, no special mode.

## Party system

### Making a party

All three ways end in the same server-side "join party" call.

1. **Walk up to a player.** A prompt appears: "INVITE TO PARTY" (E / tap). They get a toast: "**Ron** invited you to their party", YES / NO, with a timer bar.
2. **INVITE button** for friends not in the game. It opens Roblox's invite prompt (`SocialService:PromptGameInvite`) with the party code in the launch data. When the friend joins, the server reads it (`Player:GetJoinData()`) and puts them in the party, or teleports them straight into the party's private server if the party is already playing.
3. **JOIN a friend.** If a friend in the same lobby has a party with room, the party bar shows a JOIN chip for it.

Before building: check whether Roblox now has a platform party API we can read (Roblox has been adding party features). If it does, use it for #2 and #3 instead of our own codes.

### While in a party

- **Party bar** (left side, under INVITE / DAILY): up to 4 rows, each with the member's **Roblox avatar headshot** (`Players:GetUserThumbnailAsync`, `HeadShot`; not the chef character), name, a crown icon for the leader, and a ready tick during the ready check. START (leader) and LEAVE at the bottom. An **arrow button** next to it hides the whole bar; collapsed, only the arrow and a member count stay. On mobile the bar is a compact row of heads.
- **Party nameplates:** your party's nameplates turn the party colour, so you can find each other in the lobby.
- **Leader starts.** Leader presses START on the party bar. Everyone gets a short **ready check** ("READY?" banner, YES / NO, a few seconds). If nobody says NO, the whole party teleports together into one private server.
- **Leaving:** LEAVE on the bar anytime. If the leader leaves, the next member (by join order) becomes leader.
- **Kick:** the leader can remove a member from the bar (tap their row). Needed for public lobbies.

### Rules

- Max party size: 4 (Config).
- One pending invite per pair; invites expire after a few seconds (Config). Spamming invites: a short cooldown per sender.
- The server owns parties as data: party id, leader, members, invite code, ready state, as attributes on each player. Clients only draw the bar, nameplates, toasts and the ready check (same rule as everything else: server simulates data, clients render).

## In the private server (campaign)

### HQ hub

Between levels the party is in the **Superchefs HQ**: a small room, not a world map you drive around (Overcooked's bus overworld is its most recognisable part, so we avoid it).

- A **door or poster per level**, with its stars. Locked levels are boarded up.
- The chef locker, a trophy shelf with the party's stars, later cosmetics.
- Walking to a door opens a small panel: level name, stars, START (leader) / "Waiting for leader" (others).
- INVITE works here too, between levels only.

### Results screen

After a level: stars, coins, then **NEXT** (next level), **RETRY**, or **HQ**. The leader picks; others see what the leader is pointing at.

### Progress

- The party plays at the **leader's progress**: their unlocked levels are open.
- **Everyone earns** stars and coins from every level they play.
- Clearing a level **unlocks it for each member who cleared it**, so nobody is locked out by a friend who's behind.
- A player who leaves mid-run keeps everything earned so far. The run continues; their slot is open for an invite.
- If everyone leaves, the server closes.

### Quick Play runs

Strangers don't commit to a whole campaign. A Quick Play party plays **one level** picked from what all members have unlocked (the lowest common), then gets results with **PLAY AGAIN** (another random level, same group) or **LOBBY**.

## Scope

| When | What |
|---|---|
| Demo (Nov) | One level. The pads with "standing on the pad together = party". No HQ. |
| Before freeze (Dec 1) | Full party system (prompts, party bar, invites with launch data, leader handoff, ready check), HQ hub, results NEXT / RETRY / HQ, progress rules. Needs saving ([meta-progression.md](meta-progression.md)). |
| Later | Kick-vote for Quick Play, party chat emotes, a cosmetic party colour pick. |

Ties into [RELEASE-TODO.md](../RELEASE-TODO.md): the game place waits for the whole teleported party before the intro.

## Every new mechanic is a level setting

Nothing here changes rounds. Party and HQ live outside the round, so no `Config.Levels` switches are needed. Tunables (party size, invite timeout, ready-check time, quick-play countdown) go in a new `Config/Lobby.luau`.

## Open questions

- Is the HQ hub its own small map in the game place, or a corner of every level's map? (Own map is simpler.)
- Does Quick Play show up at all for the beta, or only Campaign + Solo? (Low player counts at launch make Quick Play queues empty.)
- Daily reward: in scope for the beta?
