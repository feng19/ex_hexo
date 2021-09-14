defmodule ExHexo.Render do
  @moduledoc false
  require Logger
  import ExHexo.Render.Env
  alias ExHexo.Template

  def handle_default(page, key, default) do
    case Map.get(page, key) do
      nil -> default
      [:default] -> default
      list when is_list(list) -> handle_list_default(list, default)
    end
  end

  def handle_list_default(list, default) do
    case Enum.split_while(list, &(not match?(:default, &1))) do
      {list_h, [:default | tail]} -> list_h ++ default ++ tail
      _ -> list
    end
  end

  def __render__(file, assigns) do
    Template.get_eex(file)
    |> Code.eval_quoted([assigns: assigns], env(file))
    |> eval_layout(assigns)
  rescue
    reason ->
      Logger.error(Exception.format(:error, reason, __STACKTRACE__))
      raise "render file: #{file} with assigns: #{inspect(assigns)}, error: #{inspect(reason)}"
  catch
    error, reason ->
      Logger.error(Exception.format(error, reason, __STACKTRACE__))

      raise "render file: #{file} with assigns: #{inspect(assigns)}, #{inspect(error)}: #{inspect(reason)}"
  end

  defp eval_layout(return = {inner_content, bindings}, assigns) do
    case Keyword.get(bindings, :use_layout) do
      nil ->
        return

      false ->
        return

      layout_page ->
        layout_bindings = Keyword.fetch!(bindings, :use_layout_bindings) |> Map.new()

        assigns =
          Map.put(assigns, :inner_content, inner_content)
          |> Map.merge(layout_bindings)

        {content, _} = __render__(layout_page, assigns)
        {content, bindings}
    end
  end

  def eval_exs(file) do
    file
    |> File.read!()
    |> Code.eval_string([], env(file))
    |> elem(0)
  end
end
