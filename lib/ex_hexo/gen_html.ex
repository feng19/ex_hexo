defmodule ExHexo.GenHtml do
  @moduledoc false
  import ExHexo.Utils, only: [async_tasks: 2]
  alias ExHexo.{Template, Post, Page, Render}

  @public_dir "public"

  def run(config) do
    config = normalize(config)
    IO.puts("starting gen html...")
    setup_from_db()

    [
      Task.async(fn -> copy_static(config) end),
      Task.async(fn -> Template.compile_all_eex(config) end)
    ]
    |> Task.await_many()

    gen_pages(config)
    build_assets(config)
    Page.generate_sitemap(config.site.url)
    dump_db()
    IO.puts("gen html finished!")
    config
  end

  defp normalize(config) do
    default = %{
      theme_dir: "themes/starter",
      source_dir: "source",
      assets_builder: %{
        ".js" => &build_js/1,
        ".css" => &build_css/1
      },
      assigns: %{}
    }

    Map.merge(default, Map.new(config))
  end

  defp setup_from_db do
    File.mkdir_p!("db")
    Template.init()
    Post.init()
    Page.init()
  end

  defp dump_db do
    Template.dump_db()
    Post.dump_db()
    Page.dump_db()
  end

  defp init_assigns(config) do
    config
    |> Map.take([:theme_dir, :source_dir, :site])
    |> Map.merge(config.assigns)
  end

  defp copy_static(%{theme_dir: theme_dir, source_dir: source_dir}) do
    public_dir = @public_dir
    File.mkdir_p!(public_dir)

    [theme_dir, source_dir]
    |> Stream.map(&Path.join(&1, "static"))
    |> Enum.each(fn dir ->
      if File.exists?(dir) do
        File.cp_r!(dir, public_dir)
      end
    end)

    posts_dir = "#{public_dir}/posts"
    File.mkdir_p!(posts_dir)

    source_dir
    |> Path.join("posts/*\.assets")
    |> Path.wildcard()
    |> Enum.each(fn file ->
      path_list = String.split(file, ["/", ".assets"], trim: true)
      post_name = List.last(path_list)
      target_dir = Path.join(posts_dir, "#{post_name}/#{post_name}.assets")
      File.mkdir_p!(target_dir)
      File.cp_r!(file, target_dir)
    end)
  end

  defp gen_pages(config) do
    assigns = init_assigns(config)

    # posts
    Path.join(config.source_dir, "posts/*.md")
    |> Path.wildcard()
    |> async_tasks(&gen_post!(&1, assigns))

    # exs
    [config.theme_dir, config.source_dir]
    |> Enum.flat_map(&(Path.join(&1, "pages/*.exs") |> Path.wildcard()))
    |> async_tasks(&gen_exs_page!(&1, assigns))

    # eex
    [config.theme_dir, config.source_dir]
    |> Enum.flat_map(&(Path.join(&1, "pages/*.eex") |> Path.wildcard()))
    |> async_tasks(&gen_eex_page!(&1, assigns))
  end

  defp gen_post!(file, assigns) do
    path = "posts/" <> (file |> Path.basename() |> Path.rootname())
    post = Post.parse_contents!(file, path)
    assigns = Map.put(assigns, :post, post)
    Template.render_layout_page(@public_dir, file, path, post, assigns, :post)
  end

  defp gen_exs_page!(file, assigns) do
    path = file |> Path.basename() |> Path.rootname()

    case Render.eval_exs(file) do
      pages when is_list(pages) ->
        Enum.map(pages, fn {page_number, page} ->
          current_path =
            if page_number > 1 do
              Path.join([path, "page", Integer.to_string(page_number)])
            else
              path
            end

          page_assigns = Map.new(page.assigns) |> Map.put(:root_path, path)
          page = Map.put(page, :assigns, page_assigns)
          Template.render_layout_page(@public_dir, file, current_path, page, assigns)
        end)

      page ->
        page = Map.put(page, :assigns, Map.new(page.assigns))
        Template.render_layout_page(@public_dir, file, path, page, assigns)
    end
  end

  defp gen_eex_page!(file, assigns) do
    path = file |> Path.basename() |> Path.rootname()
    assigns = Map.put(assigns, :path, path)
    {content, bindings} = Render.__render__(file, assigns)

    if path in ["index", "404"] do
      [@public_dir, "#{path}.html"]
    else
      [@public_dir, path, "index.html"]
    end
    |> Path.join()
    |> Template.write_page(content, path)
    |> case do
      {:ok, path, md5sum} ->
        page = Keyword.fetch!(bindings, :page)
        Page.insert_page(path, page, md5sum)
        {path, :ok}

      {:skiped, path, _md5sum} ->
        {path, :skiped}
    end
  end

  defp build_assets(%{
         theme_dir: theme_dir,
         source_dir: source_dir,
         assets_builder: assets_builder
       }) do
    if File.exists?("package.json") do
      [theme_dir, source_dir]
      |> Enum.each(fn dir ->
        [
          Path.join(dir, "assets/js/*.js") |> Path.wildcard(),
          Path.join(dir, "assets/css/*.css") |> Path.wildcard()
        ]
        |> Enum.concat()
        |> async_tasks(fn input ->
          ext = Path.extname(input)
          assets_builder[ext].(input)
        end)
      end)
    end
  end

  defp build_js(input) do
    System.cmd(
      "npx",
      [
        "esbuild",
        input,
        "--bundle",
        "--minify",
        "--target=es2016",
        "--outdir=#{@public_dir}/js"
      ],
      into: IO.stream(:stdio, :line)
    )
  end

  defp build_css(input) do
    System.cmd(
      "npx",
      [
        "tailwindcss",
        "--postcss",
        "--minify",
        "--input=#{input}",
        "--output=#{@public_dir}/css/#{Path.basename(input)}"
      ],
      env: [{"NODE_ENV", "production"}],
      into: IO.stream(:stdio, :line)
    )
  end
end
