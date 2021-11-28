defmodule ViaDisplayScenic.Messages.Frequencies do
  def freq_list(freq_max \\ 50) do
    Enum.filter(1..freq_max, fn x -> rem(freq_max, x) == 0 end)
  end

  def freq_binary_list() do
    freqs = freq_list()
    for x <- freqs, do: "#{x}"
  end

  def freq_binary_number_tuple() do
    freqs = freq_list()
    for x <- freqs, do: {"#{x}", x}
  end
end
