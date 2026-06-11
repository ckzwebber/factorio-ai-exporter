local M = {}

function M.collect()
  local force = game.forces.player

  local completed = {}

  for name, tech in pairs(force.technologies) do
    if tech.researched then
      completed[#completed + 1] = name
    end
  end

  table.sort(completed)

  return {
    completed = completed,
    in_progress = force.current_research and force.current_research.name or nil
  }
end

return M
