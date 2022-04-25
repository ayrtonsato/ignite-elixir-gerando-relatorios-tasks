defmodule GenReport do
  def build() do
    {:error, "Insira o nome de um arquivo"}
  end

  def build(filename) do
    filename
    |> GenReport.Parser.parse_file()
    |> Enum.reduce(report_acc(), fn line, report -> sum_values(line, report) end)
  end

  def build_from_files(filenames) when not is_list(filenames),
    do: {:error, "Please provide a list of strings"}

  def build_from_files(filenames) do
    filenames
    |> Task.async_stream(&build/1)
    |> Enum.reduce(report_acc(), fn {:ok, line}, report -> merge(line, report) end)
  end

  defp merge(map1, map2) do
    Map.merge(map1, map2, &deep_resolve/3)
  end

  defp deep_resolve(_key, left = %{}, right = %{}) do
    merge(left, right)
  end

  defp deep_resolve(_key, left, right) do
    left + right
  end

  defp sum_values(list, %{
         "all_hours" => all_hours,
         "hours_per_month" => hours_per_month,
         "hours_per_year" => hours_per_year
       }) do
    all_hours = sum_all_hours(list, all_hours)

    %{"hours_per_month" => hm, "hours_per_year" => hy} =
      sum_by_month_and_year(list, hours_per_month, hours_per_year)

    build_report(all_hours, hm, hy)
  end

  defp sum_all_hours([name, hours, _day, _month, _year], all_hours)
       when is_map_key(all_hours, name),
       do:
         all_hours
         |> Map.put(name, all_hours[name] + hours)

  defp sum_all_hours([name, hours, _day, _month, _year], all_hours) do
    all_hours
    |> Map.put(name, hours)
  end

  defp sum_by_month_and_year(
         [name, hours, _day, month, year],
         hours_per_month,
         hours_per_year
       ) do
    %{
      "hours_per_month" => sum_by_period(hours_per_month, name, month, hours),
      "hours_per_year" => sum_by_period(hours_per_year, name, year, hours)
    }
  end

  defp sum_by_period(map, name, period, hours) do
    map_period = create_key(map, name, %{})

    inside_period =
      map_period[name]
      |> create_key(period, 0)
      |> set_key(period, hours)

    map_period
    |> Map.put(name, inside_period)
  end

  defp create_key(map, key, value) when false === is_map_key(map, key),
    do: map |> Map.put(key, value)

  defp create_key(map, _key, _value), do: map

  defp set_key(map, key, value) when is_map_key(map, key),
    do: map |> Map.put(key, map[key] + value)

  defp set_key(map, _key, _value), do: map

  defp report_acc do
    %{"all_hours" => %{}, "hours_per_month" => %{}, "hours_per_year" => %{}}
  end

  defp build_report(all_hours, hours_per_month, hours_per_year),
    do: %{
      "all_hours" => all_hours,
      "hours_per_month" => hours_per_month,
      "hours_per_year" => hours_per_year
    }
end
