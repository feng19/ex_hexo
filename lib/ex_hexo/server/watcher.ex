defmodule ExHexo.Server.Watcher do
  @moduledoc false
  use GenServer

  dir = :code.priv_dir(:file_system)
  files = File.ls!(dir) |> Enum.map(&Path.join(dir, &1))

  for file <- files do
    @external_resource file
  end

  file_contents = Enum.map(files, &{Path.basename(&1), File.read!(&1)})

  def start_link(config_file) do
    File.mkdir_p!("bin")
    os_type = :os.type()

    Enum.each(unquote(file_contents), fn {file, content} ->
      case {os_type, file} do
        {{:unix, :darwin}, "mac_listener"} -> true
        {{:win32, :nt}, "inotifywait.exe"} -> true
        _ -> false
      end
      |> if do
        file = Path.join("bin", file)

        unless File.exists?(file) do
          File.write!(file, content)
          File.chmod!(file, 0o755)
        end
      end
    end)

    Application.put_all_env([
      {:file_system,
       [
         fs_mac: [executable_file: Path.absname("bin/mac_listener")],
         fs_inotify: [executable_file: Path.absname("bin/inotifywait.exe")]
       ]}
    ])

    GenServer.start_link(__MODULE__, config_file, name: __MODULE__)
  end

  def io_read(config_file) do
    flush()

    IO.gets("regen? y/n: ")
    |> String.trim()
    |> String.downcase()
    |> case do
      "n" -> :ignore
      _ -> :ok = GenServer.call(__MODULE__, :regen)
    end

    io_read(config_file)
  end

  defp flush do
    {:ok, pid} =
      Task.start(fn ->
        f = fn fun ->
          IO.read(:all)
          fun.()
        end

        f.(f)
      end)

    Process.sleep(1000)
    Process.exit(pid, :kill)
  end

  @impl true
  def init(config_file) do
    {config, _} = Code.eval_file(config_file)

    dirs =
      [config_file, "data", config.theme_dir, config.source_dir]
      |> Enum.map(&Path.absname/1)
      |> Enum.filter(&File.exists?/1)

    {:ok, pid} = FileSystem.start_link(dirs: dirs, name: :watch_worker)
    FileSystem.subscribe(pid)
    {:ok, %{watcher: pid, config_file: config_file, interval: 1000, timer: nil}}
  end

  @impl true
  def handle_call(:regen, _from, state) do
    regen(state.config_file)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:file_event, _worker_pid, _event}, state) do
    flush_event()
    state = start_regen_timer(state)
    {:noreply, state}
  end

  def handle_info(:regen_timeout, state) do
    regen(state.config_file)
    {:noreply, %{state | timer: nil}}
  end

  defp start_regen_timer(state = %{timer: nil, interval: interval}) do
    timer = Process.send_after(self(), :regen_timeout, interval)
    %{state | timer: timer}
  end

  defp start_regen_timer(state), do: state

  defp regen(config_file) do
    flush_event()
    {config, _} = Code.eval_file(config_file)

    config
    |> ExHexo.GenHtml.run()
    |> ExHexo.put_config()

    ExHexo.Server.Socket.reload()
    flush_event()
  end

  defp flush_event do
    receive do
      {:file_event, _worker_pid, _event} -> flush_event()
    after
      0 -> :ok
    end
  end
end
