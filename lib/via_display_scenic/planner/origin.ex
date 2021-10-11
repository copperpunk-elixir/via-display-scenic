defmodule ViaDisplayScenic.Planner.Origin do
  require Logger
  require ViaUtils.Shared.ValueNames, as: SVN

  defstruct [:lat_rad, :lon_rad, :dx_lat_scaled, :dy_lon_scaled]

  @spec new(float(), float(), float(), float()) :: struct()
  def new(lat_rad, lon_rad, dx_lat, dy_lon) do
    %ViaDisplayScenic.Planner.Origin{
      lat_rad: lat_rad,
      lon_rad: lon_rad,
      dx_lat_scaled: dx_lat,
      dy_lon_scaled: dy_lon
    }
  end

  @spec get_xy(struct(), float(), float()) :: tuple()
  def get_xy(origin, lat, lon) do
    x = (lat - origin.lat_rad) * origin.dx_lat_scaled
    y = (lon - origin.lon_rad) * origin.dy_lon_scaled
    {x, y}
  end

  @spec get_dx_dy(struct(), struct(), struct()) :: tuple()
  def get_dx_dy(origin, point1, point2) do
    %{SVN.latitude_rad() => p1_lat, SVN.longitude_rad() => p1_lon} = point1
    %{SVN.latitude_rad() => p2_lat, SVN.longitude_rad() => p2_lon} = point2
    x = (p2_lat - p1_lat) * origin.dx_lat_scaled
    y = (p2_lon - p1_lon) * origin.dy_lon_scaled
    {x, y}
  end
end
