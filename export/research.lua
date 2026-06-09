local M = {}

function M.collect()
  local techs       = game.forces.player.technologies
  local completed   = {}
  local in_progress = nil

  for name, tech in pairs(techs) do
    if tech.researched then
      completed[#completed + 1] = name
    elseif tech.current_research then
      -- current_research is a LuaTechnology if this tech is actively being researched
      in_progress = name
    end
  end

  -- Fallback: check the force's current_research directly
  if not in_progress then
    local cr = game.forces.player.current_research
    if cr then
      in_progress = cr.name
    end
  end

  table.sort(completed)

  return {
    completed   = completed,
    in_progress = in_progress,
  }
end

return M
