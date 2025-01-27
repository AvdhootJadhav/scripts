defmodule Main do
  defmodule Stats do
    defstruct [
      :container_id,
      :name,
      :cpu,
      :mem_usage,
      :mem_limit,
      :mem,
      :net_input,
      :net_output,
      :block_input,
      :block_output,
      :pids
    ]
  end

  @conversion %{"KiB" => 1, "MiB" => 2, "GiB" => 3}

  def main() do
    name = "compassionate_moser"

    shell = System.cmd("docker", ["stats", "#{name}", "--no-stream"])
    list = String.split(elem(shell, 0), "\n")
    list = List.delete_at(list, length(list) - 1)

    unless length(list) <= 1 do
      data =
        List.first(tl(list))
        |> String.replace("  ", "")
        |> String.replace(~r"( / )", "/")

      stats = String.split(data, " ") |> get_stats()
      IO.puts("Current stats : #{inspect(stats)}")

      mem_usage = get_floats(stats.mem_usage)
      mem_limit = get_floats(stats.mem_limit)

      mem_check = check_mem_threshold(mem_usage, mem_limit)
      {cpu_usage, _} = get_floats(stats.cpu)

      IO.puts("CPU usage : #{cpu_usage}")
      IO.puts("Is memory overused? - #{mem_check}")

      cond do
        mem_check -> restart_container(name)
        cpu_usage > 50.0 -> restart_container(name)
        true -> IO.puts("Stats seems normal, no restart required")
      end
    end
  end

  def get_stats(data) do
    data = List.to_tuple(data)
    mem_list = String.split(elem(data, 3), "/")
    {mem_usage, mem_limit} = {List.first(mem_list), List.last(mem_list)}
    net_list = String.split(elem(data, 5), "/")
    {net_input, net_output} = {List.first(net_list), List.last(net_list)}
    block_list = String.split(elem(data, 6), "/")
    {block_input, block_output} = {List.first(block_list), List.last(block_list)}

    %Stats{
      container_id: elem(data, 0),
      name: elem(data, 1),
      cpu: elem(data, 2),
      mem_usage: mem_usage,
      mem_limit: mem_limit,
      mem: elem(data, 4),
      net_input: net_input,
      net_output: net_output,
      block_input: block_input,
      block_output: block_output,
      pids: elem(data, 7)
    }
  end

  def get_floats(input) do
    case Float.parse(input) do
      {prefix, suffix} -> {prefix, suffix}
      _ -> IO.puts("some error occurred while converting")
    end
  end

  def check_mem_threshold(usage, limit) do
    usage_value = calculate_resource_usage(usage)
    limit_value = calculate_resource_usage(limit)
    usage_value >= limit_value
  end

  def calculate_resource_usage(input) do
    input_unit = elem(input, 1)
    input_value = elem(input, 0)

    input_value * :math.pow(1024, @conversion[input_unit])
  end

  def restart_container(name) do
    result = System.cmd("docker", ["restart", name])
    code = elem(result, 0)

    case String.length(code) do
      0 -> IO.puts("Failed to restart #{name}")
      _ -> IO.puts("#{name} restarted successfully")
    end
  end

end

Main.main()
