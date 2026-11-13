# rsg-gangmenu – Docs (v3.0.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `oxmysql`, `rsg-inventory`; exports `AddGangMoney`, `RemoveGangMoney`, `GetGangAccount` |
| `shared/config.lua` | Locations, keybind, limits |
| `client/client.lua` | Prompts, blips, NUI bridge, `/gangmenu` |
| `server/server.lua` | Members, hire/fire/grade, stash, gang bank, `/removegang` |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI (`index.html`, `style.css`, `script.js`) |
| `locales/*.json` | en, cs, de, el, es, fr, it, pl, pt-br |

## 2. How it works
- Gang bosses manage members (online and offline), promote/demote, and fire with confirmation.
- Recruiting: nearby players must accept an invite.
- Shared gang stash through rsg-inventory, named `gang_<name>`.
- Gang bank in `management_funds` (type `gang`): deposit and withdraw cash.
- `/gangmenu` opens member management and hiring from anywhere; stash and money stay locked to the gang location.
- Optional blips, shown to everyone or only to gang members.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Blip` | table | Sprite and scale |
| `Keybind` | `'J'` | Open key |
| `StorageMaxWeight` / `StorageMaxSlots` | `4000000` / `50` | Stash size |
| `InteractDistance` | `5.0` | Server-side max distance to use stash/money |
| `HireDistance` | `10.0` | Max boss-to-recruit distance |
| `MaxTransaction` | `1000000` | Max single deposit/withdraw |
| `GangLocations` | list | `{ id, name, blipname, coords, showblip, blipforall }` |

`id` must match the gang name in your gangs data (`rsg-core/shared/gangs.lua`).

## 4. Exports, events and commands
| Name | Side | Notes |
|---|---|---|
| `GetGangAccount(account)` | server export | Gang balance |
| `AddGangMoney(account, amount)` | server export | Add to a gang account |
| `RemoveGangMoney(account, amount)` | server export | Remove from a gang account |
| `rsg-gangmenu:client:mainmenu` | client event | Open the menu |
| `rsg-gangmenu:server:openinventory` | server event | Open the gang stash |
| `rsg-gangmenu:server:withdrawMoney` / `depositMoney` | server events | `(amount)` |
| `rsg-gangmenu:server:GetAccount` | callback | Gang balance |
| `rsg-gangmenu:server:GetEmployees` | callback | Member list |
| `rsg-gangmenu:server:GradeUpdate` | server event | `(data)` |
| `rsg-gangmenu:server:FireMember` | server event | `(citizenid)` |
| `rsg-gangmenu:server:HireMember` | server event | `(recruit)` |
| `rsg-gangmenu:server:GetNearbyPlayers` | callback | Recruit candidates |

| Command | Who | What |
|---|---|---|
| `/gangmenu` | gang boss | Manage members and hire from anywhere |
| `/removegang [id]` | admin | Remove a player from their gang |

## 5. Database
Uses `management_funds` (`job_name`, `amount`, `type`), created by the rsg-core SQL; this resource uses rows with `type = 'gang'`.

## 6. Security
Every action re-checks boss status and the real gang on the server. Stash and gang names are never taken from the client. Stash and money need proximity to that gang's location. Amounts are sanitised, capped and rate limited. Promote/fire only within your gang and not above your grade. Hire re-checks distance before and after the invite. Optional logging through rsg-log.

## 7. How-tos
- Add a gang: add it to your gangs data, then add a `GangLocations` entry with the same `id`.
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| No prompt | The gang name must match `id` and the player must be a boss grade |
| Placeholder gang1 at 0,0,0 | Replace the example location in `GangLocations` |
| Stash won't open | Stand within `InteractDistance` of the location |

Support the Project : https://rexshack.tebex.store/
