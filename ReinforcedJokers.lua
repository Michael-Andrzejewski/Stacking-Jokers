--[[
  Reinforced Jokers
  Author: Soareverix  (commissioned by Bean)

  Two linked behaviours, both on by default:
    1. Showman is always active, so duplicate Jokers can appear.
    2. Picking up a Joker you already own folds it into the copy you
       have, bumping a stack counter instead of taking a new slot. A
       stacked Joker applies its effect once per stack, so a 3x
       Photograph gives X2^3 = X8 and a 2x Chad retriggers 2 x 2 = 4.

  Stacking model: when a stacked Joker scores, we scale the effect table
  it returns by the stack count (additive fields x N, multiplicative
  fields ^ N, repetitions x N). This matches "N copies of the Joker" for
  the large majority of Jokers (mult, chips, x_mult, money, retriggers).

  Known v1 limits (Bean: scope to the common cases):
    * One-time / create-card / self-scaling Jokers run their side effect
      once per pickup, not once per stack.
    * Editions and eternal/perishable/rental of the *incoming* duplicate
      are dropped; the kept copy's stickers/edition win.
    * Combining is by Joker type (center key), ignoring edition.
--]]

----------------------------------------------------------------------
-- Config
----------------------------------------------------------------------

local rj_mod = SMODS.current_mod

local rj_defaults = {
    enabled            = true,
    always_showman     = true,
    combine_and_stack  = true,
}

if rj_mod then
    rj_mod.config = rj_mod.config or {}
    for k, v in pairs(rj_defaults) do
        if rj_mod.config[k] == nil then rj_mod.config[k] = v end
    end
end

local function rj_cfg()
    return (rj_mod and rj_mod.config) or rj_defaults
end

local function rj_enabled()
    return rj_cfg().enabled ~= false
end

local function rj_stack_of(card)
    return (card and card.ability and card.ability.rj_stack) or 1
end

----------------------------------------------------------------------
-- 1. Always-on Showman
----------------------------------------------------------------------

-- SMODS.showman(key) is the single gate the pool generator checks to
-- allow a card to repeat. Force it true so duplicates always appear.
local rj_orig_showman = SMODS.showman
function SMODS.showman(card_key)
    if rj_enabled() and rj_cfg().always_showman then return true end
    return rj_orig_showman(card_key)
end

----------------------------------------------------------------------
-- 2a. Stacking: scale a stacked Joker's effect by its stack count
----------------------------------------------------------------------

-- Fields that represent an additive bonus (N copies -> value x N).
-- Includes the vanilla "_mod" keys (mult_mod / chip_mod), which most
-- built-in Jokers actually return (e.g. Green Joker uses mult_mod).
local RJ_ADD_KEYS = {
    'mult', 'h_mult', 'mult_mod',
    'chips', 'h_chips', 'chip_mod',
    'dollars', 'p_dollars', 'h_dollars',
    'repetitions',
}
-- Fields that represent a multiplier (N copies -> value ^ N).
local RJ_MUL_KEYS = {
    'x_mult', 'Xmult', 'xmult', 'x_mult_mod', 'Xmult_mod',
    'x_chips', 'xchips', 'Xchip_mod', 'h_x_mult', 'h_x_chips',
}

local function rj_scale_effect(ret, n)
    if type(ret) ~= 'table' or n <= 1 then return ret end
    for _, k in ipairs(RJ_ADD_KEYS) do
        if type(ret[k]) == 'number' then ret[k] = ret[k] * n end
    end
    for _, k in ipairs(RJ_MUL_KEYS) do
        if type(ret[k]) == 'number' and ret[k] ~= 1 then ret[k] = ret[k] ^ n end
    end
    return ret
end

-- Some Jokers apply money as a SIDE EFFECT (ease_dollars) inside their
-- calculate and return only a message, so scaling the return does
-- nothing (e.g. Mail-In Rebate). We track the stack of the Joker that is
-- currently calculating and scale any ease_dollars it triggers. The
-- save/restore makes this correct under nesting (e.g. Blueprint).
local rj_current_stack = 1
-- Track money eased during the current calculate so we can also fix the
-- popup message, which some Jokers build from the un-scaled amount.
local rj_ease_base, rj_ease_scaled = 0, 0

local rj_orig_ease_dollars = ease_dollars
function ease_dollars(amount, ...)
    if rj_enabled() and rj_current_stack > 1 and type(amount) == 'number' then
        rj_ease_base = rj_ease_base + amount
        amount = amount * rj_current_stack
        rj_ease_scaled = rj_ease_scaled + amount
    end
    return rj_orig_ease_dollars(amount, ...)
end

-- Pure side-effect Jokers whose effect is NOT a returned scalable field
-- (they create/destroy/level/edit cards, change hands, drop a tag, etc.).
-- For these we re-run the whole calculate N times so the side effect
-- happens N times. They have no scalable scoring return, so there is
-- nothing to double-count. (Self-scaling and mixed Jokers are NOT here.)
local RJ_REPEAT = {
    -- create cards
    j_marble = true, j_8_ball = true, j_dna = true, j_sixth_sense = true,
    j_superposition = true, j_seance = true, j_riff_raff = true,
    j_vagabond = true, j_hallucination = true, j_certificate = true,
    j_cartomancer = true, j_perkeo = true, j_invisible = true,
    -- level a hand
    j_space = true, j_burnt = true,
    -- edit cards
    j_hiker = true, j_gift = true, j_midas_mask = true,
    -- tag / hands
    j_diet_cola = true, j_burglar = true,
}

-- Card:calculate_joker returns the Joker's effect table (o) plus an
-- optional trigger flag (t). For RJ_REPEAT Jokers we re-run N times;
-- otherwise we scale the returned effect by the stack and expose the
-- stack to ease_dollars for the duration of the call.
local rj_orig_calc_joker = Card.calculate_joker
function Card:calculate_joker(context)
    local n = (rj_enabled() and rj_stack_of(self)) or 1
    local key = self.config and self.config.center_key

    if n > 1 and key and RJ_REPEAT[key] then
        local first_o, first_t
        for i = 1, n do
            local prev = rj_current_stack
            rj_current_stack = 1 -- side effects already repeat; don't also scale
            local o, t = rj_orig_calc_joker(self, context)
            rj_current_stack = prev
            if i == 1 then first_o, first_t = o, t end
        end
        return first_o, first_t
    end

    local prev = rj_current_stack
    rj_current_stack = n
    rj_ease_base, rj_ease_scaled = 0, 0
    local o, t = rj_orig_calc_joker(self, context)
    rj_current_stack = prev
    if n > 1 and type(o) == 'table' then
        rj_scale_effect(o, n)
        -- If the Joker paid via ease_dollars and built a "$<base>" popup
        -- from the un-scaled amount (e.g. Mail-In Rebate), correct it to
        -- the scaled payout so the popup matches the money received.
        if rj_ease_base > 0 and type(o.message) == 'string' then
            local dollar = localize('$')
            if o.message == dollar .. tostring(rj_ease_base) then
                o.message = dollar .. tostring(rj_ease_scaled)
            end
        end
    end
    return o, t
end

-- End-of-round money (Golden Joker, Cloud 9, Rocket, Satellite) is paid
-- through Card:calculate_dollar_bonus, which returns a bare number rather
-- than a scalable effect table. Scale that by the stack too.
local rj_orig_calc_dollar = Card.calculate_dollar_bonus
function Card:calculate_dollar_bonus(...)
    local r = rj_orig_calc_dollar(self, ...)
    if rj_enabled() and type(r) == 'number' then
        local n = rj_stack_of(self)
        if n > 1 then return r * n end
    end
    return r
end

----------------------------------------------------------------------
-- 2b. Combine on pickup
----------------------------------------------------------------------

-- Find an owned Joker of the same type as `card` (excluding `card`
-- itself). Used both to fold a freshly bought duplicate into an existing
-- copy and to detect, in the shop, that a Joker would reinforce.
local function rj_find_match(card)
    if not (G.jokers and G.jokers.cards and card and card.config) then return nil end
    local key = card.config.center_key
    if not key then return nil end
    for _, j in ipairs(G.jokers.cards) do
        if j ~= card and j.config and j.config.center_key == key and not j.getting_sliced then
            return j
        end
    end
    return nil
end

-- Fold `card` into an existing copy if one exists.
local function rj_try_merge(card)
    if not rj_enabled() or not rj_cfg().combine_and_stack then return end
    if not (card and card.ability and card.ability.set == 'Joker') then return end
    if card.getting_sliced then return end
    local target = rj_find_match(card)
    if not target then return end

    target.ability.rj_stack = rj_stack_of(target) + rj_stack_of(card)
    if target.juice_up then target:juice_up(0.5, 0.5) end

    -- Remove the incoming duplicate (animated, like a destroyed Joker).
    -- rj_absorbed tells remove_from_deck NOT to undo this card's passive
    -- (hand size, discards, interest, etc.) -- it stays applied so the
    -- stack keeps N copies' worth. remove_from_deck undoes it N times
    -- when the surviving stack is eventually sold.
    card.getting_sliced = true
    card.rj_absorbed = true
    pcall(function() card:start_dissolve() end)
end

-- Hook add_to_deck so a freshly acquired Joker schedules a merge check
-- AFTER the acquisition flow finishes (avoids touching the card while
-- the buy/open code still references it).
local rj_orig_add_to_deck = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    local res = rj_orig_add_to_deck(self, from_debuff)
    if rj_enabled() and rj_cfg().combine_and_stack
       and self.ability and self.ability.set == 'Joker' then
        local card = self
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.0,
            func = function()
                pcall(function() rj_try_merge(card) end)
                return true
            end,
        }))
    end
    return res
end

-- Balance the passive (hand size / discards / interest / etc.) for stacks.
-- Each copy applied its passive once via add_to_deck. An absorbed
-- duplicate keeps its passive (we skip its removal); the surviving stack
-- of N undoes the passive N times when it leaves play (sold/destroyed).
local rj_orig_remove_from_deck = Card.remove_from_deck
function Card:remove_from_deck(from_debuff)
    if self.rj_absorbed then
        -- This duplicate was merged; its passive now belongs to the stack.
        self.added_to_deck = false
        return
    end
    if rj_enabled() and self.ability and self.ability.set == 'Joker' then
        local n = rj_stack_of(self)
        if n > 1 then
            for _ = 1, n do
                self.added_to_deck = true
                rj_orig_remove_from_deck(self, from_debuff)
            end
            return
        end
    end
    return rj_orig_remove_from_deck(self, from_debuff)
end

----------------------------------------------------------------------
-- 2c. Shop: let a reinforcing duplicate be bought with full slots, and
--     relabel its buy button
----------------------------------------------------------------------

-- A Joker you already own can always be bought, even at full slots,
-- because it folds into the existing copy instead of taking a slot.
local rj_orig_check_space = G.FUNCS.check_for_buy_space
G.FUNCS.check_for_buy_space = function(card)
    if rj_enabled() and rj_cfg().combine_and_stack
       and card and card.ability and card.ability.set == 'Joker'
       and rj_find_match(card) then
        return true
    end
    return rj_orig_check_space(card)
end

-- Swap a buy button's text. The text node is the button root's first
-- child; clearing text_drawable forces it to rebuild on the next update.
local function rj_set_buy_label(e, label, scale)
    local t = e.children and e.children[1]
    if t and t.config and t.config.text ~= label then
        t.config.text = label
        if scale then t.config.scale = scale end
        t.config.text_drawable = nil
        if t.UIBox then t.UIBox:recalculate() end
    end
end

-- can_buy runs on the buy button every frame. After the stock cost
-- check, relabel to "Reinforce" when the card would fold into an owned
-- Joker, and restore "Buy" otherwise.
local rj_orig_can_buy = G.FUNCS.can_buy
G.FUNCS.can_buy = function(e)
    rj_orig_can_buy(e)
    if not (rj_enabled() and rj_cfg().combine_and_stack) then return end
    local card = e.config and e.config.ref_table
    local reinforcing = card and card.ability and card.ability.set == 'Joker'
                        and rj_find_match(card)
    if reinforcing then
        rj_set_buy_label(e, 'Reinforce', 0.38)
    else
        rj_set_buy_label(e, localize('b_buy'), 0.5)
    end
end

----------------------------------------------------------------------
-- 3. Display the stack count on the Joker's tooltip
----------------------------------------------------------------------

local rj_hover_card = nil

local rj_orig_hover = Card.hover
function Card:hover()
    rj_hover_card = self
    return rj_orig_hover(self)
end

local rj_orig_stop_hover = Card.stop_hover
function Card:stop_hover()
    if rj_hover_card == self then rj_hover_card = nil end
    return rj_orig_stop_hover(self)
end

-- generate_card_ui's result.main entries are flat arrays of inline text
-- UIEs (the outer renderer wraps them in rows). Append a "Reinforced xN"
-- line for any stacked Joker.
local rj_orig_gen_card_ui = generate_card_ui
function generate_card_ui(...)
    local args = { ... }
    local card_type = args[4]
    local card = args[9] or rj_hover_card
    local result = rj_orig_gen_card_ui(...)

    if not rj_enabled() or not result or not result.main then return result end
    if card_type ~= 'Joker' then return result end
    if not (card and card.ability and card.ability.set == 'Joker') then return result end

    local n = rj_stack_of(card)
    if n and n > 1 then
        pcall(function()
            table.insert(result.main, {
                { n = G.UIT.T, config = {
                    text = 'Reinforced x' .. tostring(n),
                    scale = 0.34,
                    colour = G.C.RED,
                } },
            })
        end)
    end
    return result
end

----------------------------------------------------------------------
-- Mod config tab
----------------------------------------------------------------------

if rj_mod then
    rj_mod.config_tab = function()
        local cfg = rj_mod.config or rj_defaults
        local function toggle(label, key)
            return { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
                create_toggle({ label = label, ref_table = cfg, ref_value = key }),
            } }
        end
        return {
            n = G.UIT.ROOT,
            config = { align = 'cm', padding = 0.04, colour = G.C.CLEAR },
            nodes = {
                toggle('Enable Reinforced Jokers', 'enabled'),
                toggle('Always-on Showman', 'always_showman'),
                toggle('Combine + stack duplicate Jokers', 'combine_and_stack'),
            },
        }
    end
end
