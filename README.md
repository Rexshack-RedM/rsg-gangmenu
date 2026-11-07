# rsg-gangmenu

A gang boss management menu for **RedM** servers running the **RSG Framework**. Gang bosses can manage members, recruit nearby players, use a shared gang stash and manage a shared gang bank account. All actions are validated on the server.

## Features

- **Member management** — view online/offline members, promote/demote, fire with confirmation
- **Recruitment** — nearby players (configurable range) must accept an invite
- **Gang stash** — shared inventory `gang_<name>` via rsg-inventory
- **Gang bank** — deposit/withdraw cash in `management_funds` (type `gang`)
- **Map blips** — optional, public or gang-only
- **`/gangmenu`** — manage members and hire from anywhere (stash/money stay location-locked)
- **`/removegang [id]`** — admin remove from gang
- **Logging** via rsg-log (optional)
- **Custom NUI** following the RSG brain design standard (Roboto, monochrome panel, no vignette)

### Security

- Every action re-checks boss status and real gang on the server
- Stash name and gang name are never taken from the client
- Stash and money require proximity to that gang’s configured location
- Amounts are sanitised, capped, and rate-limited
- Promote/fire only within your gang and not above your grade
- Hire re-checks distance before and after the invite prompt

## Dependencies

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework, locale, notify, callbacks |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Gang stash |
| rsg-log *(optional)* | Discord / server logging |

## Installation

1. Place in your resources folder.
2. Ensure `management_funds` exists (ships with rsg-core; shared with rsg-bossmenu):

```sql
CREATE TABLE IF NOT EXISTS `management_funds` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `job_name` VARCHAR(50) NOT NULL,
    `amount` INT(100) NOT NULL,
    `type` ENUM('boss','gang') NOT NULL DEFAULT 'boss',
    PRIMARY KEY (`id`),
    UNIQUE KEY `job_name` (`job_name`),
    KEY `type` (`type`)
);
```

3. `server.cfg` (after dependencies):

```cfg
ensure oxmysql
ensure rsg-core
ensure rsg-inventory
ensure rsg-gangmenu
```

4. Define each gang in `rsg-core/shared/gangs.lua` with a boss grade (`isboss = true`).
5. Add locations in `shared/config.lua` — **`id` must match the gang name**.

Language: `setr rsg:locale "en"` (falls back to `ox:locale`, then `en`).

## Configuration

See `shared/config.lua`:

| Option | Description |
|---|---|
| `Config.Keybind` | Key at location prompts (`RSGCore.Shared.Keybinds`) |
| `Config.StorageMaxWeight` / `StorageMaxSlots` | Stash limits |
| `Config.InteractDistance` | Server max distance for stash / money |
| `Config.HireDistance` | Max boss ↔ recruit distance |
| `Config.MaxTransaction` | Max single deposit / withdraw |
| `Config.GangLocations` | `id`, `name`, `blipname`, `coords`, `showblip`, `blipforall` |

## Usage

- At a gang location: full menu (members, hire, stash, money)
- `/gangmenu`: members and hire only
- `/removegang [id]`: admin

## Exports (server)

```lua
exports['rsg-gangmenu']:GetGangAccount(gangName)
exports['rsg-gangmenu']:AddGangMoney(gangName, amount)
exports['rsg-gangmenu']:RemoveGangMoney(gangName, amount)
```

## Support

RexShack Gaming / RSG Framework
