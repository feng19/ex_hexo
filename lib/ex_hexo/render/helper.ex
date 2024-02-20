defmodule ExHexo.Render.Helper do
  @moduledoc false
  require Logger
  alias ExHexo.Template

  defmacro find_and_render(eex, new_assigns \\ []) do
    if file = Template.find_eex(eex) do
      render_quote(file, new_assigns)
    end
  end

  defmacro render(eex, new_assigns \\ []) do
    render_dir = Path.dirname(__CALLER__.file)
    file = Path.expand(eex, render_dir) |> Path.relative_to_cwd()

    if File.exists?(file) do
      render_quote(file, new_assigns)
    end
  end

  defp render_quote(file, new_assigns) do
    quote do
      var!(assigns)
      |> Map.merge(Map.new(unquote(new_assigns) || []))
      |> then(&ExHexo.Render.__render__(unquote(file), &1))
      |> elem(0)
    end
  end

  defmacro render_component(eex, new_assigns \\ []) do
    case Template.find_eex("components", eex) do
      nil ->
        Logger.warning("can not found #{eex} on components dirs.")
        nil

      file ->
        render_quote(file, new_assigns)
    end
  end

  defmacro use_layout(eex, bindings \\ []) do
    case Template.find_eex("layouts", eex) do
      {:ok, page} ->
        quote do
          var!(use_layout) = unquote(page)
          var!(use_layout_bindings) = unquote(bindings)
        end

      {:error, error} ->
        Logger.warning(error)
        nil
    end
  end

  defmacro load_data("/" <> exs) do
    quote do
      {data, _} = Code.eval_file(unquote(exs))
      data
    end
  end

  defmacro load_data(exs) do
    quote do
      {data, _} = Code.eval_file(unquote(exs), __DIR__)
      data
    end
  end

  def page_path(root_path, 1), do: "/#{root_path}/"

  def page_path(root_path, page_number) do
    "/#{Path.join([root_path, "page", Integer.to_string(page_number)])}/"
  end
end
