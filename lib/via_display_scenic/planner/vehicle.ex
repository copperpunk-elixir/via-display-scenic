defmodule ViaDisplayScenic.Planner.Vehicle do
  require ViaUtils.Shared.ValueNames, as: SVN
  defstruct [SVN.position_rrm(), SVN.yaw_rad(), SVN.groundspeed_mps()]

  @spec new(struct(), number(), number()) :: struct()
  def new(positon_rrm, yaw_rad, groundspeed_mps) do
    %ViaDisplayScenic.Planner.Vehicle{
      SVN.position_rrm() => positon_rrm,
      SVN.yaw_rad() => yaw_rad,
      SVN.groundspeed_mps() => groundspeed_mps
    }
  end
end
