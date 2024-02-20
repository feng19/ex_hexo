defmodule ExHexo.Post do
  @moduledoc false
  @enforce_keys [:path, :title, :date]
  defstruct path: nil,
            order: 99,
            title: nil,
            description: "",
            date: nil,
            updated_date: nil,
            assigns: [],
            categories: [],
            tags: [],
            layout: "detail.eex",
            sitemap: true,
            thumbnail: nil,
            banner: nil,
            toc: [],
            body: ""

  @type t :: %__MODULE__{
          path: String.t(),
          order: integer,
          title: String.t(),
          description: String.t(),
          date: NaiveDateTime.t(),
          updated_date: NaiveDateTime.t(),
          assigns: Enumerable.t(),
          categories: [String.t()],
          tags: [String.t()],
          layout: String.t(),
          sitemap: boolean,
          thumbnail: String.t(),
          banner: String.t(),
          toc: [Map.t()],
          body: String.t()
        }

  @post_table :ex_hexo_posts
  @db_file "db/post.db"

  alias ExHexo.Utils

  def init do
    with :undefined <- :ets.info(@post_table, :size) do
      Utils.setup_from_file!(@post_table, @db_file)
    end
  end

  def dump_db() do
    Utils.dump_ets2file(@post_table, @db_file)
  end

  def get_posts_by_category(category) do
    find_by(fn {_path, _mtime, post}, acc ->
      if category in post.categories do
        [post | acc]
      else
        acc
      end
    end)
  end

  def get_posts_by_tag(tag) do
    find_by(fn {_path, _mtime, post}, acc ->
      if tag in post.tags do
        [post | acc]
      else
        acc
      end
    end)
  end

  def get_posts_by_category(category, tag) do
    find_by(fn {_path, _mtime, post}, acc ->
      if category in post.categories and tag in post.tags do
        [post | acc]
      else
        acc
      end
    end)
  end

  defp find_by(fun) do
    :ets.foldl(fun, [], @post_table) |> Enum.sort_by(&{&1.order, &1.date})
  end

  def parse_contents!(filename, path, earmark_opts \\ %Earmark.Options{}) do
    mtime = File.stat!(filename, time: :posix).mtime

    case :ets.lookup(@post_table, path) do
      [{_, ^mtime, post}] ->
        post

      _ ->
        {attrs, markdown_string} = do_parse_contents!(filename, File.read!(filename))
        post = struct(__MODULE__, attrs)

        {body, toc} =
          case Path.extname(filename) do
            ".md" -> transform_markdown(markdown_string, earmark_opts)
            ".markdown" -> transform_markdown(markdown_string, earmark_opts)
          end

        categories = Enum.sort(post.categories)
        tags = Enum.sort(post.tags)
        assigns = Map.new(post.assigns)

        post = %{
          post
          | path: path,
            body: body,
            toc: toc,
            categories: categories,
            tags: tags,
            assigns: assigns
        }

        :ets.insert(@post_table, {path, mtime, post})
        post
    end
  end

  # copy from nimble_publisher
  defp do_parse_contents!(path, contents) do
    case do_parse_contents(path, contents) do
      {:ok, attrs, body} ->
        {attrs, body}

      {:error, message} ->
        raise """
        #{message}

        Each entry must have a map with attributes, followed by --- and a body. For example:

            %{
              title: "Hello World"
            }
            ---
            Hello world!

        """
    end
  end

  defp do_parse_contents(path, contents) do
    case :binary.split(contents, ["\n---\n", "\r\n---\r\n"]) do
      [_] ->
        {:error, "could not find separator --- in #{inspect(path)}"}

      [code, body] ->
        case Code.eval_string(code, []) do
          {%{} = attrs, _} ->
            {:ok, attrs, body}

          {other, _} ->
            {:error,
             "expected attributes for #{inspect(path)} to return a map, got: #{inspect(other)}"}
        end
    end
  end

  defp build_toc(ast) do
    ast
    |> Stream.filter(&(elem(&1, 0) in ~w(h2 h3 h4)))
    |> Enum.map(fn {"h" <> level, _, [title], _} ->
      level = String.to_integer(level) - 1
      {level, %{title: title, level: level, href: nil, sub_list: []}}
    end)
    |> into_sub_list()
    |> reduce_toc({"h", 1})
  end

  defp into_sub_list([]), do: []
  defp into_sub_list([h | tail]), do: into_sub_list(tail, h) |> elem(0)

  defp into_sub_list([{level, _item} = current | tail], {level, old_item}) do
    {items, tail} = into_sub_list(tail, current)
    {[old_item | items], tail}
  end

  defp into_sub_list([{level, _} = current | tail], {parent_level, parent_item})
       when parent_level < level do
    {items, tail} = into_sub_list(tail, current)
    into_sub_list(tail, {parent_level, %{parent_item | sub_list: items}})
  end

  defp into_sub_list(tail, {_, item}), do: {[item], tail}

  defp reduce_toc(toc, acc) do
    Enum.map_reduce(toc, acc, fn item, {prefix, index} ->
      current_prefix = "#{prefix}.#{index}"
      sub_list = reduce_toc(item.sub_list, {current_prefix, 1})
      {%{item | sub_list: sub_list, href: "#" <> current_prefix}, {prefix, index + 1}}
    end)
    |> elem(0)
  end

  @compile {:no_warn_undefined, {EarmarkParser, :as_ast, 2}}
  defp transform_markdown(markdown_string, options) do
    {:ok, ast, _messages} = EarmarkParser.as_ast(markdown_string, options)
    toc = build_toc(ast)

    {ast, _} =
      Enum.map_reduce(ast, flat_toc(toc), fn
        {h, attrs, children, meta}, [{h, name} | acc] ->
          {{h, [{"id", name} | attrs], children, meta}, acc}

        node, acc ->
          {node, acc}
      end)

    {Earmark.Transform.transform(ast, options), toc}
  end

  defp flat_toc(toc) do
    Enum.flat_map(toc, fn item ->
      [
        {"h" <> Integer.to_string(item.level + 1), String.slice(item.href, 1..-1)}
        | flat_toc(item.sub_list)
      ]
    end)
  end
end
