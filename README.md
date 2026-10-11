# rsg-gangmenu

A gang boss management menu for **RedM** servers running the **RSG Framework**. Gang bosses can manage members, recruit nearby players, use a shared gang stash and look after a shared gang bank account. All of these actions are checked on the server.

---

## Features

- **Member management**
  - View every gang member, online 🟢 or offline ❌, sorted by rank
  - Promote or demote online members to any grade up to your own
  - Fire members, online or offline, after a confirmation prompt
  - You can't edit yourself or anyone who outranks you
- **Recruitment**
  - Lists players near you (default 10m)
  - The recruit gets an invite and must **accept** before joining
- **Gang stash**
  - Shared inventory per gang (`gang_<gangname>`) using `rsg-inventory`
  - Weight and slot count can be set in the config
- **Gang bank account**
  - Deposit and withdraw cash, saved to the `management_funds` table
  - Amounts must be whole numbers within a configurable limit, with a cooldown between transactions
- **Map blips** (optional), shown to everyone or only to that gang's members
- **`/gangmenu` command** to manage members and hire from anywhere
- **Admin command** `/removegang [id]` removes a player from their gang
- **Logging** through `rsg-log` for deposits, withdrawals, hires and firings
- **ox_lib** menus, dialogs and notifications
- **Locales**: en, de, fr, es, it, pl, cs, el, pt-br

### Security

- Every action checks on the server that the player is the boss of a real gang
- The server works out the stash name and gang name; it never trusts what the client sends
- The stash and money only work within `Config.InteractDistance` of your gang's location
- Database queries use parameters, so they can't be injected
- Money amounts are sanitised, capped and rate limited
- You can only promote, demote or fire members of your own gang who don't outrank you
- Recruiting checks distance and needs the target to accept

---

## Dependencies

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework |
| [ox_lib](https://github.com/overextended/ox_lib) | Menus, dialogs, notifications, callbacks, locales |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Gang stash |
| rsg-log *(optional)* | Discord or server logging |

---

## Installation

1. Download the resource and place it in your resources folder, e.g. `resources/[rsg]/rsg-gangmenu`.
2. Make sure the `management_funds` table exists. It ships with rsg-core and is shared with rsg-bossmenu. If you don't have it, run:

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

3. Add it to your `server.cfg` **after** its dependencies:

   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-gangmenu
   ```

4. Make sure each gang exists in `rsg-core/shared/gangs.lua`, and that its boss grade has `isboss = true`.
5. Add your gang locations to `shared/config.lua` (see below) and restart the server.

---

## Configuration

All settings live in `shared/config.lua`.

```lua
Config.Blip = {
    blipSprite = 'blip_honor_bad', -- blip sprite name
    blipScale  = 0.2               -- blip size
}

Config.Keybind          = 'J'      -- key to open the menu at a gang location (from RSGCore.Shared.Keybinds)
Config.StorageMaxWeight = 4000000  -- gang stash max weight
Config.StorageMaxSlots  = 50       -- gang stash slots
Config.InteractDistance = 5.0      -- max distance (server-checked) from the location to use stash / money
Config.HireDistance     = 10.0     -- max distance between boss and recruit
Config.MaxTransaction   = 1000000  -- max single deposit / withdrawal
```

### Gang locations

```lua
Config.GangLocations = {
    {
        id         = 'odriscoll',               -- MUST match the gang name in rsg-core/shared/gangs.lua
        name       = "O'Driscoll Boss Menu",    -- prompt text ("Open <name>")
        blipname   = "O'Driscoll Hideout",      -- blip label
        coords     = vector3(-1234.5, 456.7, 89.0),
        showblip   = true,                      -- show a blip on the map
        blipforall = false                      -- true = everyone sees it, false = gang members only
    },
}
```

> ⚠️ The `id` must exactly match the gang name. The server uses it to check that a boss is at **their own** gang's location before opening the stash or the money menu.

### Locales

Language files are in `locales/*.json`. To choose the language, set ox_lib's locale convar in `server.cfg`:

```cfg
setr ox:locale en
```

---

## Usage

### For gang bosses

**At your gang location:** walk up to the location and press the prompt key (default **J**). This opens the full menu:

| Option | Description |
|---|---|
| **Manage Members** | View members, change their grade, or fire them |
| **Hire Gang Members** | Invite a nearby player; they must accept |
| **Storage Access** | Open the shared gang stash |
| **Money Management** | Check the balance, then deposit or withdraw cash |

**Anywhere:** type `/gangmenu` to manage members and hire. The stash and money only open at the gang location.

### Rules

- Only players with `isboss = true` for their gang grade can use the menu.
- You can't set anyone to a grade above your own, or act on someone who outranks you.
- You can't fire or edit yourself.
- Grade changes need the member to be online. You can fire members whether they're online or offline.

### For admins

```
/removegang [player id]
```

Removes an online player from their gang. Requires the `admin` permission.

---

## Exports (server)

Other resources can use these to work with gang accounts:

```lua
-- get balance
local balance = exports['rsg-gangmenu']:GetGangAccount('odriscoll')

-- add money (returns true/false)
exports['rsg-gangmenu']:AddGangMoney('odriscoll', 500)

-- remove money (returns false if the balance is too low)
if exports['rsg-gangmenu']:RemoveGangMoney('odriscoll', 250) then
    -- success
end
```

---

## License

GPL-3.0. See [LICENSE](LICENSE).
