-- main/game.lua — presentation-side owner of the Sim instance.
-- Holds the single sim, wraps every mutation in apply()+autosave, and
-- implements the boot/resume protocol (docs/m1-contract.md §9).
--
-- PRESENTATION RULE: screens read game.state() and the events returned by
-- game.apply(); nothing here or above pokes sim internals.
--
-- Autosave deviation (orchestrator-approved): sys.save/sys.load with
-- sys.get_save_file("emberdelve","run") replaces defold-saver. Zero deps.

local Sim = require "sim.init"

local M = {}

M.sim = nil

-- Phases from which there is nothing to resume.
local TERMINAL = { idle = true, run_won = true, run_lost = true }

local function save_path()
  return sys.get_save_file("emberdelve", "run")
end

-- Returns the raw saved snapshot table, or nil if absent/unreadable.
function M.load_snapshot()
  local ok, snap = pcall(sys.load, save_path())
  if not ok or type(snap) ~= "table" then return nil end
  if type(snap.phase) ~= "string" then return nil end
  return snap
end

-- Returns the saved snapshot only if it represents a resumable run.
function M.resumable_snapshot()
  local snap = M.load_snapshot()
  if snap and not TERMINAL[snap.phase] then return snap end
  return nil
end

-- Restore the saved run if resumable. Returns the restored phase, or nil.
-- Idempotent: if a sim already exists, just report its phase.
function M.resume()
  if M.sim then return M.sim.phase end
  local snap = M.resumable_snapshot()
  if not snap then return nil end
  local ok, sim = pcall(Sim.restore, snap)
  if not ok or not sim then return nil end
  M.sim = sim
  return sim.phase
end

-- Fresh run. Seed policy: os.time() at the call site (presentation only).
function M.new_run(seed)
  M.sim = Sim.new(seed)
  return M.apply({ type = "start_run" })
end

-- The ONLY mutation path. Autosaves after every apply that returns >=1 event.
function M.apply(cmd)
  if not M.sim then return {} end
  local events = M.sim:apply(cmd)
  if #events > 0 then
    pcall(sys.save, save_path(), M.sim:snapshot())
  end
  return events
end

function M.state()
  if not M.sim then return nil end
  return M.sim:state()
end

function M.phase()
  return M.sim and M.sim.phase or nil
end

return M
