defmodule ExHexo.Template do
  @moduledoc false

  @eex_table :ex_hexo_eex_list
  @db_file "db/eex.db"

  require Logger
  alias ExHexo.{Page, Render, Utils}

  def init do
    with :undefined <- :ets.info(@eex_table, :size) do
      Utils.setup_from_file!(@eex_table, @db_file)
    end
  end

  def dump_db() do
    Utils.dump_ets2file(@eex_table, @db_file)
  end

  def compile_all_eex(%{theme_dir: theme_dir, source_dir: source_dir}) do
    [theme_dir, source_dir]
    |> Enum.flat_map(&(&1 |> Path.join("**/*.eex") |> Path.wildcard()))
    |> Utils.async_tasks(fn eex ->
      mtime = File.stat!(eex, time: :posix).mtime

      case :ets.lookup(@eex_table, eex) do
        [{_, ^mtime, _q}] ->
          :ok

        _ ->
          q = EEx.compile_file(eex, trim: true)
          :ets.insert(@eex_table, {eex, mtime, q})
      end
    end)
  end

  def get_eex(eex) do
    [{_, _, q}] = :ets.lookup(@eex_table, eex)
    q
  end

  def find_eex(eex) do
    ets_stream(@eex_table)
    |> Enum.find(&String.ends_with?(&1, eex))
  end

  def find_eex(dir, eex) do
    Path.join(dir, eex)
    |> find_eex()
    |> case do
      nil -> {:error, "can not found #{eex} on #{dir} dirs."}
      page -> {:ok, page}
    end
  end

  defp ets_stream(table) do
    Stream.unfold(:ets.first(table), fn
      :"$end_of_table" ->
        nil

      key ->
        next_key = :ets.next(table, key)
        {key, next_key}
    end)
  end

  def write_page(filename, content, path) do
    filename |> Path.dirname() |> File.mkdir_p!()
    md5sum = :crypto.hash(:md5, content)

    if File.exists?(filename) do
      Page.write_page?(path, md5sum)
    else
      true
    end
    |> case do
      true ->
        File.write!(filename, content)
        Logger.info("write #{filename} success.")
        {:ok, path, md5sum}

      false ->
        {:skiped, path, md5sum}
    end
  end

  def render_layout_page(public_dir, file, path, page, assigns, type \\ :page) do
    case find_eex("layouts", page.layout) do
      {:ok, layout_page} ->
        assigns = assigns |> Map.merge(page.assigns) |> Map.merge(%{path: path, page: page})
        {content, _} = Render.__render__(layout_page, assigns)

        [public_dir, path, "index.html"]
        |> Path.join()
        |> write_page(content, path)
        |> case do
          {:ok, path, md5sum} ->
            Page.insert_page(path, page, md5sum, type)
            {path, :ok}

          {:skiped, path, _md5sum} ->
            {path, :skiped}
        end

      {:error, error} ->
        Logger.warning(error <> " when gen file: #{file}.")
        {path, :error}
    end
  end
end
