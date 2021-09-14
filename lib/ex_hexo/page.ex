defmodule ExHexo.Page do
  @moduledoc false
  @enforce_keys [:title]
  defstruct path: nil,
            title: nil,
            description: nil,
            layout: "list.eex",
            assigns: [],
            sitemap: true,
            paginater: false,
            links: [:default],
            scripts: [:default]

  @type t :: %__MODULE__{
          path: String.t(),
          title: String.t(),
          description: String.t(),
          layout: String.t(),
          assigns: Enumerable.t(),
          sitemap: boolean,
          paginater: false | {start :: integer, size :: integer},
          links: [:default | String.t()],
          scripts: [:default | String.t()]
        }

  @page_table :ex_hexo_pages
  @db_file "db/page.db"

  alias ExHexo.{Sitemap, Utils}

  def init do
    with :undefined <- :ets.info(@page_table, :size) do
      Utils.setup_from_file!(@page_table, @db_file)
    end
  end

  def dump_db() do
    Utils.dump_ets2file(@page_table, @db_file)
  end

  def insert_page(
        path,
        page,
        md5sum,
        type \\ :page,
        last_mod \\ :erlang.localtime(),
        priority \\ 0.6,
        change_freq \\ "weekly"
      ) do
    ets_record = %{
      type: type,
      path: path,
      page: page,
      md5sum: md5sum,
      last_mod: last_mod,
      priority: priority,
      change_freq: change_freq
    }

    :ets.insert(@page_table, {path, ets_record})
  end

  def write_page?(path, md5sum) do
    case :ets.lookup(@page_table, path) do
      [{_, %{md5sum: ^md5sum}}] -> false
      _ -> true
    end
  end

  def generate_sitemap(url) do
    Sitemap.generate(url, :ets.tab2list(@page_table))
  end
end
