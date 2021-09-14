defmodule ExHexo.Utils do
  @moduledoc false
  require Logger

  def dump_ets2file(table_name, file_name) do
    file_name = String.to_charlist(file_name)
    :ets.tab2file(table_name, file_name, extended_info: [:md5sum], sync: true)
  end

  def setup_from_file!(table_name, file_name) do
    if File.exists?(file_name) do
      file_name
      |> String.to_charlist()
      |> :ets.file2tab(verify: true)
      |> case do
        {:ok, _tid} ->
          Logger.info("setup table: #{table_name} from file: #{file_name} success.")
          :ok

        {:error, error} ->
          raise "setup from file: #{file_name} error: #{inspect(error)}"
      end
    else
      :ets.new(table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    end
  end

  def async_tasks(files, fun) do
    files
    |> Task.async_stream(fun, max_concurrency: System.schedulers_online() * 4)
    |> Stream.run()
  end
end
