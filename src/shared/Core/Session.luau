--!strict
-- Session - who may write a player's save. Pure.
--
-- A stored record is { data = <profile>, lock = { job, t }? }. A server takes
-- the lock when the player joins, refreshes `t` on every save and clears it on
-- leave. A second server that finds a live lock must NOT load at once: two
-- servers writing one profile is how items get duplicated and progress gets
-- rolled back.
--
-- A lock can be left behind (the server crashed, or was stopped before its
-- last save landed). Three rules stop that from locking a player out:
--   1. a lock nobody refreshed for TIMEOUT seconds is dead
--   2. a lock we have waited on for STEAL_AFTER seconds is taken over. That is
--      safe because the old server's next save sees a foreign lock and refuses
--      to write (see `owns`), so there is still only one writer
--   3. Studio play sessions take each other's locks at once: they use their own
--      store, and a new session starting means the last one has ended

local Session = {}

-- Seconds a lock is honoured without a refresh. Autosave runs every couple of
-- minutes, so a lock older than this belongs to a server that is gone.
Session.TIMEOUT = 600

-- Seconds a joining server waits for a live-looking lock to be released before
-- it takes the profile over. A normal server hop releases in a few seconds
-- (one queued write plus retries), so anything still locked after this is a
-- server that will never release.
Session.STEAL_AFTER = 30

-- Seconds between looks at a busy lock.
Session.POLL = 3

local STUDIO = "studio-"

export type Lock = { job: string, t: number }

--- The job id a Studio play session uses (a live server uses game.JobId).
function Session.studioJob(guid: string): string
	return STUDIO .. guid
end

--- Is `job` a Studio play session?
function Session.isStudio(job: string): boolean
	return string.sub(job, 1, #STUDIO) == STUDIO
end

--- May server `job` take (or keep) the lock at time `now`, having already
--- waited `waited` seconds for it to be released?
function Session.canAcquire(lock: Lock?, job: string, now: number, waited: number?): boolean
	if lock == nil then
		return true
	end
	if lock.job == job then
		return true
	end
	if now - lock.t > Session.TIMEOUT then
		return true
	end
	if Session.isStudio(job) and Session.isStudio(lock.job) then
		return true
	end
	return (waited or 0) >= Session.STEAL_AFTER
end

--- Does server `job` hold the lock right now? A missing lock is NOT ours: it
--- means another server released it after taking it from us.
function Session.owns(lock: Lock?, job: string): boolean
	return lock ~= nil and lock.job == job
end

--- Seconds to wait before retry number `attempt` (1-based): 1, 2, 4, 8, capped.
function Session.backoff(attempt: number): number
	return math.min(2 ^ (attempt - 1), 8)
end

return Session
